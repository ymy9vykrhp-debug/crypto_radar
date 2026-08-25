import 'market_models.dart';

enum SignalDirection { long, short }

extension SignalDirectionText on SignalDirection {
  String get label => this == SignalDirection.long ? 'LONG' : 'SHORT';

  Bias get bias => this == SignalDirection.long ? Bias.bullish : Bias.bearish;
}

enum SignalStyle { standard, scalp }

extension SignalStyleText on SignalStyle {
  String get label => this == SignalStyle.scalp ? 'SCALP 1м' : 'STANDARD';
}

class RiskRewardEstimate {
  const RiskRewardEstimate({
    required this.rewardMultiple,
    required this.targetPrice,
    required this.probabilityPercent,
    required this.expectedR,
  });

  final int rewardMultiple;
  final double targetPrice;
  final double probabilityPercent;
  final double expectedR;

  String get label => '1:$rewardMultiple';
}

enum SignalStatus {
  waitingEntry,
  inPosition,
  tp1Hit,
  tp2Hit,
  stopped,
  cancelled,
}

extension SignalStatusText on SignalStatus {
  String get code {
    switch (this) {
      case SignalStatus.waitingEntry:
        return 'WAITING_ENTRY';
      case SignalStatus.inPosition:
        return 'IN_POSITION';
      case SignalStatus.tp1Hit:
        return 'TP1_HIT';
      case SignalStatus.tp2Hit:
        return 'TP2_HIT';
      case SignalStatus.stopped:
        return 'STOPPED';
      case SignalStatus.cancelled:
        return 'CANCELLED';
    }
  }

  bool get isActive =>
      this == SignalStatus.waitingEntry ||
      this == SignalStatus.inPosition ||
      this == SignalStatus.tp1Hit;
}

class RadarSignal {
  const RadarSignal({
    required this.id,
    required this.symbol,
    required this.time,
    required this.direction,
    required this.referencePrice,
    required this.entryLow,
    required this.entryHigh,
    required this.stop,
    required this.tp1,
    required this.tp2,
    required this.score,
    required this.trend5m,
    required this.trend15m,
    required this.trend1h,
    required this.rsi,
    required this.macd,
    required this.ema20,
    required this.ema50,
    required this.ema200,
    required this.relativeVolume,
    required this.rvolBias,
    required this.fvgBias,
    required this.orderBlockBias,
    required this.liquidityBias,
    required this.bos,
    required this.choch,
    this.style = SignalStyle.standard,
    this.trend1m = Bias.neutral,
    this.leverage = 1,
    this.status = SignalStatus.waitingEntry,
    this.entryTime,
    this.tp1Time,
    this.tp2Time,
    this.exitTime,
    this.lastTrackedCandleTime,
    this.mfeR = 0.0,
    this.maeR = 0.0,
    this.mfePercent = 0.0,
    this.maePercent = 0.0,
    this.resultR = 0.0,
  });

  final String id;
  final String symbol;
  final DateTime time;
  final SignalDirection direction;
  final SignalStyle style;
  final double referencePrice;
  final double entryLow;
  final double entryHigh;
  final double stop;
  final double tp1;
  final double tp2;
  final int score;
  final Bias trend1m;
  final Bias trend5m;
  final Bias trend15m;
  final Bias trend1h;
  final double rsi;
  final double macd;
  final double ema20;
  final double ema50;
  final double ema200;
  final double relativeVolume;
  final Bias rvolBias;
  final Bias fvgBias;
  final Bias orderBlockBias;
  final Bias liquidityBias;
  final Bias bos;
  final Bias choch;
  final int leverage;
  final SignalStatus status;
  final DateTime? entryTime;
  final DateTime? tp1Time;
  final DateTime? tp2Time;
  final DateTime? exitTime;
  final DateTime? lastTrackedCandleTime;
  final double mfeR;
  final double maeR;
  final double mfePercent;
  final double maePercent;
  final double resultR;

