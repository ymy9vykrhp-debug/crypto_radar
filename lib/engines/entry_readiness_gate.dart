import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';

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
    String? signalId,
    DateTime? evaluatedAt,
  }) {
    final List<EntryReadinessReason> reasons = <EntryReadinessReason>[];
    if (decision.dataQuality == DataQuality.low) {
      reasons.add(EntryReadinessReason.dataQualityLow);
    }
    if (market.dataIntegrity.hasCriticalIssue) {
      reasons.add(EntryReadinessReason.criticalMarketData);
    }
    if (!market.dataIntegrity.hasFreshBidAsk) {
      reasons.add(EntryReadinessReason.staleBidAsk);
    }
    if (!market.dataIntegrity.hasInstrumentRules) {
      reasons.add(EntryReadinessReason.missingInstrumentRules);
    }
    if (decision.executionAction.toUpperCase().contains('NO TRADE')) {
      reasons.add(EntryReadinessReason.hardBlock);
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
        decision.signalStage == SignalStage.entryConfirmed ||
        decision.signalStage == SignalStage.inPosition ||
        decision.signalStage == SignalStage.tp1Hit ||
        decision.signalStage == SignalStage.tp2Hit;
    final bool priceInZone =
        decision.entryLow > 0.0 &&
        decision.entryHigh >= decision.entryLow &&
        decision.price >= decision.entryLow &&
        decision.price <= decision.entryHigh;
    final bool liquidityReady =
        decision.qualityScores.liquidity >= 70 ||
        decision.liquiditySweepConfirmed;
    final bool riskReady =
        decision.qualityScores.stop >= 70 && decision.qualityScores.risk >= 70;
    final bool directionReady = decision.qualityScores.direction >= 65;
    if (!entryConfirmed) reasons.add(EntryReadinessReason.entryNotConfirmed);
    if (decision.entryDecision != EntryDecision.enterNow) {
      reasons.add(EntryReadinessReason.entryDecisionWait);
    }
    if (!priceInZone) {
      reasons.add(EntryReadinessReason.priceOutsideEntryZone);
    }
    if (!liquidityReady) {
      reasons.add(EntryReadinessReason.liquidityNotConfirmed);
    }
    if (decision.qualityScores.stop < 70) {
      reasons.add(EntryReadinessReason.stopQualityLow);
    }
    if (decision.qualityScores.risk < 70) {
      reasons.add(EntryReadinessReason.riskQualityLow);
    }
    if (!directionReady) {
      reasons.add(EntryReadinessReason.directionQualityLow);
    }
    final bool entryReady =
        !hardBlocked &&
        entryConfirmed &&
        decision.entryDecision == EntryDecision.enterNow &&
        priceInZone &&
        liquidityReady &&
        riskReady &&
        directionReady;
    final bool dataSuspended = !marketDataReady || !microstructureReady;
    final EntryReadinessStatus status = entryReady
        ? EntryReadinessStatus.entryReady
        : dataSuspended
        ? EntryReadinessStatus.suspended
        : reasons.contains(EntryReadinessReason.hardBlock)
        ? EntryReadinessStatus.invalidated
        : _almostReady(
            entryConfirmed: entryConfirmed,
            priceInZone: priceInZone,
            liquidityReady: liquidityReady,
            riskReady: riskReady,
            directionReady: directionReady,
          )
        ? EntryReadinessStatus.almostReady
        : EntryReadinessStatus.wait;
    final EntryNextAction nextAction = entryReady
        ? EntryNextAction.enter
        : dataSuspended
        ? EntryNextAction.waitForData
        : reasons.contains(EntryReadinessReason.hardBlock)
        ? EntryNextAction.skip
        : !priceInZone
        ? EntryNextAction.waitForZone
        : !entryConfirmed || decision.entryDecision != EntryDecision.enterNow
        ? EntryNextAction.waitForConfirmation
        : !liquidityReady
        ? EntryNextAction.waitForLiquidity
        : !riskReady
        ? EntryNextAction.waitForRisk
        : EntryNextAction.waitForDirection;

    return EntryReadinessResult(
      signalId: signalId,
      evaluatedAt: (evaluatedAt ?? market.updatedAt).toUtc(),
      status: status,
      nextAction: nextAction,
      reasons: List<EntryReadinessReason>.unmodifiable(reasons),
      dataQuality: decision.dataQuality,
      hardBlocked: hardBlocked,
      marketDataReady: marketDataReady,
      microstructureReady: microstructureReady,
      entryConfirmed: entryConfirmed,
      priceInZone: priceInZone,
      liquidityReady: liquidityReady,
      riskReady: riskReady,
      directionReady: directionReady,
      entryReady: entryReady,
    );
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

  List<String> get reasonCodes => reasons
      .map<String>((EntryReadinessReason reason) => reason.code)
      .toList(growable: false);
}
