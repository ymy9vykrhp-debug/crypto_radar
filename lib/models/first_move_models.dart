import '../config/trading_safety_config.dart';

enum HistoricalConfidence { insufficient, low, medium, high }

extension HistoricalConfidenceText on HistoricalConfidence {
  String get code => switch (this) {
    HistoricalConfidence.insufficient => 'INSUFFICIENT_DATA',
    HistoricalConfidence.low => 'LOW',
    HistoricalConfidence.medium => 'MEDIUM',
    HistoricalConfidence.high => 'HIGH',
  };
}

class FirstMoveRecord {
  const FirstMoveRecord({
    this.tradingMode = 'INTRADAY',
    this.marketRegime = 'UNKNOWN',
    this.volatilityRegime = 'UNKNOWN',
    this.btcState = 'UNKNOWN',
    this.expectedMovePercent = 0.0,
    this.netRiskReward = 0.0,
    this.atrPercent = 0.0,
    this.spreadPercent = 0.0,
    this.historicalSamples = 0,
    this.historicalConfidence = HistoricalConfidence.insufficient,
    this.probability020,
    this.probability030,
    this.probability050,
    this.probability075,
    this.probability100,
    this.probabilityStopFirst,
    this.hit020 = false,
    this.hit030 = false,
    this.hit050 = false,
    this.hit075 = false,
    this.hit100 = false,
    this.time020,
    this.time030,
    this.time050,
    this.time075,
    this.time100,
    this.stopHitFirst = false,
    this.observationComplete = false,
  });

  final String tradingMode;
  final String marketRegime;
  final String volatilityRegime;
  final String btcState;
  final double expectedMovePercent;
  final double netRiskReward;
  final double atrPercent;
  final double spreadPercent;
  final int historicalSamples;
  final HistoricalConfidence historicalConfidence;
  final double? probability020;
  final double? probability030;
  final double? probability050;
  final double? probability075;
  final double? probability100;
  final double? probabilityStopFirst;
  final bool hit020;
  final bool hit030;
  final bool hit050;
  final bool hit075;
  final bool hit100;
  final DateTime? time020;
  final DateTime? time030;
  final DateTime? time050;
  final DateTime? time075;
  final DateTime? time100;
  final bool stopHitFirst;
  final bool observationComplete;

  bool get hasEnoughSamples =>
      historicalSamples >= TradingSafetyConfig.minProbabilitySamples;

  double? probabilityFor(double thresholdPercent) {
    if (thresholdPercent == 0.20) return probability020;
    if (thresholdPercent == 0.30) return probability030;
    if (thresholdPercent == 0.50) return probability050;
    if (thresholdPercent == 0.75) return probability075;
    if (thresholdPercent == 1.00) return probability100;
    return null;
  }

  bool hitFor(double thresholdPercent) {
    if (thresholdPercent == 0.20) return hit020;
    if (thresholdPercent == 0.30) return hit030;
    if (thresholdPercent == 0.50) return hit050;
    if (thresholdPercent == 0.75) return hit075;
    if (thresholdPercent == 1.00) return hit100;
    return false;
  }

  DateTime? timeFor(double thresholdPercent) {
    if (thresholdPercent == 0.20) return time020;
    if (thresholdPercent == 0.30) return time030;
    if (thresholdPercent == 0.50) return time050;
    if (thresholdPercent == 0.75) return time075;
    if (thresholdPercent == 1.00) return time100;
    return null;
  }

