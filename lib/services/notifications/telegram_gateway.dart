import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/integration_models.dart';
import '../../models/trade_alert_models.dart';

abstract interface class TelegramGateway {
  Future<IntegrationStatus> check(TelegramRelayConfig config);

  Future<void> sendTest(TelegramRelayConfig config);

  Future<void> sendTradeAlert(TelegramRelayConfig config, TradeAlert alert);
}

/// Browser-safe client for the local Telegram relay. Bot token and chat ID are
/// intentionally absent from this class and from persisted Flutter settings.
class HttpTelegramRelayGateway implements TelegramGateway {
  HttpTelegramRelayGateway(this._client);

  final http.Client _client;

  @override
  Future<IntegrationStatus> check(TelegramRelayConfig config) async {
    if (!config.enabled) {
      return const IntegrationStatus(
        state: IntegrationConnectionState.disabled,
        message: 'DISABLED',
      );
    }
    final Uri? uri = _endpoint(config, '/health');
    if (uri == null) {
      return IntegrationStatus(
        state: IntegrationConnectionState.notConfigured,
        message: 'INVALID RELAY URL',
        checkedAt: DateTime.now(),
      );
    }
    try {
      final http.Response response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      final Map<String, dynamic>? body = _jsonMap(response.body);
      final bool configured = body?['configured'] == true;
      return IntegrationStatus(
        state: response.statusCode == 200 && configured
            ? IntegrationConnectionState.connected
            : IntegrationConnectionState.notConfigured,
        message: configured ? 'CONNECTED' : 'RELAY NOT CONFIGURED',
        checkedAt: DateTime.now(),
      );
    } on Object {
      return IntegrationStatus(
        state: IntegrationConnectionState.unavailable,
        message: 'RELAY UNAVAILABLE',
        checkedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> sendTest(TelegramRelayConfig config) =>
      _send(config, <String, Object?>{
        'eventId': 'test-${DateTime.now().microsecondsSinceEpoch}',
        'kind': 'TEST',
        'text': 'Crypto Radar: Telegram relay подключён. MONITOR ONLY.',
      });

  @override
  Future<void> sendTradeAlert(TelegramRelayConfig config, TradeAlert alert) {
    final signal = alert.signal;
    final String direction = signal.direction.name.toUpperCase();
    return _send(config, <String, Object?>{
      'eventId': signal.id,
      'kind': 'ENTRY_CONFIRMED',
      'symbol': signal.symbol,
      'direction': direction,
      'score': signal.score,
      'entryLow': signal.entryLow,
      'entryHigh': signal.entryHigh,
      'stop': signal.stop,
      'tp1': signal.tp1,
      'tp2': signal.tp2,
      'createdAt': alert.createdAt.toUtc().toIso8601String(),
      'text': '${signal.symbol} · $direction · score ${signal.score}',
    });
  }

  Future<void> _send(
    TelegramRelayConfig config,
    Map<String, Object?> payload,
  ) async {
    if (!config.enabled) return;
    final Uri? uri = _endpoint(config, '/v1/telegram/messages');
    if (uri == null) throw const FormatException('Invalid Telegram relay URL');
    final http.Response response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'content-type': 'application/json',
            'x-crypto-radar-client': 'flutter-ui',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final Map<String, dynamic>? body = _jsonMap(response.body);
      throw Exception(
        body?['error']?.toString() ?? 'Relay HTTP ${response.statusCode}',
      );
    }
  }

  Uri? _endpoint(TelegramRelayConfig config, String path) {
    if (!config.hasValidUrl) return null;
    final Uri base = Uri.parse(config.baseUrl.trim());
    return base.replace(path: path);
  }

  Map<String, dynamic>? _jsonMap(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }
}
