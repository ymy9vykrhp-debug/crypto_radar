import 'market_models.dart';
import 'execution_models.dart';
import 'first_move_models.dart';

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
  bool get hasHistoricalProbability => probabilityPercent >= 0.0;
}

enum SignalStatus {
  waitingEntry,
  inPosition,
  tp1Hit,
  tp2Hit,
  stopped,
  cancelled,
  expired,
}

enum TradeOutcomeFlag {
  directionWrong,
  entryTooEarly,
  entryTooLate,
  chaseEntry,
  stopTooTight,
  stopInLiquidity,
  realInvalidation,
  noConfirmation,
  badRiskReward,
  newsEvent,
  regimeError,
  goodSetupBadExecution,
  falseBreakout,
  liquiditySweepBeforeMove,
  stopThenTarget,
  unknown,
}

enum TradeQualityFlag {
  goodDirection,
  goodLocation,
  goodEntry,
  goodStop,
  goodRisk,
  planFollowed,
  goodTrade,
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
      case SignalStatus.expired:
        return 'EXPIRED';
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
    this.reasonCodes = const <String>[],
    this.stage = SignalStage.setupFound,
    this.entryMode = EntryMode.confirmed,
    this.entryVariant = EntryVariant.bosConfirmation,
    this.stopVariant = StopVariant.structuralAtr,
    this.executionProfileId = 'live_confirmed',
    this.qualities = SignalQualityScores.unrated,
    this.invalidationPrice = 0.0,
    this.structuralStop = 0.0,
    this.stopBuffer = 0.0,
    this.stopBufferAtr = 0.0,
    this.stopIsSafe = true,
    this.executionAction = '',
    this.falseBreakoutState = FalseBreakoutState.none,
    this.falseBreakoutLevel = 0.0,
    this.falseBreakoutScore = 0,
    this.liquiditySweepConfirmed = false,
    this.entryConfirmedTime,
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
    this.hasCostAwareResult = false,
    this.rawResultR = 0.0,
    this.netResultR = 0.0,
    this.grossPnl = 0.0,
    this.netPnl = 0.0,
    this.entryFee = 0.0,
    this.exitFees = 0.0,
    this.spreadCost = 0.0,
    this.slippageCost = 0.0,
    this.fundingCost = 0.0,
    this.simulatedQuantity = 0.0,
    this.executionModelVersion = '',
    this.outcomeFlags = const <TradeOutcomeFlag>[],
    this.qualityFlags = const <TradeQualityFlag>[],
    this.strategyVersion = 'STRATEGY_V1',
    this.entryEngineVersion = 'ENTRY_ENGINE_V2',
    this.stopEngineVersion = 'STOP_ENGINE_V2',
    this.liquidityEngineVersion = 'LIQUIDITY_ENGINE_V1',
    this.stopTime,
    this.maximumOvershootPrice = 0.0,
    this.overshootPoints = 0.0,
    this.overshootPercent = 0.0,
    this.overshootAtr = 0.0,
    this.timeOutsideLevelSeconds = 0,
    this.reclaimedLevel = false,
    this.postStopTp1 = false,
    this.postStopTp2 = false,
    this.postStopTrackingUntil,
    this.firstMove = const FirstMoveRecord(),
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
  final List<String> reasonCodes;
  final SignalStage stage;
  final EntryMode entryMode;
  final EntryVariant entryVariant;
  final StopVariant stopVariant;
  final String executionProfileId;
  final SignalQualityScores qualities;
  final double invalidationPrice;
  final double structuralStop;
  final double stopBuffer;
  final double stopBufferAtr;
  final bool stopIsSafe;
  final String executionAction;
  final FalseBreakoutState falseBreakoutState;
  final double falseBreakoutLevel;
  final int falseBreakoutScore;
  final bool liquiditySweepConfirmed;
  final DateTime? entryConfirmedTime;
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
  final bool hasCostAwareResult;
  final double rawResultR;
  final double netResultR;
  final double grossPnl;
  final double netPnl;
  final double entryFee;
  final double exitFees;
  final double spreadCost;
  final double slippageCost;
  final double fundingCost;
  final double simulatedQuantity;
  final String executionModelVersion;
  final List<TradeOutcomeFlag> outcomeFlags;
  final List<TradeQualityFlag> qualityFlags;
  final String strategyVersion;
  final String entryEngineVersion;
  final String stopEngineVersion;
  final String liquidityEngineVersion;
  final DateTime? stopTime;
  final double maximumOvershootPrice;
  final double overshootPoints;
  final double overshootPercent;
  final double overshootAtr;
  final int timeOutsideLevelSeconds;
  final bool reclaimedLevel;
  final bool postStopTp1;
  final bool postStopTp2;
  final DateTime? postStopTrackingUntil;
  final FirstMoveRecord firstMove;

