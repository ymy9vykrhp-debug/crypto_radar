import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto_radar/services/notifications/telegram_message_formatter.dart';

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
  final File ledgerFile = _eventLedgerFile();
  final _TelegramRelay relay = _TelegramRelay(
    token: token,
    chatId: chatId,
    ledgerFile: ledgerFile,
    delivered: await _readDelivered(ledgerFile),
  );
  stdout.writeln(
    'Crypto Radar Telegram relay: http://127.0.0.1:$port '
    '(${relay.configured ? 'configured' : 'NOT CONFIGURED'})',
  );
  await for (final HttpRequest request in server) {
    unawaited(relay.handle(request));
  }
}

class _TelegramRelay {
  _TelegramRelay({
    required this.token,
    required this._chatId,
    required this.ledgerFile,
    required this._delivered,
  });

  final String token;
  String _chatId;
  final File ledgerFile;
  final Set<String> _delivered;
  final HttpClient _client = HttpClient();
  final Map<String, Future<void>> _inFlight = <String, Future<void>>{};
  Future<void> _ledgerWriteQueue = Future<void>.value();

  bool get configured => token.isNotEmpty && _chatId.isNotEmpty;

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
        'tokenConfigured': token.isNotEmpty,
        'chatConfigured': _chatId.isNotEmpty,
        'service': 'crypto-radar-telegram-relay',
      });
      return;
    }
    if (request.method == 'POST' &&
        request.uri.path == '/v1/telegram/discover-chat') {
      if (token.isEmpty) {
        await _json(
          request.response,
          HttpStatus.serviceUnavailable,
          <String, Object?>{
            'ok': false,
            'error': 'Telegram token is not configured',
          },
        );
        return;
      }
      try {
        final String message = await _discoverChat();
        await _json(request.response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'message': message,
        });
      } on Object catch (error) {
        await _json(request.response, HttpStatus.badGateway, <String, Object?>{
          'ok': false,
          'error': _safeError(error),
        });
      }
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
          'error': token.isEmpty
              ? 'Telegram token is not configured'
              : 'Send /start to the bot and discover the chat first',
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
      final Future<void>? activeDelivery = _inFlight[eventId];
      if (activeDelivery != null) {
        await activeDelivery;
        await _json(request.response, HttpStatus.ok, <String, Object?>{
          'ok': true,
          'duplicate': true,
        });
        return;
      }
      final Future<void> delivery = _deliverEvent(eventId, decoded);
      _inFlight[eventId] = delivery;
      try {
        await delivery;
      } finally {
        _inFlight.remove(eventId);
      }
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
        'chat_id': _chatId,
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

  Future<void> _deliverEvent(
    String eventId,
    Map<String, dynamic> payload,
  ) async {
    await _sendTelegram(formatTelegramRelayMessage(payload));
    _delivered.add(eventId);
    if (_delivered.length > 2000) _delivered.remove(_delivered.first);
    await _persistDelivered();
  }

  Future<void> _persistDelivered() async {
    final String payload = jsonEncode(_delivered.toList());
    _ledgerWriteQueue = _ledgerWriteQueue.then<void>((_) async {
      await ledgerFile.parent.create(recursive: true);
      final File temporary = File('${ledgerFile.path}.tmp');
      await temporary.writeAsString(payload);
      if (await ledgerFile.exists()) await ledgerFile.delete();
      await temporary.rename(ledgerFile.path);
    });
    await _ledgerWriteQueue;
  }

  Future<String> _discoverChat() async {
    final Uri uri = Uri.https('api.telegram.org', '/bot$token/getUpdates');
    final HttpClientRequest telegramRequest = await _client.postUrl(uri);
    telegramRequest.headers.contentType = ContentType.json;
    telegramRequest.write(
      jsonEncode(<String, Object?>{
        'limit': 100,
        'timeout': 0,
        'allowed_updates': <String>['message'],
      }),
    );
    final HttpClientResponse response = await telegramRequest.close().timeout(
      const Duration(seconds: 12),
    );
    final String body = await utf8.decoder.bind(response).join();
    final Object? decoded = _tryDecode(body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map<String, dynamic> ||
        decoded['ok'] != true) {
      final String description = decoded is Map<String, dynamic>
          ? decoded['description']?.toString() ?? 'Telegram getUpdates error'
          : 'Telegram HTTP ${response.statusCode}';
      throw Exception(description);
    }
    final Object? rawUpdates = decoded['result'];
    if (rawUpdates is! List<dynamic>) {
      throw Exception('Telegram returned no updates');
    }
    for (final Object? rawUpdate in rawUpdates.reversed) {
      if (rawUpdate is! Map<String, dynamic>) continue;
      final Object? rawMessage = rawUpdate['message'];
      if (rawMessage is! Map<String, dynamic>) continue;
      final String text = rawMessage['text']?.toString().trim() ?? '';
      if (!text.startsWith('/start')) continue;
      final Object? rawChat = rawMessage['chat'];
      if (rawChat is! Map<String, dynamic>) continue;
      final String discovered = rawChat['id']?.toString().trim() ?? '';
      if (discovered.isEmpty) continue;
      _chatId = discovered;
      final String suffix = discovered.length <= 4
          ? discovered
          : discovered.substring(discovered.length - 4);
      return 'CHAT CONNECTED · •••$suffix';
    }
    throw Exception('Send /start to the bot, then try again');
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

File _eventLedgerFile() {
  final String base =
      Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
  return File(
    '$base${Platform.pathSeparator}CryptoRadar${Platform.pathSeparator}'
    'telegram_delivered_events_v1.json',
  );
}

Future<Set<String>> _readDelivered(File file) async {
  try {
    if (!await file.exists()) return <String>{};
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<dynamic>) return <String>{};
    return decoded
        .map<String>((Object? value) => value?.toString() ?? '')
        .where((String value) => value.isNotEmpty)
        .take(2000)
        .toSet();
  } on Object {
    return <String>{};
  }
}
