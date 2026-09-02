import 'package:crypto_radar/services/notifications/telegram_message_formatter.dart';
import 'package:crypto_radar/utils/market_price_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('market prices follow tick-size precision', () {
    expect(formatMarketPrice(0.2032, tickSize: 0.0001), '0.2032');
    expect(formatMarketPrice(4604.59, tickSize: 0.01), '4604.59');
    expect(formatMarketPrice(double.nan), '—');
  });

  test('ENTRY READY message explains quality and execution levels', () {
    final String message = formatTelegramRelayMessage(<String, dynamic>{
      'kind': 'ENTRY_READY',
      'symbol': 'FARTCOINUSDT',
      'direction': 'LONG',
      'score': 91,
      'entryLowText': '0.2010',
      'entryHighText': '0.2020',
      'entryLow': 0.2010,
      'entryHigh': 0.2020,
      'stop': 0.1980,
      'tp1': 0.2050,
      'tp2': 0.2090,
      'stopText': '0.1980',
      'stopDistancePercentText': '1.73%',
      'tp1Text': '0.2050',
      'tp2Text': '0.2090',
      'riskRewardTp1Text': '1:1.25',
      'riskRewardTp2Text': '1:2.50',
      'netRiskReward': 2.1,
      'netRiskRewardText': '1:2.10',
      'expectedMovePercent': 1.49,
      'expectedMovePercentText': '1.49%',
      'tradingMode': 'INTRADAY',
      'marketRegime': 'TREND_UP',
      'historicalSamples': 284,
      'historicalConfidence': 'HIGH',
      'firstMoveProbability020': 84.0,
      'firstMoveProbability030': 77.0,
      'firstMoveProbability050': 71.0,
      'firstMoveProbability075': 63.0,
      'firstMoveProbability100': 58.0,
      'stopFirstProbability': 23.0,
      'directionQuality': 90,
      'entryQuality': 85,
      'locationQuality': 82,
      'liquidityQuality': 80,
      'stopQuality': 78,
      'riskQuality': 75,
      'dataQuality': 'HIGH',
      'confirmedAt': '2026-08-31T12:00:00Z',
      'setupAgeSeconds': 45,
    });

    expect(message, contains('ВХОД ПОДТВЕРЖДЁН'));
    expect(message, contains('Совпадение факторов, не вероятность прибыли'));
    expect(message, contains('0.2010 — 0.2020'));
    expect(message, contains('Raw R:R TP2: 1:2.50'));
    expect(message, contains('0.30% → 77.0%'));
    expect(message, contains('Похожие наблюдения: 284 · HIGH'));
    expect(message, contains('Ордер не отправлен'));
  });

  test('incomplete ENTRY READY fails closed without empty fields', () {
    final String message = formatTelegramRelayMessage(<String, dynamic>{
      'kind': 'ENTRY_READY',
      'symbol': 'FARTCOINUSDT',
      'direction': 'LONG',
    });

    expect(message, contains('ДАННЫХ НЕДОСТАТОЧНО'));
    expect(message, contains('вход не разрешён'));
    expect(message, isNot(contains('—')));
  });

  test('suspension is clearly different from strategy invalidation', () {
    final String message = formatTelegramRelayMessage(<String, dynamic>{
      'kind': 'ENTRY_SUSPENDED',
      'symbol': 'BTCUSDT',
      'direction': 'SHORT',
      'stage': 'ENTRY_CONFIRMED',
      'reasonCodes': <String>['BID_ASK_STALE'],
    });

    expect(message, contains('ПРИОСТАНОВЛЕНО'));
    expect(message, contains('BID_ASK_STALE'));
    expect(message, contains('до нового ENTRY READY'));
  });

  test('confirmed gate loss produces an explicit cancelled-signal message', () {
    final String message = formatTelegramRelayMessage(<String, dynamic>{
      'kind': 'SIGNAL_INVALIDATED',
      'symbol': 'FARTCOINUSDT',
      'direction': 'LONG',
      'stage': 'ENTRY_CONFIRMED',
      'reasonCodes': <String>['PRICE_OUTSIDE_ENTRY_ZONE', 'HARD_BLOCK'],
    });

    expect(message, contains('СИГНАЛ ОТМЕНЁН'));
    expect(message, contains('PRICE_OUTSIDE_ENTRY_ZONE'));
    expect(message, contains('не входить'));
  });
}