  double get entryPrice => (entryLow + entryHigh) / 2.0;

  double get risk => (entryPrice - stop).abs();

  bool get needsPostStopTracking {
    if (status != SignalStatus.stopped || postStopTrackingUntil == null) {
      return false;
    }
    final DateTime last = lastTrackedCandleTime ?? stopTime ?? time;
    return last.isBefore(postStopTrackingUntil!) && !postStopTp2;
  }

  bool get stopThenTarget => postStopTp1 || postStopTp2;

  List<RiskRewardEstimate> get riskRewardEstimates {
    const List<int> rewardMultiples = <int>[1, 3, 5, 9];
    return rewardMultiples
        .map<RiskRewardEstimate>((int reward) {
          final double targetDistance = risk * reward;
          final double targetMovePercent = entryPrice <= 0.0
              ? 0.0
              : targetDistance / entryPrice * 100.0;
          final double? historicalProbability = _historicalProbabilityForMove(
            targetMovePercent,
          );
          final double probability = historicalProbability ?? -1.0;
          final double probabilityRatio = probability / 100.0;
          final double expectedR = historicalProbability == null
              ? -999.0
              : probabilityRatio * reward - (1.0 - probabilityRatio);
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

  double? _historicalProbabilityForMove(double movePercent) {
    if (!firstMove.hasEnoughSamples || movePercent <= 0.0) return null;
    if (movePercent <= 0.20) return firstMove.probability020;
    if (movePercent <= 0.30) return firstMove.probability030;
    if (movePercent <= 0.50) return firstMove.probability050;
    if (movePercent <= 0.75) return firstMove.probability075;
    if (movePercent <= 1.00) return firstMove.probability100;
    return null;
  }

  RiskRewardEstimate get recommendedRiskReward {
    final List<RiskRewardEstimate> options = riskRewardEstimates;
    final List<RiskRewardEstimate> calibrated = options
        .where((RiskRewardEstimate option) => option.hasHistoricalProbability)
        .toList(growable: false);
    if (calibrated.isEmpty) return options.first;
    RiskRewardEstimate best = calibrated.first;
    for (final RiskRewardEstimate option in calibrated.skip(1)) {
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
    String? id,
    double? entryLow,
    double? entryHigh,
    double? stop,
    double? tp1,
    double? tp2,
    SignalStage? stage,
    EntryMode? entryMode,
    EntryVariant? entryVariant,
    StopVariant? stopVariant,
    String? executionProfileId,
    SignalQualityScores? qualities,
    double? invalidationPrice,
    double? structuralStop,
    double? stopBuffer,
    double? stopBufferAtr,
    bool? stopIsSafe,
    String? executionAction,
    FalseBreakoutState? falseBreakoutState,
    double? falseBreakoutLevel,
    int? falseBreakoutScore,
    bool? liquiditySweepConfirmed,
    DateTime? entryConfirmedTime,
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
    bool? hasCostAwareResult,
    double? rawResultR,
    double? netResultR,
    double? grossPnl,
    double? netPnl,
    double? entryFee,
    double? exitFees,
    double? spreadCost,
    double? slippageCost,
    double? fundingCost,
    double? simulatedQuantity,
    String? executionModelVersion,
    List<TradeOutcomeFlag>? outcomeFlags,
    List<TradeQualityFlag>? qualityFlags,
    String? strategyVersion,
    String? entryEngineVersion,
    String? stopEngineVersion,
    String? liquidityEngineVersion,
    List<String>? reasonCodes,
    DateTime? stopTime,
    double? maximumOvershootPrice,
    double? overshootPoints,
    double? overshootPercent,
    double? overshootAtr,
    int? timeOutsideLevelSeconds,
    bool? reclaimedLevel,
    bool? postStopTp1,
    bool? postStopTp2,
    DateTime? postStopTrackingUntil,
    FirstMoveRecord? firstMove,
  }) {
    return RadarSignal(
      id: id ?? this.id,
      symbol: symbol,
      time: time,
      direction: direction,
      style: style,
      referencePrice: referencePrice,
      entryLow: entryLow ?? this.entryLow,
      entryHigh: entryHigh ?? this.entryHigh,
      stop: stop ?? this.stop,
      tp1: tp1 ?? this.tp1,
      tp2: tp2 ?? this.tp2,
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
      reasonCodes: reasonCodes ?? this.reasonCodes,
      stage: stage ?? this.stage,
      entryMode: entryMode ?? this.entryMode,
      entryVariant: entryVariant ?? this.entryVariant,
      stopVariant: stopVariant ?? this.stopVariant,
      executionProfileId: executionProfileId ?? this.executionProfileId,
      qualities: qualities ?? this.qualities,
      invalidationPrice: invalidationPrice ?? this.invalidationPrice,
      structuralStop: structuralStop ?? this.structuralStop,
      stopBuffer: stopBuffer ?? this.stopBuffer,
      stopBufferAtr: stopBufferAtr ?? this.stopBufferAtr,
      stopIsSafe: stopIsSafe ?? this.stopIsSafe,
      executionAction: executionAction ?? this.executionAction,
      falseBreakoutState: falseBreakoutState ?? this.falseBreakoutState,
      falseBreakoutLevel: falseBreakoutLevel ?? this.falseBreakoutLevel,
      falseBreakoutScore: falseBreakoutScore ?? this.falseBreakoutScore,
      liquiditySweepConfirmed:
          liquiditySweepConfirmed ?? this.liquiditySweepConfirmed,
      entryConfirmedTime: entryConfirmedTime ?? this.entryConfirmedTime,
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
      hasCostAwareResult: hasCostAwareResult ?? this.hasCostAwareResult,
      rawResultR: rawResultR ?? this.rawResultR,
      netResultR: netResultR ?? this.netResultR,
      grossPnl: grossPnl ?? this.grossPnl,
      netPnl: netPnl ?? this.netPnl,
      entryFee: entryFee ?? this.entryFee,
      exitFees: exitFees ?? this.exitFees,
      spreadCost: spreadCost ?? this.spreadCost,
      slippageCost: slippageCost ?? this.slippageCost,
      fundingCost: fundingCost ?? this.fundingCost,
      simulatedQuantity: simulatedQuantity ?? this.simulatedQuantity,
      executionModelVersion:
          executionModelVersion ?? this.executionModelVersion,
      outcomeFlags: outcomeFlags ?? this.outcomeFlags,
      qualityFlags: qualityFlags ?? this.qualityFlags,
      strategyVersion: strategyVersion ?? this.strategyVersion,
      entryEngineVersion: entryEngineVersion ?? this.entryEngineVersion,
      stopEngineVersion: stopEngineVersion ?? this.stopEngineVersion,
      liquidityEngineVersion:
          liquidityEngineVersion ?? this.liquidityEngineVersion,
      stopTime: stopTime ?? this.stopTime,
      maximumOvershootPrice:
          maximumOvershootPrice ?? this.maximumOvershootPrice,
      overshootPoints: overshootPoints ?? this.overshootPoints,
      overshootPercent: overshootPercent ?? this.overshootPercent,
      overshootAtr: overshootAtr ?? this.overshootAtr,
      timeOutsideLevelSeconds:
          timeOutsideLevelSeconds ?? this.timeOutsideLevelSeconds,
      reclaimedLevel: reclaimedLevel ?? this.reclaimedLevel,
      postStopTp1: postStopTp1 ?? this.postStopTp1,
      postStopTp2: postStopTp2 ?? this.postStopTp2,
      postStopTrackingUntil:
          postStopTrackingUntil ?? this.postStopTrackingUntil,
      firstMove: firstMove ?? this.firstMove,
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
      'reasonCodes': reasonCodes,
      'stage': stage.name,
      'entryMode': entryMode.name,
      'entryVariant': entryVariant.name,
      'stopVariant': stopVariant.name,
      'executionProfileId': executionProfileId,
      'qualities': qualities.toJson(),
      'invalidationPrice': invalidationPrice,
      'structuralStop': structuralStop,
      'stopBuffer': stopBuffer,
      'stopBufferAtr': stopBufferAtr,
      'stopIsSafe': stopIsSafe,
      'executionAction': executionAction,
      'falseBreakoutState': falseBreakoutState.name,
      'falseBreakoutLevel': falseBreakoutLevel,
      'falseBreakoutScore': falseBreakoutScore,
      'liquiditySweepConfirmed': liquiditySweepConfirmed,
      'entryConfirmedTime': entryConfirmedTime?.toIso8601String(),
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
      'hasCostAwareResult': hasCostAwareResult,
      'rawResultR': rawResultR,
      'netResultR': netResultR,
      'grossPnl': grossPnl,
      'netPnl': netPnl,
      'entryFee': entryFee,
      'exitFees': exitFees,
      'spreadCost': spreadCost,
      'slippageCost': slippageCost,
      'fundingCost': fundingCost,
      'simulatedQuantity': simulatedQuantity,
      'executionModelVersion': executionModelVersion,
      'outcomeFlags': outcomeFlags
          .map<String>((TradeOutcomeFlag flag) => flag.name)
          .toList(growable: false),
      'qualityFlags': qualityFlags
          .map<String>((TradeQualityFlag flag) => flag.name)
          .toList(growable: false),
      'strategyVersion': strategyVersion,
      'entryEngineVersion': entryEngineVersion,
      'stopEngineVersion': stopEngineVersion,
      'liquidityEngineVersion': liquidityEngineVersion,
      'stopTime': stopTime?.toIso8601String(),
      'maximumOvershootPrice': maximumOvershootPrice,
      'overshootPoints': overshootPoints,
      'overshootPercent': overshootPercent,
      'overshootAtr': overshootAtr,
      'timeOutsideLevelSeconds': timeOutsideLevelSeconds,
      'reclaimedLevel': reclaimedLevel,
      'postStopTp1': postStopTp1,
      'postStopTp2': postStopTp2,
      'postStopTrackingUntil': postStopTrackingUntil?.toIso8601String(),
      'firstMove': firstMove.toJson(),
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
      reasonCodes: _stringList(json['reasonCodes']),
      stage: _enumByName(
        SignalStage.values,
        json['stage'],
        _stageForStatus(
          _enumByName(
            SignalStatus.values,
            json['status'],
            SignalStatus.waitingEntry,
          ),
        ),
      ),
      entryMode: _enumByName(
        EntryMode.values,
        json['entryMode'],
        EntryMode.confirmed,
      ),
      entryVariant: _enumByName(
        EntryVariant.values,
        json['entryVariant'],
        EntryVariant.bosConfirmation,
      ),
      stopVariant: _enumByName(
        StopVariant.values,
        json['stopVariant'],
        StopVariant.structuralAtr,
      ),
      executionProfileId:
          json['executionProfileId']?.toString() ?? 'live_confirmed',
      qualities: SignalQualityScores.fromJson(json['qualities']),
      invalidationPrice: _double(json['invalidationPrice']),
      structuralStop: _double(json['structuralStop']),
      stopBuffer: _double(json['stopBuffer']),
      stopBufferAtr: _double(json['stopBufferAtr']),
      stopIsSafe: json.containsKey('stopIsSafe')
          ? _bool(json['stopIsSafe'])
          : true,
      executionAction: json['executionAction']?.toString() ?? '',
      falseBreakoutState: _enumByName(
        FalseBreakoutState.values,
        json['falseBreakoutState'],
        FalseBreakoutState.none,
      ),
      falseBreakoutLevel: _double(json['falseBreakoutLevel']),
      falseBreakoutScore: _int(json['falseBreakoutScore']),
      liquiditySweepConfirmed: _bool(json['liquiditySweepConfirmed']),
      entryConfirmedTime: _date(json['entryConfirmedTime']),
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
      hasCostAwareResult: _bool(json['hasCostAwareResult']),
      rawResultR: _double(json['rawResultR']),
      netResultR: _double(json['netResultR']),
      grossPnl: _double(json['grossPnl']),
      netPnl: _double(json['netPnl']),
      entryFee: _double(json['entryFee']),
      exitFees: _double(json['exitFees']),
      spreadCost: _double(json['spreadCost']),
      slippageCost: _double(json['slippageCost']),
      fundingCost: _double(json['fundingCost']),
      simulatedQuantity: _double(json['simulatedQuantity']),
      executionModelVersion: json['executionModelVersion']?.toString() ?? '',
      outcomeFlags: _enumList(TradeOutcomeFlag.values, json['outcomeFlags']),
      qualityFlags: _enumList(TradeQualityFlag.values, json['qualityFlags']),
      strategyVersion: json['strategyVersion']?.toString() ?? 'STRATEGY_V1',
      entryEngineVersion:
          json['entryEngineVersion']?.toString() ?? 'ENTRY_ENGINE_V2',
      stopEngineVersion:
          json['stopEngineVersion']?.toString() ?? 'STOP_ENGINE_V2',
      liquidityEngineVersion:
          json['liquidityEngineVersion']?.toString() ?? 'LIQUIDITY_ENGINE_V1',
      stopTime: _date(json['stopTime']),
      maximumOvershootPrice: _double(json['maximumOvershootPrice']),
      overshootPoints: _double(json['overshootPoints']),
      overshootPercent: _double(json['overshootPercent']),
      overshootAtr: _double(json['overshootAtr']),
      timeOutsideLevelSeconds: _int(json['timeOutsideLevelSeconds']),
      reclaimedLevel: _bool(json['reclaimedLevel']),
      postStopTp1: _bool(json['postStopTp1']),
      postStopTp2: _bool(json['postStopTp2']),
      postStopTrackingUntil: _date(json['postStopTrackingUntil']),
      firstMove: json['firstMove'] is Map<String, dynamic>
          ? FirstMoveRecord.fromJson(json['firstMove'] as Map<String, dynamic>)
          : const FirstMoveRecord(),
    );
  }
}

SignalStage _stageForStatus(SignalStatus status) {
  switch (status) {
    case SignalStatus.waitingEntry:
      return SignalStage.setupFound;
    case SignalStatus.inPosition:
      return SignalStage.inPosition;
    case SignalStatus.tp1Hit:
      return SignalStage.tp1Hit;
    case SignalStatus.tp2Hit:
      return SignalStage.tp2Hit;
    case SignalStatus.stopped:
      return SignalStage.stopped;
    case SignalStatus.cancelled:
      return SignalStage.cancelled;
    case SignalStatus.expired:
      return SignalStage.expired;
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

bool _bool(Object? raw) {
  if (raw is bool) {
    return raw;
  }
  return raw?.toString().toLowerCase() == 'true';
}

List<String> _stringList(Object? raw) {
  if (raw is! List<dynamic>) {
    return const <String>[];
  }
  return raw
      .map<String>((dynamic value) => value.toString())
      .toList(growable: false);
}

List<T> _enumList<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! List) return <T>[];
  final List<T> result = <T>[];
  for (final Object? item in raw) {
    final String name = item?.toString() ?? '';
    for (final T value in values) {
      if (value.name == name) {
        result.add(value);
        break;
      }
    }
  }
  return List<T>.unmodifiable(result);
}
