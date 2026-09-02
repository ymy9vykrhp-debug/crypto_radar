import 'package:crypto_radar/engines/first_move_probability_engine.dart';
import 'package:crypto_radar/engines/trade_tracker.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/first_move_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime cutoff = DateTime.utc(2026, 9, 1, 12);

  group('FirstMoveProbabilityEngine', () {
    test('uses only matching completed observations before signal time', () {
      final List<RadarSignal> history = <RadarSignal>[
        for (int index = 0; index < 50; index++)
          _signal(
            time: cutoff.subtract(Duration(minutes: index + 1)),
            id: 'past-$index',
            firstMove: FirstMoveRecord(
              tradingMode: 'INTRADAY',
              marketRegime: 'TREND_UP',
              volatilityRegime: 'NORMAL',
              hit020: index < 45,
              hit030: index < 40,
              hit050: index < 30,
              hit075: index < 20,
              hit100: index < 10,
              stopHitFirst: index >= 40,
              observationComplete: true,
            ),
            entered: true,
          ),
        // Future failures must never leak into the profile at [cutoff].
        for (int index = 0; index < 50; index++)
          _signal(
            time: cutoff.add(Duration(minutes: index + 1)),
            id: 'future-$index',
            firstMove: const FirstMoveRecord(
              tradingMode: 'INTRADAY',
              marketRegime: 'TREND_UP',
              volatilityRegime: 'NORMAL',
              stopHitFirst: true,
              observationComplete: true,
            ),
            entered: true,
          ),
      ];
      final RadarSignal candidate = _signal(time: cutoff, id: 'candidate');

      final RadarSignal profiled =
          FirstMoveProbabilityEngine.attachHistoricalProfile(
            signal: candidate,
            historicalSignals: history,
            asOf: cutoff,
          );

      expect(profiled.firstMove.historicalSamples, 50);
      expect(profiled.firstMove.probability020, 90.0);
      expect(profiled.firstMove.probability030, 80.0);
      expect(profiled.firstMove.probability100, 20.0);
      expect(profiled.firstMove.probabilityStopFirst, 20.0);
      expect(profiled.firstMove.historicalConfidence, HistoricalConfidence.low);
    });

    test('fails closed below minimum samples', () {
      final List<RadarSignal> history = <RadarSignal>[
        for (int index = 0; index < 49; index++)
          _signal(
            time: cutoff.subtract(Duration(minutes: index + 1)),
            id: 'sample-$index',
            firstMove: const FirstMoveRecord(
              tradingMode: 'INTRADAY',
              marketRegime: 'TREND_UP',
              volatilityRegime: 'NORMAL',
              hit030: true,
              observationComplete: true,
            ),
            entered: true,
          ),
      ];
      final RadarSignal candidate = _signal(
        time: cutoff,
        id: 'candidate',
        stage: SignalStage.entryConfirmed,
      );

      final RadarSignal gated =
          FirstMoveProbabilityEngine.enforceEntryPermission(
            FirstMoveProbabilityEngine.attachHistoricalProfile(
              signal: candidate,
              historicalSignals: history,
              asOf: cutoff,
            ),
          );

      expect(gated.stage, SignalStage.waitForTrigger);
      expect(gated.firstMove.probability030, isNull);
      expect(gated.reasonCodes, contains('HISTORICAL_SAMPLES_LOW'));
    });
  });

  group('TradeTracker first move', () {
    const TradeTracker tracker = TradeTracker();

    test('tracks LONG thresholds before structural stop', () {
      RadarSignal signal = _signal(
        time: cutoff,
        id: 'long',
        stage: SignalStage.entryConfirmed,
      );
      signal = tracker.consume(
        signal,
        _candle(
          cutoff.add(const Duration(minutes: 5)),
          low: 99.8,
          high: 100.55,
        ),
      );

      expect(signal.firstMove.hit020, isTrue);
      expect(signal.firstMove.hit030, isTrue);
      expect(signal.firstMove.hit050, isTrue);
      expect(signal.firstMove.hit075, isFalse);
      expect(signal.firstMove.time030, isNotNull);
    });

    test('tracks SHORT thresholds before structural stop', () {
      RadarSignal signal = _signal(
        time: cutoff,
        id: 'short',
        direction: SignalDirection.short,
        stop: 101,
        tp1: 98,
        tp2: 97,
        stage: SignalStage.entryConfirmed,
      );
      signal = tracker.consume(
        signal,
        _candle(
          cutoff.add(const Duration(minutes: 5)),
          low: 99.45,
          high: 100.2,
        ),
      );

      expect(signal.firstMove.hit020, isTrue);
      expect(signal.firstMove.hit050, isTrue);
      expect(signal.firstMove.hit075, isFalse);
    });

    test('same candle target and stop is conservatively stop first', () {
      RadarSignal signal = _signal(
        time: cutoff,
        id: 'ambiguous',
        stage: SignalStage.entryConfirmed,
      );
      signal = tracker.consume(
        signal,
        _candle(cutoff.add(const Duration(minutes: 5)), low: 98.5, high: 101.5),
      );

      expect(signal.status, SignalStatus.stopped);
      expect(signal.firstMove.stopHitFirst, isTrue);
      expect(signal.firstMove.hit020, isFalse);
      expect(signal.firstMove.observationComplete, isTrue);
    });
  });
}

RadarSignal _signal({
  required DateTime time,
  required String id,
  SignalDirection direction = SignalDirection.long,
  double stop = 99,
  double tp1 = 102,
  double tp2 = 103,
  SignalStage stage = SignalStage.setupFound,
  FirstMoveRecord firstMove = const FirstMoveRecord(
    tradingMode: 'INTRADAY',
    marketRegime: 'TREND_UP',
    volatilityRegime: 'NORMAL',
  ),
  bool entered = false,
}) {
  return RadarSignal(
    id: id,
    symbol: 'BTCUSDT',
    time: time,
    direction: direction,
    referencePrice: 100,
    entryLow: 99.9,
    entryHigh: 100.1,
    stop: stop,
    tp1: tp1,
    tp2: tp2,
    score: 90,
    trend5m: Bias.bullish,
    trend15m: Bias.bullish,
    trend1h: Bias.bullish,
    rsi: 55,
    macd: 1,
    ema20: 101,
    ema50: 99,
    ema200: 95,
    relativeVolume: 1.4,
    rvolBias: Bias.bullish,
    fvgBias: Bias.bullish,
    orderBlockBias: Bias.bullish,
    liquidityBias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    stage: stage,
    entryConfirmedTime: stage == SignalStage.entryConfirmed ? time : null,
    entryTime: entered ? time : null,
    status: entered ? SignalStatus.cancelled : SignalStatus.waitingEntry,
    exitTime: entered ? time.add(const Duration(minutes: 5)) : null,
    lastTrackedCandleTime: time,
    firstMove: firstMove,
  );
}

Candle _candle(DateTime time, {required double low, required double high}) {
  return Candle(
    time: time,
    open: 100,
    high: high,
    low: low,
    close: 100,
    volume: 1000,
  );
}
