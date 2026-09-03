import '../config/trading_safety_config.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/first_move_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'structural_target_engine.dart';

enum EntryReadinessStatus {
  wait,
  almostReady,
  entryReady,
  suspended,
  invalidated,
}

extension EntryReadinessStatusText on EntryReadinessStatus {
  String get code => switch (this) {
    EntryReadinessStatus.wait => 'WAIT',
    EntryReadinessStatus.almostReady => 'ALMOST READY',
    EntryReadinessStatus.entryReady => 'ENTRY READY',
    EntryReadinessStatus.suspended => 'PERMISSION SUSPENDED',
    EntryReadinessStatus.invalidated => 'INVALIDATED',
  };
}

enum EntryNextAction {
  enter,
  waitForData,
  waitForZone,
  waitForConfirmation,
  waitForLiquidity,
  waitForRisk,
  waitForDirection,
  skip,
}

extension EntryNextActionText on EntryNextAction {
  String get code => switch (this) {
    EntryNextAction.enter => 'ENTER',
    EntryNextAction.waitForData => 'DATA VETO',
    EntryNextAction.waitForZone => 'WAIT FOR ZONE',
    EntryNextAction.waitForConfirmation => 'WAIT FOR CONFIRMATION',
    EntryNextAction.waitForLiquidity => 'WAIT FOR LIQUIDITY',
    EntryNextAction.waitForRisk => 'RISK VETO',
    EntryNextAction.waitForDirection => 'WAIT FOR DIRECTION',
    EntryNextAction.skip => 'SKIP',
  };
}

enum EntryReadinessReason {
  dataQualityLow,
  criticalMarketData,
  staleBidAsk,
  missingInstrumentRules,
  hardBlock,
  entryNotConfirmed,
  entryDecisionWait,
  priceOutsideEntryZone,
  liquidityNotConfirmed,
  stopQualityLow,
  riskQualityLow,
  directionQualityLow,
  setupMissing,
  entryZoneMissing,
  targetTooClose,
  targetNotStructural,
  obstacleBeforeTarget,
  structuralStopMissing,
  stopTooTight,
  riskRewardTooLow,
  entryTriggerMissing,
  signalStale,
  liquidityInvalid,
  marketConflict,
  historicalSamplesLow,
  firstMoveProbabilityLow,
  spreadTooWide,
}

extension EntryReadinessReasonText on EntryReadinessReason {
  String get code => switch (this) {
    EntryReadinessReason.dataQualityLow => 'DATA_QUALITY_LOW',
    EntryReadinessReason.criticalMarketData => 'CRITICAL_MARKET_DATA',
    EntryReadinessReason.staleBidAsk => 'BID_ASK_STALE',
    EntryReadinessReason.missingInstrumentRules => 'INSTRUMENT_RULES_MISSING',
    EntryReadinessReason.hardBlock => 'HARD_BLOCK',
    EntryReadinessReason.entryNotConfirmed => 'ENTRY_NOT_CONFIRMED',
    EntryReadinessReason.entryDecisionWait => 'ENTRY_DECISION_WAIT',
    EntryReadinessReason.priceOutsideEntryZone => 'PRICE_OUTSIDE_ENTRY_ZONE',
    EntryReadinessReason.liquidityNotConfirmed => 'LIQUIDITY_CONFIRMATION_LOST',
    EntryReadinessReason.stopQualityLow => 'STOP_QUALITY_FAILED',
    EntryReadinessReason.riskQualityLow => 'RISK_QUALITY_FAILED',
    EntryReadinessReason.directionQualityLow => 'DIRECTION_QUALITY_FAILED',
    EntryReadinessReason.setupMissing => 'SETUP_MISSING',
    EntryReadinessReason.entryZoneMissing => 'ENTRY_ZONE_MISSING',
    EntryReadinessReason.targetTooClose => 'TARGET_TOO_CLOSE',
    EntryReadinessReason.targetNotStructural => 'STRUCTURAL_TARGET_MISSING',
    EntryReadinessReason.obstacleBeforeTarget => 'OBSTACLE_BEFORE_TARGET',
    EntryReadinessReason.structuralStopMissing => 'STRUCTURAL_STOP_MISSING',
    EntryReadinessReason.stopTooTight => 'STOP_TOO_TIGHT',
    EntryReadinessReason.riskRewardTooLow => 'RR_TOO_LOW',
    EntryReadinessReason.entryTriggerMissing => 'ENTRY_TRIGGER_MISSING',
    EntryReadinessReason.signalStale => 'SIGNAL_STALE',
    EntryReadinessReason.liquidityInvalid => 'LIQUIDITY_INVALID',
    EntryReadinessReason.marketConflict => 'MARKET_CONFLICT',
    EntryReadinessReason.historicalSamplesLow => 'HISTORICAL_SAMPLES_LOW',
    EntryReadinessReason.firstMoveProbabilityLow =>
      'FIRST_MOVE_PROBABILITY_LOW',
    EntryReadinessReason.spreadTooWide => 'SPREAD_TOO_WIDE',
  };
}