  FirstMoveRecord copyWith({
    String? tradingMode,
    String? marketRegime,
    String? volatilityRegime,
    String? btcState,
    double? expectedMovePercent,
    double? netRiskReward,
    double? atrPercent,
    double? spreadPercent,
    int? historicalSamples,
    HistoricalConfidence? historicalConfidence,
    double? probability020,
    double? probability030,
    double? probability050,
    double? probability075,
    double? probability100,
    double? probabilityStopFirst,
    bool clearProbabilities = false,
    bool? hit020,
    bool? hit030,
    bool? hit050,
    bool? hit075,
    bool? hit100,
    DateTime? time020,
    DateTime? time030,
    DateTime? time050,
    DateTime? time075,
    DateTime? time100,
    bool? stopHitFirst,
    bool? observationComplete,
  }) {
    return FirstMoveRecord(
      tradingMode: tradingMode ?? this.tradingMode,
      marketRegime: marketRegime ?? this.marketRegime,
      volatilityRegime: volatilityRegime ?? this.volatilityRegime,
      btcState: btcState ?? this.btcState,
      expectedMovePercent: expectedMovePercent ?? this.expectedMovePercent,
      netRiskReward: netRiskReward ?? this.netRiskReward,
      atrPercent: atrPercent ?? this.atrPercent,
      spreadPercent: spreadPercent ?? this.spreadPercent,
      historicalSamples: historicalSamples ?? this.historicalSamples,
      historicalConfidence: historicalConfidence ?? this.historicalConfidence,
      probability020: clearProbabilities
          ? null
          : probability020 ?? this.probability020,
      probability030: clearProbabilities
          ? null
          : probability030 ?? this.probability030,
      probability050: clearProbabilities
          ? null
          : probability050 ?? this.probability050,
      probability075: clearProbabilities
          ? null
          : probability075 ?? this.probability075,
      probability100: clearProbabilities
          ? null
          : probability100 ?? this.probability100,
      probabilityStopFirst: clearProbabilities
          ? null
          : probabilityStopFirst ?? this.probabilityStopFirst,
      hit020: hit020 ?? this.hit020,
      hit030: hit030 ?? this.hit030,
      hit050: hit050 ?? this.hit050,
      hit075: hit075 ?? this.hit075,
      hit100: hit100 ?? this.hit100,
      time020: time020 ?? this.time020,
      time030: time030 ?? this.time030,
      time050: time050 ?? this.time050,
      time075: time075 ?? this.time075,
      time100: time100 ?? this.time100,
      stopHitFirst: stopHitFirst ?? this.stopHitFirst,
      observationComplete: observationComplete ?? this.observationComplete,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'tradingMode': tradingMode,
    'marketRegime': marketRegime,
    'volatilityRegime': volatilityRegime,
    'btcState': btcState,
    'expectedMovePercent': expectedMovePercent,
    'netRiskReward': netRiskReward,
    'atrPercent': atrPercent,
    'spreadPercent': spreadPercent,
    'historicalSamples': historicalSamples,
    'historicalConfidence': historicalConfidence.name,
    'probability020': probability020,
    'probability030': probability030,
    'probability050': probability050,
    'probability075': probability075,
    'probability100': probability100,
    'probabilityStopFirst': probabilityStopFirst,
    'hit020': hit020,
    'hit030': hit030,
    'hit050': hit050,
    'hit075': hit075,
    'hit100': hit100,
    'time020': time020?.toIso8601String(),
    'time030': time030?.toIso8601String(),
    'time050': time050?.toIso8601String(),
    'time075': time075?.toIso8601String(),
    'time100': time100?.toIso8601String(),
    'stopHitFirst': stopHitFirst,
    'observationComplete': observationComplete,
  };

  factory FirstMoveRecord.fromJson(Map<String, dynamic> json) {
    return FirstMoveRecord(
      tradingMode: json['tradingMode']?.toString() ?? 'INTRADAY',
      marketRegime: json['marketRegime']?.toString() ?? 'UNKNOWN',
      volatilityRegime: json['volatilityRegime']?.toString() ?? 'UNKNOWN',
      btcState: json['btcState']?.toString() ?? 'UNKNOWN',
      expectedMovePercent: _double(json['expectedMovePercent']),
      netRiskReward: _double(json['netRiskReward']),
      atrPercent: _double(json['atrPercent']),
      spreadPercent: _double(json['spreadPercent']),
      historicalSamples: _int(json['historicalSamples']),
      historicalConfidence: HistoricalConfidence.values.firstWhere(
        (HistoricalConfidence value) =>
            value.name == json['historicalConfidence']?.toString(),
        orElse: () => HistoricalConfidence.insufficient,
      ),
      probability020: _nullableDouble(json['probability020']),
      probability030: _nullableDouble(json['probability030']),
      probability050: _nullableDouble(json['probability050']),
      probability075: _nullableDouble(json['probability075']),
      probability100: _nullableDouble(json['probability100']),
      probabilityStopFirst: _nullableDouble(json['probabilityStopFirst']),
      hit020: json['hit020'] == true,
      hit030: json['hit030'] == true,
      hit050: json['hit050'] == true,
      hit075: json['hit075'] == true,
      hit100: json['hit100'] == true,
      time020: _date(json['time020']),
      time030: _date(json['time030']),
      time050: _date(json['time050']),
      time075: _date(json['time075']),
      time100: _date(json['time100']),
      stopHitFirst: json['stopHitFirst'] == true,
      observationComplete: json['observationComplete'] == true,
    );
  }
}

class FirstMoveHistoricalBucket {
  const FirstMoveHistoricalBucket({
    required this.symbol,
    required this.direction,
    required this.tradingMode,
    required this.marketRegime,
    required this.volatilityRegime,
    required this.stopDistanceBucket,
    required this.samples,
    required this.hit020,
    required this.hit030,
    required this.hit050,
    required this.hit075,
    required this.hit100,
    required this.stopFirst,
  });

