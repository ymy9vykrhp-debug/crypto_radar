import 'dart:async';
import 'dart:convert';
import 'dart:io';

const String _tokenVariable = 'CRYPTO_RADAR_TELEGRAM_BOT_TOKEN';
const String _chatVariable = 'CRYPTO_RADAR_TELEGRAM_CHAT_ID';
const String _portVariable = 'CRYPTO_RADAR_TELEGRAM_RELAY_PORT';

Future<void> main() async {
  final Map<String, String> environment = Platform.environment;
  final String token = environment[_tokenVariable]?.trim() ?? '';
  final String chatId = environment[_chatVariable]?.trim() ?? '';
  final int port = int.tryParse(environment[_portVariable] ?? '') ?? 8787;
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    port,
  );
  final _TelegramRelay relay = _TelegramRelay(token: token, chatId: chatId);
  stdout.writeln(
    'Crypto Radar Telegram relay: http://127.0.0.1:$port '
    '(${relay.configured ? 'configured' : 'NOT CONFIGURED'})',
  );
  await for (final HttpRequest request in server) {
    unawaited(relay.handle(request));
  }
}

class _TelegramRelay {
  _TelegramRelay({required this.token, required this.chatId});

  final String token;
  final String chatId;
  final Set<String> _delivered = <String>{};
  final HttpClient _client = HttpClient();

  bool get configured => token.isNotEmpty && chatId.isNotEmpty;

  Future<void> handle(HttpRequest request) async {
    final String? origin = request.headers.value('origin');
    if (!_allowOrigin(origin)) {
      await _json(request.response, HttpStatus.forbidden, <String, Object?>{
        'ok': false,
        'error': 'Origin is not allowed',
      });
      return;
    }
    _cors(request.response, origin);
    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/health') {
      await _json(request.response, HttpStatus.ok, <String, Object?>{
        'ok': true,
        'configured': configured,
        'service': 'crypto-radar-telegram-relay',
      });
      return;
    }
    if (request.method != 'POST' ||
        request.uri.path != '/v1/telegram/messages') {
      await _json(request.response, HttpStatus.notFound, <String, Object?>{
        'ok': false,
        'error': 'Not found',
      });
      return;
    }
    if (!configured) {
      await _json(
        request.response,
        HttpStatus.serviceUnavailable,
        <String, Object?>{
          'ok': false,
          'error': 'Telegram token or chat ID is not configured',
        },
      );
      return;
    }
    try {
      final String raw = await utf8.decoder.bind(request).join();
      if (raw.length > 16000) throw const FormatException('Payload too large');
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON object expected');
      }
      final String eventId = decoded['eventId']?.toString().trim() ?? '';
      if (eventId.isEmpty) throw const FormatException('eventId is required');
      if (_delivered.contains(eventId)) {
        await _json(request.response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'duplicate': true,
        });
        return;
      }
      await _sendTelegram(_formatMessage(decoded));
      _delivered.add(eventId);
      if (_delivered.length > 2000) _delivered.remove(_delivered.first);
      await _json(request.response, HttpStatus.ok, <String, Object?>{
        'ok': true,
        'duplicate': false,
      });
    } on FormatException catch (error) {
      await _json(request.response, HttpStatus.badRequest, <String, Object?>{
        'ok': false,
        'error': error.message,
      });
    } on Object catch (error) {
      await _json(request.response, HttpStatus.badGateway, <String, Object?>{
        'ok': false,
        'error': _safeError(error),
      });
    }
  }

  Future<void> _sendTelegram(String text) async {
    final Uri uri = Uri.https('api.telegram.org', '/bot$token/sendMessage');
    final HttpClientRequest telegramRequest = await _client.postUrl(uri);
    telegramRequest.headers.contentType = ContentType.json;
    telegramRequest.write(
      jsonEncode(<String, Object?>{
        'chat_id': chatId,
        'text': text,
        'disable_web_page_preview': true,
      }),
    );
    final HttpClientResponse response = await telegramRequest.close().timeout(
      const Duration(seconds: 12),
    );
    final String body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Object? decoded = _tryDecode(body);
      final String description = decoded is Map<String, dynamic>
          ? decoded['description']?.toString() ?? 'Telegram error'
          : 'Telegram HTTP ${response.statusCode}';
      throw Exception(description);
    }
  }

  String _formatMessage(Map<String, dynamic> payload) {
    if (payload['kind'] == 'TEST') {
      return payload['text']?.toString() ?? 'Crypto Radar test';
    }
    final String symbol = payload['symbol']?.toString() ?? 'UNKNOWN';
    final String direction = payload['direction']?.toString() ?? 'WAIT';
    return <String>[
      'Crypto Radar · ENTRY CONFIRMED',
      '$symbol · $direction · score ${payload['score'] ?? '—'}',
      'Entry: ${payload['entryLow'] ?? '—'} – ${payload['entryHigh'] ?? '—'}',
      'Stop: ${payload['stop'] ?? '—'}',
      'TP1: ${payload['tp1'] ?? '—'} · TP2: ${payload['tp2'] ?? '—'}',
      'MONITOR ONLY · order was not placed',
    ].join('\n');
  }

  bool _allowOrigin(String? origin) {
    if (origin == null || origin.isEmpty) return true;
    final Uri? uri = Uri.tryParse(origin);
    return uri != null &&
        uri.scheme == 'http' &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1');
  }

  void _cors(HttpResponse response, String? origin) {
    if (origin != null && origin.isNotEmpty) {
      response.headers.set('Access-Control-Allow-Origin', origin);
      response.headers.set('Vary', 'Origin');
    }
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    response.headers.set(
      'Access-Control-Allow-Headers',
      'Content-Type, X-Crypto-Radar-Client',
    );
  }

  Future<void> _json(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(body));
    await response.close();
  }

  Object? _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } on Object {
      return null;
    }
  }

  String _safeError(Object error) {
    final String value = error.toString().replaceFirst('Exception: ', '');
    return value.replaceAll(token, '[REDACTED]');
  }
}