/// One safety contract shared by the dashboard and outbound notifications.
///
/// A green visual state and a phone alert must never disagree about whether an
/// entry is currently allowed. This gate does not place orders.
class EntryReadinessGate {
  const EntryReadinessGate._();

  static EntryReadinessResult evaluate({
    required MarketSnapshot market,
    required DecisionSnapshot decision,
    RadarSignal? signal,
    MarketSnapshot? benchmarkMarket,
    FeeModel feeModel = const FeeModel(),
    String? signalId,
    DateTime? evaluatedAt,
bool checkEntryZone = true,
bool checkEntryConfirmation = true,
bool checkLiquidity = true,
bool checkStructuralTarget = true,
bool checkMarketContext = true,
  }) {
    final List<EntryReadinessReason> reasons = <EntryReadinessReason>[];
    void addReason(EntryReadinessReason reason) {
      if (!reasons.contains(reason)) reasons.add(reason);
    }

    if (decision.dataQuality == DataQuality.low) {
      addReason(EntryReadinessReason.dataQualityLow);
    }
    if (market.dataIntegrity.hasCriticalIssue) {
      addReason(EntryReadinessReason.criticalMarketData);
    }
    if (!market.dataIntegrity.hasFreshBidAsk) {
      addReason(EntryReadinessReason.staleBidAsk);
    }
    if (!market.dataIntegrity.hasInstrumentRules) {
      addReason(EntryReadinessReason.missingInstrumentRules);
    }
    if (decision.executionAction.toUpperCase().contains('NO TRADE')) {
      addReason(EntryReadinessReason.hardBlock);
    }
    final bool marketDataReady =
        decision.dataQuality != DataQuality.low &&
        !market.dataIntegrity.hasCriticalIssue;
    final bool microstructureReady =
        market.dataIntegrity.hasFreshBidAsk &&
        market.dataIntegrity.hasInstrumentRules;
    final bool hardBlocked =
        !marketDataReady ||
        !microstructureReady ||
        decision.executionAction.toUpperCase().contains('NO TRADE');
    final bool entryConfirmed =
     !checkEntryConfirmation ||
        decision.signalStage == SignalStage.entryConfirmed ||
        decision.signalStage == SignalStage.inPosition ||
        decision.signalStage == SignalStage.tp1Hit ||
        decision.signalStage == SignalStage.tp2Hit;
    final bool priceInZone =
          !checkEntryZone ||
        (decision.entryLow > 0.0 &&
        decision.entryHigh >= decision.entryLow &&
        decision.price >= decision.entryLow &&
        decision.price <= decision.entryHigh);
    final bool liquidityReady =
         !checkLiquidity ||
        decision.qualityScores.liquidity >= 70 ||
        decision.liquiditySweepConfirmed;
    final bool riskReady =
        decision.qualityScores.stop >= 70 && decision.qualityScores.risk >= 70;
    final bool directionReady = decision.qualityScores.direction >= 65;
    if (!entryConfirmed) addReason(EntryReadinessReason.entryNotConfirmed);
    if (decision.entryDecision != EntryDecision.enterNow) {
      addReason(EntryReadinessReason.entryDecisionWait);
    }
    if (!priceInZone) {
      addReason(EntryReadinessReason.priceOutsideEntryZone);
    }
    if (!liquidityReady) {
      addReason(EntryReadinessReason.liquidityNotConfirmed);
    }
    if (decision.qualityScores.stop < 70) {
      addReason(EntryReadinessReason.stopQualityLow);
    }
    if (decision.qualityScores.risk < 70) {
      addReason(EntryReadinessReason.riskQualityLow);
    }
    if (!directionReady) {
      addReason(EntryReadinessReason.directionQualityLow);
    }
    final bool strictChecks = signal != null;
    final SignalDirection? direction =
        signal?.direction ??
        switch (decision.decision) {
          DecisionAction.long => SignalDirection.long,
          DecisionAction.short => SignalDirection.short,
          DecisionAction.wait => null,
        };
    final bool setupReady =
        direction != null && decision.selectedStrategy.trim().isNotEmpty;
    final bool entryZoneReady =
        decision.entryLow > 0.0 && decision.entryHigh >= decision.entryLow;
    final double conservativeEntry = direction == SignalDirection.short
        ? decision.entryLow
        : decision.entryHigh;
    final double targetMovePercent = _movePercent(
      direction: direction,
      entry: conservativeEntry,
      target: decision.tp1,
    );
    final double stopDistancePercent = conservativeEntry <= 0.0
        ? 0.0
        : (conservativeEntry - decision.stop).abs() / conservativeEntry * 100.0;
    final double rawRiskReward = stopDistancePercent <= 0.0
        ? 0.0
        : targetMovePercent / stopDistancePercent;
    final double spreadPercent = market.ticker.spreadPercent > 0.0
        ? market.ticker.spreadPercent
        : feeModel.estimatedSpreadPercent;
    final double targetCostsPercent =
        feeModel.feePercent(feeModel.entryOrderType) +
        feeModel.feePercent(feeModel.targetExitOrderType) +
        feeModel.entrySlippagePercent +
        feeModel.targetSlippagePercent +
        spreadPercent;
    final double stopCostsPercent =
        feeModel.feePercent(feeModel.entryOrderType) +
        feeModel.feePercent(feeModel.stopOrderType) +
        feeModel.entrySlippagePercent +
        feeModel.stopSlippagePercent +
        spreadPercent +
        feeModel.safetyBufferPercent;
    final double netRiskReward = stopDistancePercent + stopCostsPercent <= 0.0
        ? 0.0
        : (targetMovePercent - targetCostsPercent) /
              (stopDistancePercent + stopCostsPercent);
    final TimeframeAnalysis targetFrame = signal?.style == SignalStyle.scalp
        ? market.oneMinute
        : market.fifteenMinutes;
    final double tickSize = market.tradingRules?.tickSize ?? 0.0;
    final bool structuralTargetReady =
!checkStructuralTarget ||
        !strictChecks ||
        (market.tradePlan.structuralTargetValid &&
            direction != null &&
            StructuralTargetEngine.isConfirmedTarget(
              analysis: targetFrame,
              direction: direction,
              entryLow: decision.entryLow,
              entryHigh: decision.entryHigh,
              target: decision.tp1,
              tickSize: tickSize,
            ));
    final StructuralObstacle? obstacle = direction == null
        ? null
        : StructuralTargetEngine.obstacleBeforeTarget(
            analysis: targetFrame,
            direction: direction,
            entryLow: decision.entryLow,
            entryHigh: decision.entryHigh,
            target: decision.tp1,
            tickSize: tickSize,
          );
    final bool structuralStopReady =
        !strictChecks ||
        (market.tradePlan.structuralStopValid &&
            signal.structuralStop > 0.0 &&
            signal.invalidationPrice > 0.0 &&
            _stopOnCorrectSide(signal));
    final double actualBuffer = signal == null
        ? decision.stopBuffer
        : (signal.stop - signal.invalidationPrice).abs();
    final double requiredBuffer = _max4(
      targetFrame.atr * TradingSafetyConfig.minStopAtrBuffer,
      market.ticker.spread * TradingSafetyConfig.spreadBufferMultiplier,
      conservativeEntry *
          feeModel.stopSlippagePercent /
          100.0 *
          TradingSafetyConfig.slippageBufferMultiplier,
      tickSize * TradingSafetyConfig.tickBufferMultiplier,
    );
    final bool stopBufferReady =
        !strictChecks ||
        (requiredBuffer > 0.0 &&
            actualBuffer + tickSize * 0.1 >= requiredBuffer);
    final DateTime evaluationTime = (evaluatedAt ?? market.updatedAt).toUtc();
    final Duration maximumSignalAge = signal?.style == SignalStyle.scalp
        ? TradingSafetyConfig.scalpSignalMaxAge
        : TradingSafetyConfig.standardSignalMaxAge;
    final bool signalFresh =
        !strictChecks ||
        (!evaluationTime.isBefore(signal.time.toUtc()) &&
            evaluationTime.difference(signal.time.toUtc()) <= maximumSignalAge);
    final bool spreadReady =
    spreadPercent <= TradingSafetyConfig.maxReadySpreadPercent;

// Historical statistics are collected for research,
// but do not block entry readiness.
final bool historicalSamplesReady = true;

final double? firstMoveProbability = signal?.firstMove.probabilityFor(
  TradingSafetyConfig.readinessProbabilityTargetPercent,
);

final bool probabilityReady = true;
    final bool marketContextReady =
!checkMarketContext ||
 _marketContextReady(
      market: market,
      benchmarkMarket: benchmarkMarket,
      direction: direction,
      signal: signal,
    );
    final bool currentDirectionReady =
        signal == null ||
        (signal.direction == SignalDirection.long
            ? decision.decision == DecisionAction.long
            : decision.decision == DecisionAction.short);
    if (strictChecks && !setupReady) {
      addReason(EntryReadinessReason.setupMissing);
    }
    if (strictChecks && !entryZoneReady) {
      addReason(EntryReadinessReason.entryZoneMissing);
    }
    if (strictChecks &&
        targetMovePercent < TradingSafetyConfig.minReadyMovePercent) {
      addReason(EntryReadinessReason.targetTooClose);
    }
    if (!structuralTargetReady) {
      addReason(EntryReadinessReason.targetNotStructural);
    }
    if (obstacle != null) addReason(EntryReadinessReason.obstacleBeforeTarget);
    if (!structuralStopReady) {
      addReason(EntryReadinessReason.structuralStopMissing);
    }
    if (!stopBufferReady) addReason(EntryReadinessReason.stopTooTight);
    if (strictChecks && netRiskReward < TradingSafetyConfig.minNetRiskReward) {
      addReason(EntryReadinessReason.riskRewardTooLow);
    }
    if (strictChecks && !entryConfirmed) {
      addReason(EntryReadinessReason.entryTriggerMissing);
    }
    if (!signalFresh) addReason(EntryReadinessReason.signalStale);
    if (!liquidityReady || !market.dataIntegrity.hasFreshBidAsk) {
      addReason(EntryReadinessReason.liquidityInvalid);
    }
    if (!marketContextReady || !currentDirectionReady) {
      addReason(EntryReadinessReason.marketConflict);
    }
    if (!historicalSamplesReady) {
      addReason(EntryReadinessReason.historicalSamplesLow);
    } else if (!probabilityReady) {
      addReason(EntryReadinessReason.firstMoveProbabilityLow);
    }
    if (!spreadReady) addReason(EntryReadinessReason.spreadTooWide);
    final bool strictRiskReady =
        riskReady &&
        (!strictChecks ||
            (structuralStopReady &&
                stopBufferReady &&
                rawRiskReward > 0.0 &&
                netRiskReward >= TradingSafetyConfig.minNetRiskReward));
    final bool strictEntryReady =
        !strictChecks ||
        (setupReady &&
            entryZoneReady &&
            (!checkStructuralTarget ||
    (targetMovePercent >= TradingSafetyConfig.minReadyMovePercent &&
        structuralTargetReady &&
        obstacle == null)) &&
            signalFresh &&
            spreadReady &&
            historicalSamplesReady &&
            probabilityReady &&
            marketContextReady &&
            currentDirectionReady);
    final bool entryReady =
        !hardBlocked &&
        entryConfirmed &&
        decision.entryDecision == EntryDecision.enterNow &&
        priceInZone &&
        liquidityReady &&
        riskReady &&
        directionReady &&
        strictRiskReady &&
        strictEntryReady;
    final bool dataSuspended =
        !marketDataReady || !microstructureReady || !signalFresh;
    final bool structuralVeto =
    strictChecks &&
    ((checkStructuralTarget &&
            (!structuralTargetReady ||
                obstacle != null ||
                targetMovePercent <
                    TradingSafetyConfig.minReadyMovePercent)) ||
        !structuralStopReady ||
        !stopBufferReady ||
        netRiskReward < TradingSafetyConfig.minNetRiskReward);
    final EntryReadinessStatus status = entryReady
        ? EntryReadinessStatus.entryReady
        : dataSuspended
        ? EntryReadinessStatus.suspended
        : reasons.contains(EntryReadinessReason.hardBlock) || structuralVeto
        ? EntryReadinessStatus.invalidated
        : _almostReady(
            entryConfirmed: entryConfirmed,
            priceInZone: priceInZone,
            liquidityReady: liquidityReady,
            riskReady: strictRiskReady,
            directionReady: directionReady,
          )
        ? EntryReadinessStatus.almostReady
        : EntryReadinessStatus.wait;
    final EntryNextAction nextAction = entryReady
        ? EntryNextAction.enter
        : dataSuspended
        ? EntryNextAction.waitForData
        : reasons.contains(EntryReadinessReason.hardBlock) || structuralVeto
        ? EntryNextAction.skip
        : !priceInZone
        ? EntryNextAction.waitForZone
        : !entryConfirmed || decision.entryDecision != EntryDecision.enterNow
        ? EntryNextAction.waitForConfirmation
        : !liquidityReady
        ? EntryNextAction.waitForLiquidity
        : !strictRiskReady
        ? EntryNextAction.waitForRisk
        : EntryNextAction.waitForDirection;

    return EntryReadinessResult(
      signalId: signalId,
      evaluatedAt: (evaluatedAt ?? market.updatedAt).toUtc(),
      status: status,
      nextAction: nextAction,
      reasons: List<EntryReadinessReason>.unmodifiable(reasons),
      dataQuality: decision.dataQuality,
      hardBlocked: hardBlocked || structuralVeto,
      marketDataReady: marketDataReady,
      microstructureReady: microstructureReady,
      entryConfirmed: entryConfirmed,
      priceInZone: priceInZone,
      liquidityReady: liquidityReady,
      riskReady: strictRiskReady,
      directionReady: directionReady,
      entryReady: entryReady,
      targetMovePercent: targetMovePercent,
      stopDistancePercent: stopDistancePercent,
      rawRiskReward: rawRiskReward,
      netRiskReward: netRiskReward,
      structuralTargetReady: structuralTargetReady,
      structuralStopReady: structuralStopReady,
      stopBufferReady: stopBufferReady,
      signalFresh: signalFresh,
      marketContextReady: marketContextReady && currentDirectionReady,
      spreadReady: spreadReady,
      historicalSamples: signal?.firstMove.historicalSamples ?? 0,
      historicalConfidence:
          signal?.firstMove.historicalConfidence.code ?? 'INSUFFICIENT_DATA',
      firstMoveProbability: firstMoveProbability,
      firstMoveProbabilities: signal == null
          ? const <double, double?>{}
          : <double, double?>{
              0.20: signal.firstMove.probability020,
              0.30: signal.firstMove.probability030,
              0.50: signal.firstMove.probability050,
              0.75: signal.firstMove.probability075,
              1.00: signal.firstMove.probability100,
            },
      stopFirstProbability: signal?.firstMove.probabilityStopFirst,
      obstacleLabel: obstacle?.label,
    );
  }

