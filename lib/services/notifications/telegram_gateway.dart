import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/integration_models.dart';
import '../../models/execution_models.dart';
import '../../models/trade_alert_models.dart';
import '../../utils/market_price_formatter.dart';

abstract interface class TelegramGateway {
  Future<IntegrationStatus> check(TelegramRelayConfig config);

  Future<void> sendTest(TelegramRelayConfig config);

  Future<String> discoverChat(TelegramRelayConfig config);

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
      final bool tokenConfigured = body?['tokenConfigured'] == true;
      return IntegrationStatus(
        state: response.statusCode == 200 && configured
            ? IntegrationConnectionState.connected
            : IntegrationConnectionState.notConfigured,
        message: configured
            ? 'CONNECTED'
            : tokenConfigured
            ? 'SEND /start TO BOT'
            : 'RELAY NOT CONFIGURED',
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
  Future<String> discoverChat(TelegramRelayConfig config) async {
    final Uri? uri = _endpoint(config, '/v1/telegram/discover-chat');
    if (uri == null) throw const FormatException('Invalid Telegram relay URL');
    final http.Response response = await _client
        .post(
          uri,
          headers: const <String, String>{
            'content-type': 'application/json',
            'x-crypto-radar-client': 'flutter-ui',
          },
          body: '{}',
        )
        .timeout(const Duration(seconds: 10));
    final Map<String, dynamic>? body = _jsonMap(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body?['error']?.toString() ?? 'Relay HTTP ${response.statusCode}',
      );
    }
    return body?['message']?.toString() ?? 'CHAT CONNECTED';
  }

  @override
  Future<void> sendTest(TelegramRelayConfig config) =>
      _send(config, <String, Object?>{
        'eventId': 'test-${DateTime.now().microsecondsSinceEpoch}',
        'kind': 'TEST',
        'text':
            '✅ Crypto Radar Telegram подключён\n\n'
            'ENTRY READY alerts: ON\n'
            'Relay: CONNECTED\n'
            'Mode: LOCAL MONITOR ONLY\n\n'
            'Это тест. Торговый сигнал не создавался.\n'
            'Ордер не отправлялся.',
      });

  @override
  Future<void> sendTradeAlert(TelegramRelayConfig config, TradeAlert alert) {
    final signal = alert.signal;
    final String direction = signal.direction.name.toUpperCase();
    return _send(config, <String, Object?>{
      'eventId': alert.eventId,
      'kind': alert.kind.wireName,
      'symbol': signal.symbol,
      'direction': direction,
      'stage': signal.stage.code,
      'trackerStatus': signal.status.name.toUpperCase(),
      'score': signal.score,
      'referencePriceText': formatMarketPrice(
        signal.referencePrice,
        tickSize: alert.tickSize,
      ),
      'entryLow': signal.entryLow,
      'entryHigh': signal.entryHigh,
      'entryLowText': formatMarketPrice(
        signal.entryLow,
        tickSize: alert.tickSize,
      ),
      'entryHighText': formatMarketPrice(
        signal.entryHigh,
        tickSize: alert.tickSize,
      ),
      'stop': signal.stop,
      'stopText': formatMarketPrice(signal.stop, tickSize: alert.tickSize),
      'tp1': signal.tp1,
      'tp1Text': formatMarketPrice(signal.tp1, tickSize: alert.tickSize),
      'tp2': signal.tp2,
      'tp2Text': formatMarketPrice(signal.tp2, tickSize: alert.tickSize),
      'createdAt': alert.createdAt.toUtc().toIso8601String(),
      'confirmedAt': alert.confirmedAt.toUtc().toIso8601String(),
      'setupAgeSeconds': alert.setupAge.inSeconds,
      'stopDistancePercent': alert.stopDistancePercent,
      'stopDistancePercentText':
          '${alert.stopDistancePercent.toStringAsFixed(2)}%',
      'riskRewardTp1': alert.riskRewardTp1,
      'riskRewardTp1Text': '1:${alert.riskRewardTp1.toStringAsFixed(2)}',
      'riskRewardTp2': alert.riskRewardTp2,
      'riskRewardTp2Text': '1:${alert.riskRewardTp2.toStringAsFixed(2)}',
      'directionQuality': signal.qualities.direction,
      'entryQuality': signal.qualities.entry,
      'locationQuality': signal.qualities.location,
      'liquidityQuality': signal.qualities.liquidity,
      'stopQuality': signal.qualities.stop,
      'riskQuality': signal.qualities.risk,
      'dataQuality': alert.readiness.dataQuality.name.toUpperCase(),
      'reasonCodes': alert.readiness.reasonCodes,
      'entryTime': signal.entryTime?.toUtc().toIso8601String(),
      'tp1Time': signal.tp1Time?.toUtc().toIso8601String(),
      'tp2Time': signal.tp2Time?.toUtc().toIso8601String(),
      'exitTime': signal.exitTime?.toUtc().toIso8601String(),
      'resultR': signal.resultR,
      'netResultR': signal.netResultR,
      'mfeR': signal.mfeR,
      'maeR': signal.maeR,
      'text': 'Crypto Radar · ${alert.kind.wireName}',
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
