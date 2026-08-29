import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';

/// One safety contract shared by the dashboard and outbound notifications.
///
/// A green visual state and a phone alert must never disagree about whether an
/// entry is currently allowed. This gate does not place orders.
class EntryReadinessGate {
  const EntryReadinessGate._();

  static EntryReadinessResult evaluate({
    required MarketSnapshot market,
    required DecisionSnapshot decision,
  }) {
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
        decision.qualityScores.stop >= 70 &&
        decision.qualityScores.risk >= 70;
    final bool directionReady = decision.qualityScores.direction >= 65;
    final bool entryReady =
        !hardBlocked &&
        entryConfirmed &&
        decision.entryDecision == EntryDecision.enterNow &&
        priceInZone &&
        liquidityReady &&
        riskReady &&
        directionReady;

    return EntryReadinessResult(
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
}

class EntryReadinessResult {
  const EntryReadinessResult({
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

  final bool hardBlocked;
  final bool marketDataReady;
  final bool microstructureReady;
  final bool entryConfirmed;
  final bool priceInZone;
  final bool liquidityReady;
  final bool riskReady;
  final bool directionReady;
  final bool entryReady;
}
