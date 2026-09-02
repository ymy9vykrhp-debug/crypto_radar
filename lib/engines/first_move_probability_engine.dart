import '../config/trading_safety_config.dart';
import '../models/first_move_models.dart';
import '../models/execution_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';

class FirstMoveProbabilityEngine {
  const FirstMoveProbabilityEngine._();

  static const Set<String> _permissionCodes = <String>{
    'HISTORICAL_SAMPLES_LOW',
    'FIRST_MOVE_PROBABILITY_LOW',
  };

  static RadarSignal attachHistoricalProfile({
    required RadarSignal signal,
    required Iterable<RadarSignal> historicalSignals,
    Iterable<FirstMoveHistoricalBucket> historicalBuckets =
        const <FirstMoveHistoricalBucket>[],
    DateTime? asOf,
    FeeModel feeModel = const FeeModel(),
  }) {
    final DateTime cutoff = (asOf ?? signal.time).toUtc();
    final _Counts counts = _Counts();
    for (final RadarSignal historical in historicalSignals) {
      if (!historical.time.toUtc().isBefore(cutoff) ||
          !historical.firstMove.observationComplete ||
          historical.entryTime == null ||
          !_matches(signal, historical)) {
        continue;
      }
      counts.addRecord(historical.firstMove);
    }
    for (final FirstMoveHistoricalBucket bucket in historicalBuckets) {
      if (_matchesBucket(signal, bucket)) counts.addBucket(bucket);
    }
    final bool enough =
        counts.samples >= TradingSafetyConfig.minProbabilitySamples;
    final HistoricalConfidence confidence = !enough
        ? HistoricalConfidence.insufficient
        : counts.samples >= 250
        ? HistoricalConfidence.high
        : counts.samples >= 100
        ? HistoricalConfidence.medium
        : HistoricalConfidence.low;
    final FirstMoveRecord profile = signal.firstMove.copyWith(
      netRiskReward: _netRiskReward(signal, feeModel),
      historicalSamples: counts.samples,
      historicalConfidence: confidence,
      clearProbabilities: !enough,
      probability020: enough ? counts.percent(counts.hit020) : null,
      probability030: enough ? counts.percent(counts.hit030) : null,
      probability050: enough ? counts.percent(counts.hit050) : null,
      probability075: enough ? counts.percent(counts.hit075) : null,
      probability100: enough ? counts.percent(counts.hit100) : null,
      probabilityStopFirst: enough ? counts.percent(counts.stopFirst) : null,
    );
    return signal.copyWith(firstMove: profile);
  }

  static double _netRiskReward(RadarSignal signal, FeeModel feeModel) {
    final double entry = signal.direction == SignalDirection.long
        ? signal.entryHigh
        : signal.entryLow;
    if (entry <= 0.0 || signal.stop <= 0.0 || signal.tp1 <= 0.0) return 0.0;
    final double rewardPercent = signal.direction == SignalDirection.long
        ? (signal.tp1 - entry) / entry * 100.0
        : (entry - signal.tp1) / entry * 100.0;
    final double riskPercent = (entry - signal.stop).abs() / entry * 100.0;
    final double spreadPercent = signal.firstMove.spreadPercent > 0.0
        ? signal.firstMove.spreadPercent
        : feeModel.estimatedSpreadPercent;
    final double targetCosts =
        feeModel.feePercent(feeModel.entryOrderType) +
        feeModel.feePercent(feeModel.targetExitOrderType) +
        feeModel.entrySlippagePercent +
        feeModel.targetSlippagePercent +
        spreadPercent;
    final double stopCosts =
        feeModel.feePercent(feeModel.entryOrderType) +
        feeModel.feePercent(feeModel.stopOrderType) +
        feeModel.entrySlippagePercent +
        feeModel.stopSlippagePercent +
        spreadPercent +
        feeModel.safetyBufferPercent;
    final double denominator = riskPercent + stopCosts;
    if (rewardPercent <= targetCosts || denominator <= 0.0) return 0.0;
    return (rewardPercent - targetCosts) / denominator;
  }

  /// Historical probability is a permission filter, never a replacement for
  /// the structural setup. A signal without enough comparable closed trades
  /// remains in WAIT and cannot silently enter a position.
  static RadarSignal enforceEntryPermission(RadarSignal signal) {
    final FirstMoveRecord profile = signal.firstMove;
    final bool enough = profile.hasEnoughSamples;
    final double? probability = profile.probabilityFor(
      TradingSafetyConfig.readinessProbabilityTargetPercent,
    );
    final bool probabilityPass =
        enough &&
        probability != null &&
        probability >= TradingSafetyConfig.minReadyFirstMoveProbabilityPercent;
    final List<String> reasons = signal.reasonCodes
        .where((String code) => !_permissionCodes.contains(code))
        .toList(growable: true);
    if (!enough) {
      reasons.add('HISTORICAL_SAMPLES_LOW');
    } else if (!probabilityPass) {
      reasons.add('FIRST_MOVE_PROBABILITY_LOW');
    }
    if (probabilityPass || signal.status != SignalStatus.waitingEntry) {
      return signal.copyWith(reasonCodes: reasons);
    }
    return signal.copyWith(
      stage: SignalStage.waitForTrigger,
      executionAction: 'WAIT_FOR_HISTORICAL_EDGE',
      reasonCodes: reasons,
    );
  }

