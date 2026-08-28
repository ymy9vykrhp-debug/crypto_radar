import 'package:crypto_radar/engines/trade_tracker.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const TradeTracker tracker = TradeTracker();
  final DateTime start = DateTime.utc(2026, 1, 1, 12);

  test('tracks entry, TP1 and TP2 without duplicate candle processing', () {
    RadarSignal signal = _signal(start);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 99.5, 102.0),
    );
    expect(signal.status, SignalStatus.inPosition);
    expect(signal.entryTime, isNotNull);

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 10)), 100.0, 108.0),
    );
    expect(signal.status, SignalStatus.tp1Hit);
    expect(signal.tp1Time, isNotNull);

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 15)), 100.0, 113.0),
    );
    expect(signal.status, SignalStatus.tp2Hit);
    expect(signal.tp2Time, isNotNull);
    expect(signal.resultR, closeTo(2.0, 0.001));
  });

  test('uses conservative stop when stop and target share one candle', () {
    RadarSignal signal = _signal(start);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 94.0, 113.0),
    );
    expect(signal.status, SignalStatus.stopped);
    expect(signal.resultR, -1.0);
  });

  test('expires a signal that did not enter in twelve hours', () {
    RadarSignal signal = _signal(start);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(hours: 13)), 110.0, 111.0),
    );
    expect(signal.status, SignalStatus.expired);
    expect(signal.stage, SignalStage.expired);
    expect(signal.entryTime, isNull);
  });

  test('scalp entry expires after fifteen minutes', () {
    RadarSignal signal = _signal(start, style: SignalStyle.scalp);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 15)), 110.0, 111.0),
    );
    expect(signal.status, SignalStatus.expired);
  });

  test('builds 1:1, 1:3, 1:5 and 1:9 probability options', () {
    final RadarSignal signal = _signal(start, style: SignalStyle.scalp);
    expect(
      signal.riskRewardEstimates.map<int>(
        (RiskRewardEstimate option) => option.rewardMultiple,
      ),
      <int>[1, 3, 5, 9],
    );
    expect(signal.leverage, lessThanOrEqualTo(10));
  });

  test('persists stable reason codes in the local journal record', () {
    final RadarSignal signal = _signal(start)
        .copyWith(reasonCodes: const <String>['BOS_CONFIRMED', 'RVOL_HIGH']);
    final RadarSignal restored = RadarSignal.fromJson(signal.toJson());

    expect(restored.reasonCodes, <String>['BOS_CONFIRMED', 'RVOL_HIGH']);
  });

  test('MFE and MAE only advance with newly consumed closed candles', () {
    RadarSignal signal = _signal(start);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 99.0, 102.0),
    );
    final double mfeAfterEntry = signal.mfeR;
    final double maeAfterEntry = signal.maeR;

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 50.0, 150.0),
    );
    expect(signal.mfeR, mfeAfterEntry);
    expect(signal.maeR, maeAfterEntry);

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 10)), 98.0, 106.0),
    );
    expect(signal.mfeR, closeTo(1.2, 0.0001));
    expect(signal.maeR, closeTo(0.4, 0.0001));
  });
}

RadarSignal _signal(DateTime time, {SignalStyle style = SignalStyle.standard}) {
  return RadarSignal(
    id: 'BTCUSDT:long:${time.millisecondsSinceEpoch}',
    symbol: 'BTCUSDT',
    time: time,
    direction: SignalDirection.long,
    style: style,
    referencePrice: 100.0,
    entryLow: 99.0,
    entryHigh: 101.0,
    stop: 95.0,
    tp1: 107.5,
    tp2: 112.5,
    score: 10,
    trend5m: Bias.bullish,
    trend15m: Bias.bullish,
    trend1h: Bias.bullish,
    rsi: 60.0,
    macd: 1.0,
    ema20: 101.0,
    ema50: 100.0,
    ema200: 90.0,
    relativeVolume: 1.5,
    rvolBias: Bias.bullish,
    fvgBias: Bias.bullish,
    orderBlockBias: Bias.bullish,
    liquidityBias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    leverage: 10,
    lastTrackedCandleTime: time,
    stage: SignalStage.entryConfirmed,
    entryConfirmedTime: time,
  );
}

Candle _candle(DateTime time, double low, double high) {
  return Candle(
    time: time,
    open: 100.0,
    high: high,
    low: low,
    close: 101.0,
    volume: 1000.0,
  );
}