  static double _movePercent({
    required SignalDirection? direction,
    required double entry,
    required double target,
  }) {
    if (direction == null || entry <= 0.0 || target <= 0.0) return 0.0;
    final double move = direction == SignalDirection.long
        ? target - entry
        : entry - target;
    return move <= 0.0 ? 0.0 : move / entry * 100.0;
  }

  static bool _stopOnCorrectSide(RadarSignal signal) {
    return signal.direction == SignalDirection.long
        ? signal.stop < signal.entryLow &&
              signal.invalidationPrice < signal.entryLow
        : signal.stop > signal.entryHigh &&
              signal.invalidationPrice > signal.entryHigh;
  }

  static bool _marketContextReady({
    required MarketSnapshot market,
    required MarketSnapshot? benchmarkMarket,
    required SignalDirection? direction,
    required RadarSignal? signal,
  }) {
    if (direction == null) return false;
    final Bias opposite = direction == SignalDirection.long
        ? Bias.bearish
        : Bias.bullish;
    if (signal != null &&
        signal.trend15m == opposite &&
        signal.trend1h == opposite) {
      return false;
    }
    if (market.symbol == 'BTCUSDT') return true;
    if (benchmarkMarket == null ||
        benchmarkMarket.dataIntegrity.hasCriticalIssue) {
      return false;
    }
    return !(benchmarkMarket.oneMinute.trend == opposite &&
        benchmarkMarket.fifteenMinutes.trend == opposite);
  }

