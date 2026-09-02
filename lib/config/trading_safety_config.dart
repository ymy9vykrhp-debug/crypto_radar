/// Central fail-closed limits shared by live decisions, alerts and research.
///
/// These values describe unleveraged price movement. Leverage must never be
/// used to satisfy target-distance or reward/risk requirements.
class TradingSafetyConfig {
  const TradingSafetyConfig._();

  static const double minReadyMovePercent = 1.00;
  static const double minNetRiskReward = 1.80;
  static const double minStopAtrBuffer = 0.25;
  static const double spreadBufferMultiplier = 3.0;
  static const double slippageBufferMultiplier = 2.0;
  static const double tickBufferMultiplier = 3.0;
  static const double maxReadySpreadPercent = 0.10;

  static const int minProbabilitySamples = 50;
  static const double readinessProbabilityTargetPercent = 0.30;
  static const double minReadyFirstMoveProbabilityPercent = 70.0;
  static const List<double> firstMoveThresholdsPercent = <double>[
    0.20,
    0.30,
    0.50,
    0.75,
    1.00,
  ];

  static const Duration standardSignalMaxAge = Duration(hours: 12);
  static const Duration scalpSignalMaxAge = Duration(minutes: 15);
}