  static List<FirstMoveHistoricalBucket> buildHistoricalBuckets(
    Iterable<RadarSignal> signals,
  ) {
    final Map<String, _BucketBuilder> builders = <String, _BucketBuilder>{};
    for (final RadarSignal signal in signals) {
      if (!signal.firstMove.observationComplete || signal.entryTime == null) {
        continue;
      }
      final String key = _key(signal);
      (builders[key] ??= _BucketBuilder(signal)).add(signal.firstMove);
    }
    return builders.values
        .map<FirstMoveHistoricalBucket>(
          (_BucketBuilder builder) => builder.build(),
        )
        .toList(growable: false);
  }

  static List<ProbabilityCalibrationBucket> buildCalibrationBuckets(
    Iterable<RadarSignal> signals,
  ) {
    const List<(int, int)> ranges = <(int, int)>[
      (50, 55),
      (55, 60),
      (60, 65),
      (65, 70),
      (70, 75),
      (75, 80),
      (80, 85),
      (85, 101),
    ];
    final List<ProbabilityCalibrationBucket> result =
        <ProbabilityCalibrationBucket>[];
    for (final (int lower, int upper) in ranges) {
      final List<RadarSignal> samples = signals
          .where((RadarSignal signal) {
            final double? predicted = signal.firstMove.probability030;
            return signal.firstMove.observationComplete &&
                predicted != null &&
                predicted >= lower &&
                predicted < upper;
          })
          .toList(growable: false);
      final int hits = samples
          .where((RadarSignal signal) => signal.firstMove.hit030)
          .length;
      result.add(
        ProbabilityCalibrationBucket(
          lowerBound: lower,
          upperBound: upper,
          samples: samples.length,
          actualSuccessPercent: samples.isEmpty
              ? 0.0
              : hits / samples.length * 100.0,
        ),
      );
    }
    return List<ProbabilityCalibrationBucket>.unmodifiable(result);
  }

  static String stopDistanceBucket(RadarSignal signal) {
    final double entry = signal.entryPrice;
    final double percent = entry <= 0.0 ? 0.0 : signal.risk / entry * 100.0;
    if (percent < 0.35) return 'TIGHT';
    if (percent < 0.75) return 'MEDIUM';
    return 'WIDE';
  }

  static bool _matches(RadarSignal candidate, RadarSignal historical) {
    return candidate.symbol == historical.symbol &&
        candidate.direction == historical.direction &&
        candidate.firstMove.tradingMode == historical.firstMove.tradingMode &&
        candidate.firstMove.marketRegime == historical.firstMove.marketRegime &&
        candidate.firstMove.volatilityRegime ==
            historical.firstMove.volatilityRegime &&
        stopDistanceBucket(candidate) == stopDistanceBucket(historical);
  }

  static bool _matchesBucket(
    RadarSignal candidate,
    FirstMoveHistoricalBucket bucket,
  ) {
    return candidate.symbol == bucket.symbol &&
        candidate.direction.name.toUpperCase() == bucket.direction &&
        candidate.firstMove.tradingMode == bucket.tradingMode &&
        candidate.firstMove.marketRegime == bucket.marketRegime &&
        candidate.firstMove.volatilityRegime == bucket.volatilityRegime &&
        stopDistanceBucket(candidate) == bucket.stopDistanceBucket;
  }

  static String _key(RadarSignal signal) => <String>[
    signal.symbol,
    signal.direction.name.toUpperCase(),
    signal.firstMove.tradingMode,
    signal.firstMove.marketRegime,
    signal.firstMove.volatilityRegime,
    stopDistanceBucket(signal),
  ].join('|');
}

class _Counts {
  int samples = 0;
  int hit020 = 0;
  int hit030 = 0;
  int hit050 = 0;
  int hit075 = 0;
  int hit100 = 0;
  int stopFirst = 0;

  void addRecord(FirstMoveRecord record) {
    samples++;
    if (record.hit020) hit020++;
    if (record.hit030) hit030++;
    if (record.hit050) hit050++;
    if (record.hit075) hit075++;
    if (record.hit100) hit100++;
    if (record.stopHitFirst) stopFirst++;
  }

  void addBucket(FirstMoveHistoricalBucket bucket) {
    samples += bucket.samples;
    hit020 += bucket.hit020;
    hit030 += bucket.hit030;
    hit050 += bucket.hit050;
    hit075 += bucket.hit075;
    hit100 += bucket.hit100;
    stopFirst += bucket.stopFirst;
  }

  double percent(int hits) => samples == 0 ? 0.0 : hits / samples * 100.0;
}

class _BucketBuilder {
  _BucketBuilder(this.template);

  final RadarSignal template;
  final _Counts counts = _Counts();

  void add(FirstMoveRecord record) => counts.addRecord(record);

  FirstMoveHistoricalBucket build() => FirstMoveHistoricalBucket(
    symbol: template.symbol,
    direction: template.direction.name.toUpperCase(),
    tradingMode: template.firstMove.tradingMode,
    marketRegime: template.firstMove.marketRegime,
    volatilityRegime: template.firstMove.volatilityRegime,
    stopDistanceBucket: FirstMoveProbabilityEngine.stopDistanceBucket(template),
    samples: counts.samples,
    hit020: counts.hit020,
    hit030: counts.hit030,
    hit050: counts.hit050,
    hit075: counts.hit075,
    hit100: counts.hit100,
    stopFirst: counts.stopFirst,
  );
}
