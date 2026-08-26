import 'package:crypto_radar/engines/strategy_learning_engine.dart';
import 'package:crypto_radar/models/backtest_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/learning_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('small OOS sample cannot change the live strategy', () {
    final BacktestReport report = _report(
      confirmed: _performance(
        profileId: 'bos_atr',
        entryVariant: EntryVariant.bosConfirmation,
        trades: 20,
        validationTrades: 4,
        outOfSampleTrades: 4,
      ),
      aggressive: _performance(
        profileId: 'immediate_atr',
        entryVariant: EntryVariant.immediate,
        trades: 170,
        validationTrades: 34,
        outOfSampleTrades: 34,
        averageR: 1.2,
        validationR: 1.0,
        outOfSampleR: 1.1,
      ),
    );

    final LearningAssessment result = StrategyLearningEngine.evaluate(report);

    expect(result.readiness, LearningReadiness.collecting);
    expect(result.canApplyLive, isFalse);
    expect(result.researchLeaderProfileId, 'bos_atr');
    expect(StrategyLearningEngine.approvedProfile(report), isNull);
  });

  test('confirmed profile is approved only after validation and OOS gates', () {
    final BacktestReport report = _report(
      confirmed: _performance(
        profileId: 'bos_atr',
        entryVariant: EntryVariant.bosConfirmation,
        trades: 140,
        validationTrades: 28,
        outOfSampleTrades: 35,
        averageR: 0.35,
        validationR: 0.28,
        outOfSampleR: 0.22,
      ),
      aggressive: _performance(
        profileId: 'immediate_atr',
        entryVariant: EntryVariant.immediate,
        trades: 180,
        validationTrades: 36,
        outOfSampleTrades: 36,
        averageR: 0.9,
        validationR: 0.8,
        outOfSampleR: 0.7,
      ),
    );

    final LearningAssessment result = StrategyLearningEngine.evaluate(report);

    expect(result.readiness, LearningReadiness.ready);
    expect(result.canApplyLive, isTrue);
    expect(StrategyLearningEngine.approvedProfile(report)?.id, 'bos_atr');
  });
}

BacktestReport _report({
  required ExecutionPerformance confirmed,
  required ExecutionPerformance aggressive,
}) {
  return BacktestReport(
    symbol: 'FARTCOINUSDT',
    startedAt: DateTime.utc(2026, 1, 1),
    finishedAt: DateTime.utc(2026, 2, 1),
    signals: confirmed.signals,
    trades: confirmed.trades,
    winRate: 40,
    tp1Percent: 45,
    tp2Percent: 20,
    stopPercent: 55,
    averageR: confirmed.averageR,
    profitFactor: confirmed.profitFactor,
    maxDrawdownR: confirmed.maxDrawdownR,
    averageMovePercent: 1,
    averageTradeMinutes: 30,
    factors: const <FactorPerformance>[
      FactorPerformance(name: 'RSI', trades: 10, winRate: 40, averageR: 0.2),
    ],
    executionComparisons: <ExecutionPerformance>[aggressive, confirmed],
  );
}

ExecutionPerformance _performance({
  required String profileId,
  required EntryVariant entryVariant,
  required int trades,
  required int validationTrades,
  required int outOfSampleTrades,
  double averageR = 0.4,
  double validationR = 0.3,
  double outOfSampleR = 0.25,
}) {
  return ExecutionPerformance(
    profileId: profileId,
    label: profileId,
    entryVariant: entryVariant,
    stopVariant: StopVariant.structuralAtr,
    signals: trades + 10,
    trades: trades,
    winRate: 40,
    averageR: averageR,
    profitFactor: 1.5,
    maxDrawdownR: 6,
    stopThenTargetPercent: 30,
    trainTrades: trades - validationTrades - outOfSampleTrades,
    trainAverageR: averageR,
    validationTrades: validationTrades,
    validationAverageR: validationR,
    outOfSampleTrades: outOfSampleTrades,
    outOfSampleAverageR: outOfSampleR,
  );
}