  double get entryPrice => (entryLow + entryHigh) / 2.0;

  double get risk => (entryPrice - stop).abs();

  List<RiskRewardEstimate> get riskRewardEstimates {
    final double baseProbability = _clampDouble(
      52.0 + (score - 75) * 0.6,
      45.0,
      68.0,
    );
    const Map<int, double> probabilityFactors = <int, double>{
      1: 1.0,
      3: 0.42,
      5: 0.25,
      9: 0.10,
    };
    return probabilityFactors.entries
        .map<RiskRewardEstimate>((MapEntry<int, double> entry) {
          final int reward = entry.key;
          final double probability = baseProbability * entry.value;
          final double probabilityRatio = probability / 100.0;
          final double expectedR =
              probabilityRatio * reward - (1.0 - probabilityRatio);
          final double targetDistance = risk * reward;
          final double target = direction == SignalDirection.long
              ? entryPrice + targetDistance
              : entryPrice - targetDistance;
          return RiskRewardEstimate(
            rewardMultiple: reward,
            targetPrice: target,
            probabilityPercent: probability,
            expectedR: expectedR,
          );
        })
        .toList(growable: false);
  }

  RiskRewardEstimate get recommendedRiskReward {
    final List<RiskRewardEstimate> options = riskRewardEstimates;
    RiskRewardEstimate best = options.first;
    for (final RiskRewardEstimate option in options.skip(1)) {
      if (option.expectedR > best.expectedR) {
        best = option;
      }
    }
    return best;
  }

  Duration? get timeToEntry => entryTime?.difference(time);

  Duration? get timeToTp1 => entryTime == null || tp1Time == null
      ? null
      : tp1Time!.difference(entryTime!);

  Duration? get timeToTp2 => entryTime == null || tp2Time == null
      ? null
      : tp2Time!.difference(entryTime!);

  Duration? get tradeDuration => entryTime == null || exitTime == null
      ? null
      : exitTime!.difference(entryTime!);

  RadarSignal copyWith({
    SignalStatus? status,
    DateTime? entryTime,
    DateTime? tp1Time,
    DateTime? tp2Time,
    DateTime? exitTime,
    DateTime? lastTrackedCandleTime,
    double? mfeR,
    double? maeR,
    double? mfePercent,
    double? maePercent,
    double? resultR,
  }) {
    return RadarSignal(
      id: id,
      symbol: symbol,
      time: time,
      direction: direction,
      style: style,
      referencePrice: referencePrice,
      entryLow: entryLow,
      entryHigh: entryHigh,
      stop: stop,
      tp1: tp1,
      tp2: tp2,
      score: score,
      trend1m: trend1m,
      trend5m: trend5m,
      trend15m: trend15m,
      trend1h: trend1h,
      rsi: rsi,
      macd: macd,
      ema20: ema20,
      ema50: ema50,
      ema200: ema200,
      relativeVolume: relativeVolume,
      rvolBias: rvolBias,
      fvgBias: fvgBias,
      orderBlockBias: orderBlockBias,
      liquidityBias: liquidityBias,
      bos: bos,
      choch: choch,
      leverage: leverage,
      status: status ?? this.status,
      entryTime: entryTime ?? this.entryTime,
      tp1Time: tp1Time ?? this.tp1Time,
      tp2Time: tp2Time ?? this.tp2Time,
      exitTime: exitTime ?? this.exitTime,
      lastTrackedCandleTime:
          lastTrackedCandleTime ?? this.lastTrackedCandleTime,
      mfeR: mfeR ?? this.mfeR,
      maeR: maeR ?? this.maeR,
      mfePercent: mfePercent ?? this.mfePercent,
      maePercent: maePercent ?? this.maePercent,
      resultR: resultR ?? this.resultR,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'symbol': symbol,
      'time': time.toIso8601String(),
      'direction': direction.name,
      'style': style.name,
      'referencePrice': referencePrice,
      'entryLow': entryLow,
      'entryHigh': entryHigh,
      'stop': stop,
      'tp1': tp1,
      'tp2': tp2,
      'score': score,
      'trend1m': trend1m.name,
      'trend5m': trend5m.name,
      'trend15m': trend15m.name,
      'trend1h': trend1h.name,
      'rsi': rsi,
      'macd': macd,
      'ema20': ema20,
      'ema50': ema50,
      'ema200': ema200,
      'relativeVolume': relativeVolume,
      'rvolBias': rvolBias.name,
      'fvgBias': fvgBias.name,
      'orderBlockBias': orderBlockBias.name,
      'liquidityBias': liquidityBias.name,
      'bos': bos.name,
      'choch': choch.name,
      'leverage': leverage,
      'status': status.name,
      'entryTime': entryTime?.toIso8601String(),
      'tp1Time': tp1Time?.toIso8601String(),
      'tp2Time': tp2Time?.toIso8601String(),
      'exitTime': exitTime?.toIso8601String(),
      'lastTrackedCandleTime': lastTrackedCandleTime?.toIso8601String(),
      'mfeR': mfeR,
      'maeR': maeR,
      'mfePercent': mfePercent,
      'maePercent': maePercent,
      'resultR': resultR,
    };
  }