  static double _max4(double a, double b, double c, double d) {
    double result = a;
    if (b > result) result = b;
    if (c > result) result = c;
    if (d > result) result = d;
    return result;
  }

  static bool _almostReady({
    required bool entryConfirmed,
    required bool priceInZone,
    required bool liquidityReady,
    required bool riskReady,
    required bool directionReady,
  }) {
    final int passed = <bool>[
      entryConfirmed,
      priceInZone,
      liquidityReady,
      riskReady,
      directionReady,
    ].where((bool value) => value).length;
    return passed >= 4;
  }
}

class EntryReadinessResult {
  const EntryReadinessResult({
    required this.signalId,
    required this.evaluatedAt,
    required this.status,
    required this.nextAction,
    required this.reasons,
    required this.dataQuality,
    required this.hardBlocked,
    required this.marketDataReady,
    required this.microstructureReady,
    required this.entryConfirmed,
    required this.priceInZone,
    required this.liquidityReady,
    required this.riskReady,
    required this.directionReady,
    required this.entryReady,
    this.targetMovePercent = 0.0,
    this.stopDistancePercent = 0.0,
    this.rawRiskReward = 0.0,
    this.netRiskReward = 0.0,
    this.structuralTargetReady = true,
    this.structuralStopReady = true,
    this.stopBufferReady = true,
    this.signalFresh = true,
    this.marketContextReady = true,
    this.spreadReady = true,
    this.historicalSamples = 0,
    this.historicalConfidence = 'INSUFFICIENT_DATA',
    this.firstMoveProbability,
    this.firstMoveProbabilities = const <double, double?>{},
    this.stopFirstProbability,
    this.obstacleLabel,
  });

  final String? signalId;
  final DateTime evaluatedAt;
  final EntryReadinessStatus status;
  final EntryNextAction nextAction;
  final List<EntryReadinessReason> reasons;
  final DataQuality dataQuality;
  final bool hardBlocked;
  final bool marketDataReady;
  final bool microstructureReady;
  final bool entryConfirmed;
  final bool priceInZone;
  final bool liquidityReady;
  final bool riskReady;
  final bool directionReady;
  final bool entryReady;
  final double targetMovePercent;
  final double stopDistancePercent;
  final double rawRiskReward;
  final double netRiskReward;
  final bool structuralTargetReady;
  final bool structuralStopReady;
  final bool stopBufferReady;
  final bool signalFresh;
  final bool marketContextReady;
  final bool spreadReady;
  final int historicalSamples;
  final String historicalConfidence;
  final double? firstMoveProbability;
  final Map<double, double?> firstMoveProbabilities;
  final double? stopFirstProbability;
  final String? obstacleLabel;

  List<String> get reasonCodes => reasons
      .map<String>((EntryReadinessReason reason) => reason.code)
      .toList(growable: false);
}
