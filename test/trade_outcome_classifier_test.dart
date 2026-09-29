import 'package:crypto_radar/engines/trade_outcome_classifier.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('STOP_THEN_TARGET is not mislabeled as wrong direction', () {
    final RadarSignal classified = TradeOutcomeClassifier.classify(
      _signal().copyWith(
        status: SignalStatus.stopped,
        stage: SignalStage.stopped,
        entryTime: DateTime.utc(2026, 8, 29, 12, 1),
        entryConfirmedTime: DateTime.utc(2026, 8, 29, 12),
        exitTime: DateTime.utc(2026, 8, 29, 12, 5),
        resultR: -1.0,
        postStopTp1: true,
        overshootAtr: 0.5,
        falseBreakoutState: FalseBreakoutState.confirmed,
        hasCostAwareResult: true,
        rawResultR: -1.0,
        netResultR: -1.1,
        executionModelVersion: 'EXECUTION_MODEL_V2',
      ),
    );

    expect(classified.outcomeFlags, contains(TradeOutcomeFlag.stopThenTarget));
    expect(
      classified.outcomeFlags,
      contains(TradeOutcomeFlag.liquiditySweepBeforeMove),
    );
    expect(classified.outcomeFlags, contains(TradeOutcomeFlag.stopTooTight));
    expect(
      classified.outcomeFlags,
      isNot(contains(TradeOutcomeFlag.directionWrong)),
    );
    expect(classified.qualityFlags, contains(TradeQualityFlag.goodDirection));
    expect(classified.qualityFlags, contains(TradeQualityFlag.goodTrade));
  });

  test('outcome flags and engine versions survive journal JSON round trip', () {
    final RadarSignal source = TradeOutcomeClassifier.classify(
      _signal().copyWith(
        status: SignalStatus.stopped,
        stage: SignalStage.stopped,
        entryTime: DateTime.utc(2026, 8, 29, 12, 1),
        entryConfirmedTime: DateTime.utc(2026, 8, 29, 12),
        exitTime: DateTime.utc(2026, 8, 29, 12, 5),
        resultR: -1.0,
        overshootAtr: 1.2,
      ),
    );
    final RadarSignal restored = RadarSignal.fromJson(source.toJson());

    expect(restored.outcomeFlags, source.outcomeFlags);
    expect(restored.qualityFlags, source.qualityFlags);
    expect(restored.strategyVersion, 'STRATEGY_V1');
    expect(restored.entryEngineVersion, 'ENTRY_ENGINE_V2');
    expect(restored.stopEngineVersion, 'STOP_ENGINE_V2');
    expect(restored.liquidityEngineVersion, 'LIQUIDITY_ENGINE_V1');
  });
}

RadarSignal _signal() {
  return RadarSignal(
    id: 'outcome-test',
    symbol: 'BTCUSDT',
    time: DateTime.utc(2026, 8, 29, 12),
    direction: SignalDirection.long,
    referencePrice: 100.0,
    entryLow: 99.9,
    entryHigh: 100.1,
    stop: 99.0,
    tp1: 101.0,
    tp2: 103.0,
    score: 85,
    trend5m: Bias.bullish,
    trend15m: Bias.bullish,
    trend1h: Bias.bullish,
    rsi: 55.0,
    macd: 0.1,
    ema20: 101.0,
    ema50: 100.0,
    ema200: 99.0,
    relativeVolume: 1.2,
    rvolBias: Bias.bullish,
    fvgBias: Bias.bullish,
    orderBlockBias: Bias.bullish,
    liquidityBias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    qualities: const SignalQualityScores(
      direction: 85,
      entry: 80,
      stop: 80,
      risk: 80,
      location: 80,
      liquidity: 90,
      data: 95,
      setup: 85,
    ),
  );
}
