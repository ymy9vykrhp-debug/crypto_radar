import 'dart:convert';

import 'package:crypto_radar/engines/entry_readiness_gate.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/integration_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:crypto_radar/models/trade_alert_models.dart';
import 'package:crypto_radar/services/notifications/telegram_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Telegram relay gateway', () {
    test('disabled config performs no network request', () async {
      int requests = 0;
      final MockClient client = MockClient((http.Request request) async {
        requests++;
        return http.Response('{}', 500);
      });
      final HttpTelegramRelayGateway gateway = HttpTelegramRelayGateway(client);

      final IntegrationStatus status = await gateway.check(
        const TelegramRelayConfig(),
      );

      expect(status.state, IntegrationConnectionState.disabled);
      expect(requests, 0);
      client.close();
    });

    test(
      'health and test delivery use relay without bot credentials',
      () async {
        final List<http.Request> requests = <http.Request>[];
        final MockClient client = MockClient((http.Request request) async {
          requests.add(request);
          if (request.url.path == '/health') {
            return http.Response(
              jsonEncode(<String, Object?>{'ok': true, 'configured': true}),
              200,
            );
          }
          if (request.url.path == '/v1/telegram/messages') {
            return http.Response(
              jsonEncode(<String, Object?>{'ok': true}),
              200,
            );
          }
          if (request.url.path == '/v1/telegram/discover-chat') {
            return http.Response(
              jsonEncode(<String, Object?>{
                'ok': true,
                'message': 'CHAT CONNECTED · •••1234',
              }),
              200,
              headers: const <String, String>{
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return http.Response('{}', 404);
        });
        final HttpTelegramRelayGateway gateway = HttpTelegramRelayGateway(
          client,
        );
        const TelegramRelayConfig config = TelegramRelayConfig(
          enabled: true,
          baseUrl: 'http://127.0.0.1:8787',
        );

        final IntegrationStatus status = await gateway.check(config);
        final String discovery = await gateway.discoverChat(config);
        await gateway.sendTest(config);

        expect(status.state, IntegrationConnectionState.connected);
        expect(discovery, contains('CONNECTED'));
        expect(requests, hasLength(3));
        expect(requests.last.body, isNot(contains('bot_token')));
        expect(requests.last.url.host, '127.0.0.1');
        client.close();
      },
    );

    test('trade alert sends the complete idempotent relay payload', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      });
      final HttpTelegramRelayGateway gateway = HttpTelegramRelayGateway(client);
      const TelegramRelayConfig config = TelegramRelayConfig(
        enabled: true,
        baseUrl: 'http://127.0.0.1:8787',
      );

      await gateway.sendTradeAlert(config, _alert());
      final Map<String, dynamic> payload =
          jsonDecode(captured.body) as Map<String, dynamic>;

      expect(payload['eventId'], 'entry-ready:signal-telegram');
      expect(payload['kind'], 'ENTRY_READY');
      expect(payload['entryLowText'], '0.2010');
      expect(payload['riskRewardTp1Text'], '1:1.29');
      expect(payload['directionQuality'], 90);
      expect(payload['dataQuality'], 'HIGH');
      expect(captured.body, isNot(contains('token')));
      expect(captured.body, isNot(contains('chatId')));
      client.close();
    });
  });
}

TradeAlert _alert() {
  final DateTime now = DateTime.utc(2026, 8, 31, 12);
  final RadarSignal signal = RadarSignal(
    id: 'signal-telegram',
    symbol: 'FARTCOINUSDT',
    time: now.subtract(const Duration(minutes: 5)),
    direction: SignalDirection.long,
    referencePrice: 0.202,
    entryLow: 0.201,
    entryHigh: 0.202,
    stop: 0.198,
    tp1: 0.206,
    tp2: 0.21,
    score: 91,
    trend5m: Bias.bullish,
    trend15m: Bias.bullish,
    trend1h: Bias.bullish,
    rsi: 56,
    macd: 0.001,
    ema20: 0.202,
    ema50: 0.2,
    ema200: 0.19,
    relativeVolume: 1.4,
    rvolBias: Bias.bullish,
    fvgBias: Bias.bullish,
    orderBlockBias: Bias.bullish,
    liquidityBias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    stage: SignalStage.entryConfirmed,
    entryConfirmedTime: now,
    qualities: const SignalQualityScores(
      direction: 90,
      entry: 85,
      location: 82,
      liquidity: 80,
      stop: 78,
      risk: 75,
    ),
  );
  return TradeAlert(
    kind: TradeAlertKind.entryReady,
    signal: signal,
    createdAt: now,
    tickSize: 0.0001,
    readiness: EntryReadinessResult(
      signalId: signal.id,
      evaluatedAt: now,
      status: EntryReadinessStatus.entryReady,
      nextAction: EntryNextAction.enter,
      reasons: const <EntryReadinessReason>[],
      dataQuality: DataQuality.high,
      hardBlocked: false,
      marketDataReady: true,
      microstructureReady: true,
      entryConfirmed: true,
      priceInZone: true,
      liquidityReady: true,
      riskReady: true,
      directionReady: true,
      entryReady: true,
    ),
  );
}
