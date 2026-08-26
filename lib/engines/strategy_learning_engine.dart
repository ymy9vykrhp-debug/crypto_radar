import '../models/backtest_models.dart';
import '../models/execution_models.dart';
import '../models/learning_models.dart';

class StrategyLearningEngine {
  const StrategyLearningEngine._();

  static const int minimumCompletedTrades = 120;
  static const int minimumValidationTrades = 20;
  static const int minimumOutOfSampleTrades = 30;

  static LearningAssessment evaluate(BacktestReport report) {
    final List<ExecutionPerformance> confirmed = report.executionComparisons
        .where(
          (ExecutionPerformance performance) =>
              performance.entryVariant.mode == EntryMode.confirmed,
        )
        .toList(growable: false);
    final List<ExecutionPerformance> candidates = confirmed.isEmpty
        ? report.executionComparisons
        : confirmed;
    final ExecutionPerformance? leader = _leader(candidates);
    final int completed = leader?.trades ?? report.trades;
    final int validationTrades = leader?.validationTrades ?? 0;
    final int oosTrades = leader?.outOfSampleTrades ?? 0;
    final double validationR = leader?.validationAverageR ?? 0.0;
    final double oosR = leader?.outOfSampleAverageR ?? 0.0;
    final bool enoughSamples =
        completed >= minimumCompletedTrades &&
        validationTrades >= minimumValidationTrades &&
        oosTrades >= minimumOutOfSampleTrades;
    final bool stableEdge =
        leader != null &&
        leader.averageR > 0.0 &&
        leader.profitFactor >= 1.20 &&
        validationR > 0.0 &&
        oosR > 0.0;
    final bool drawdownSafe = leader != null && leader.maxDrawdownR <= 12.0;
    final bool canApply = enoughSamples && stableEdge && drawdownSafe;
    final LearningReadiness readiness = !enoughSamples
        ? LearningReadiness.collecting
        : canApply
        ? LearningReadiness.ready
        : LearningReadiness.guarded;
    final double progress = (completed / minimumCompletedTrades).clamp(
      0.0,
      1.0,
    );

    return LearningAssessment(
      symbol: report.symbol,
      readiness: readiness,
      completedTrades: completed,
      requiredTrades: minimumCompletedTrades,
      progress: progress,
      researchLeaderProfileId: leader?.profileId ?? '',
      researchLeaderLabel: leader?.label ?? 'Нет достаточных данных',
      validationTrades: validationTrades,
      validationAverageR: validationR,
      outOfSampleTrades: oosTrades,
      outOfSampleAverageR: oosR,
      canApplyLive: canApply,
      summary: _summary(
        readiness: readiness,
        completed: completed,
        validationTrades: validationTrades,
        oosTrades: oosTrades,
      ),
      factors: report.factors
          .map<LearnedFactor>(_learnFactor)
          .toList(growable: false),
    );
  }

  static ExecutionProfile? approvedProfile(BacktestReport report) {
    final LearningAssessment assessment = evaluate(report);
    if (!assessment.canApplyLive) return null;
    for (final ExecutionProfile profile in ExecutionProfile.backtestProfiles) {
      if (profile.id == assessment.researchLeaderProfileId &&
          profile.entryVariant.mode == EntryMode.confirmed) {
        return profile;
      }
    }
    return null;
  }

  static ExecutionPerformance? _leader(List<ExecutionPerformance> candidates) {
    ExecutionPerformance? best;
    double bestScore = double.negativeInfinity;
    for (final ExecutionPerformance candidate in candidates) {
      if (candidate.trades == 0) continue;
      final double confidence = candidate.trades / (candidate.trades + 40.0);
      final double validationConfidence =
          candidate.validationTrades / (candidate.validationTrades + 20.0);
      final double oosConfidence =
          candidate.outOfSampleTrades / (candidate.outOfSampleTrades + 30.0);
      final double score =
          candidate.averageR * confidence * 0.30 +
          candidate.validationAverageR * validationConfidence * 0.25 +
          candidate.outOfSampleAverageR * oosConfidence * 0.45 -
          candidate.maxDrawdownR / (candidate.trades + 20.0) * 0.20;
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    return best;
  }

  static LearnedFactor _learnFactor(FactorPerformance factor) {
    final double confidence = factor.trades / (factor.trades + 30.0);
    final double shrunkEdge = factor.averageR * confidence;
    final String recommendation;
    if (factor.trades < 30) {
      recommendation = 'СОБИРАТЬ ДАННЫЕ';
    } else if (shrunkEdge >= 0.15) {
      recommendation = 'УСИЛИТЬ ПОСЛЕ OOS';
    } else if (shrunkEdge <= -0.10) {
      recommendation = 'ОСЛАБИТЬ ПОСЛЕ OOS';
    } else {
      recommendation = 'НЕЙТРАЛЬНО';
    }
    return LearnedFactor(
      name: factor.name,
      trades: factor.trades,
      averageR: factor.averageR,
      confidence: confidence,
      shrunkEdgeR: shrunkEdge,
      recommendation: recommendation,
    );
  }

  static String _summary({
    required LearningReadiness readiness,
    required int completed,
    required int validationTrades,
    required int oosTrades,
  }) {
    switch (readiness) {
      case LearningReadiness.collecting:
        return 'Автоподстройка заблокирована: $completed/'
            '$minimumCompletedTrades завершённых сделок, '
            'validation $validationTrades/$minimumValidationTrades, '
            'OOS $oosTrades/$minimumOutOfSampleTrades.';
      case LearningReadiness.guarded:
        return 'Выборка собрана, но преимущество не подтвердилось одновременно '
            'на validation и OOS. Текущая стратегия не изменяется.';
      case LearningReadiness.ready:
        return 'Профиль подтвердил положительный Average R на validation и OOS. '
            'Разрешена ограниченная адаптация только будущих сигналов.';
    }
  }
}
