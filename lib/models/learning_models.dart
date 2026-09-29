class LearnedFactor {
  const LearnedFactor({
    required this.name,
    required this.trades,
    required this.averageR,
    required this.confidence,
    required this.shrunkEdgeR,
    required this.recommendation,
  });

  final String name;
  final int trades;
  final double averageR;
  final double confidence;
  final double shrunkEdgeR;
  final String recommendation;
}

enum LearningReadiness { collecting, guarded, ready }

extension LearningReadinessText on LearningReadiness {
  String get code {
    switch (this) {
      case LearningReadiness.collecting:
        return 'COLLECTING_DATA';
      case LearningReadiness.guarded:
        return 'OOS_GUARD';
      case LearningReadiness.ready:
        return 'READY_FOR_ADAPTATION';
    }
  }
}

class LearningAssessment {
  const LearningAssessment({
    required this.symbol,
    required this.readiness,
    required this.completedTrades,
    required this.requiredTrades,
    required this.progress,
    required this.researchLeaderProfileId,
    required this.researchLeaderLabel,
    required this.validationTrades,
    required this.validationAverageR,
    required this.outOfSampleTrades,
    required this.outOfSampleAverageR,
    required this.canApplyLive,
    required this.summary,
    required this.factors,
  });

  final String symbol;
  final LearningReadiness readiness;
  final int completedTrades;
  final int requiredTrades;
  final double progress;
  final String researchLeaderProfileId;
  final String researchLeaderLabel;
  final int validationTrades;
  final double validationAverageR;
  final int outOfSampleTrades;
  final double outOfSampleAverageR;
  final bool canApplyLive;
  final String summary;
  final List<LearnedFactor> factors;
}