  final String symbol;
  final String direction;
  final String tradingMode;
  final String marketRegime;
  final String volatilityRegime;
  final String stopDistanceBucket;
  final int samples;
  final int hit020;
  final int hit030;
  final int hit050;
  final int hit075;
  final int hit100;
  final int stopFirst;

  double probabilityFor(double thresholdPercent) {
    if (samples <= 0) return 0.0;
    final int hits = thresholdPercent == 0.20
        ? hit020
        : thresholdPercent == 0.30
        ? hit030
        : thresholdPercent == 0.50
        ? hit050
        : thresholdPercent == 0.75
        ? hit075
        : hit100;
    return hits / samples * 100.0;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'symbol': symbol,
    'direction': direction,
    'tradingMode': tradingMode,
    'marketRegime': marketRegime,
    'volatilityRegime': volatilityRegime,
    'stopDistanceBucket': stopDistanceBucket,
    'samples': samples,
    'hit020': hit020,
    'hit030': hit030,
    'hit050': hit050,
    'hit075': hit075,
    'hit100': hit100,
    'stopFirst': stopFirst,
  };

  factory FirstMoveHistoricalBucket.fromJson(Map<String, dynamic> json) {
    return FirstMoveHistoricalBucket(
      symbol: json['symbol']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      tradingMode: json['tradingMode']?.toString() ?? 'INTRADAY',
      marketRegime: json['marketRegime']?.toString() ?? 'UNKNOWN',
      volatilityRegime: json['volatilityRegime']?.toString() ?? 'UNKNOWN',
      stopDistanceBucket: json['stopDistanceBucket']?.toString() ?? 'UNKNOWN',
      samples: _int(json['samples']),
      hit020: _int(json['hit020']),
      hit030: _int(json['hit030']),
      hit050: _int(json['hit050']),
      hit075: _int(json['hit075']),
      hit100: _int(json['hit100']),
      stopFirst: _int(json['stopFirst']),
    );
  }
}

class ProbabilityCalibrationBucket {
  const ProbabilityCalibrationBucket({
    required this.lowerBound,
    required this.upperBound,
    required this.samples,
    required this.actualSuccessPercent,
  });

  final int lowerBound;
  final int upperBound;
  final int samples;
  final double actualSuccessPercent;

  String get label => upperBound > 85 ? '85+' : '$lowerBound–$upperBound';

  Map<String, Object?> toJson() => <String, Object?>{
    'lowerBound': lowerBound,
    'upperBound': upperBound,
    'samples': samples,
    'actualSuccessPercent': actualSuccessPercent,
  };

  factory ProbabilityCalibrationBucket.fromJson(Map<String, dynamic> json) {
    return ProbabilityCalibrationBucket(
      lowerBound: _int(json['lowerBound']),
      upperBound: _int(json['upperBound']),
      samples: _int(json['samples']),
      actualSuccessPercent: _double(json['actualSuccessPercent']),
    );
  }
}

double _double(Object? value) => double.tryParse('$value') ?? 0.0;

double? _nullableDouble(Object? value) =>
    value == null ? null : double.tryParse('$value');

int _int(Object? value) => int.tryParse('$value') ?? 0;

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse('$value');