  factory RadarSignal.fromJson(Map<String, dynamic> json) {
    return RadarSignal(
      id: json['id']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
      time: _date(json['time']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      direction: _enumByName(
        SignalDirection.values,
        json['direction'],
        SignalDirection.long,
      ),
      style: _enumByName(
        SignalStyle.values,
        json['style'],
        SignalStyle.standard,
      ),
      referencePrice: _double(json['referencePrice']),
      entryLow: _double(json['entryLow']),
      entryHigh: _double(json['entryHigh']),
      stop: _double(json['stop']),
      tp1: _double(json['tp1']),
      tp2: _double(json['tp2']),
      score: _int(json['score']),
      trend1m: _bias(json['trend1m']),
      trend5m: _bias(json['trend5m']),
      trend15m: _bias(json['trend15m']),
      trend1h: _bias(json['trend1h']),
      rsi: _double(json['rsi']),
      macd: _double(json['macd']),
      ema20: _double(json['ema20']),
      ema50: _double(json['ema50']),
      ema200: _double(json['ema200']),
      relativeVolume: _double(json['relativeVolume']),
      rvolBias: _bias(json['rvolBias']),
      fvgBias: _bias(json['fvgBias']),
      orderBlockBias: _bias(json['orderBlockBias']),
      liquidityBias: _bias(json['liquidityBias']),
      bos: _bias(json['bos']),
      choch: _bias(json['choch']),
      leverage: _int(json['leverage']) == 0 ? 1 : _int(json['leverage']),
      status: _enumByName(
        SignalStatus.values,
        json['status'],
        SignalStatus.waitingEntry,
      ),
      entryTime: _date(json['entryTime']),
      tp1Time: _date(json['tp1Time']),
      tp2Time: _date(json['tp2Time']),
      exitTime: _date(json['exitTime']),
      lastTrackedCandleTime: _date(json['lastTrackedCandleTime']),
      mfeR: _double(json['mfeR']),
      maeR: _double(json['maeR']),
      mfePercent: _double(json['mfePercent']),
      maePercent: _double(json['maePercent']),
      resultR: _double(json['resultR']),
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final String name = raw?.toString() ?? '';
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

Bias _bias(Object? raw) {
  return _enumByName(Bias.values, raw, Bias.neutral);
}

DateTime? _date(Object? raw) {
  return DateTime.tryParse(raw?.toString() ?? '');
}

double _double(Object? raw) {
  return double.tryParse(raw?.toString() ?? '') ?? 0.0;
}

int _int(Object? raw) {
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}

double _clampDouble(double value, double minimum, double maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}
