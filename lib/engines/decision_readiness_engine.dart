import '../models/decision_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'decision_engine.dart';
import 'entry_readiness_gate.dart';
import 'phase_a_engine.dart';
import 'signal_engine.dart';

/// Builds one immutable analysis shared by the dashboard and alert pipeline.
/// Existing journal state wins so learned execution profiles and TradeTracker
/// stages keep the same signal ID everywhere.
class DecisionReadinessEngine {
  const DecisionReadinessEngine._();

  static DecisionReadinessAnalysis evaluate({
    required MarketSnapshot market,
    Iterable<RadarSignal> trackedSignals = const <RadarSignal>[],
    MarketSnapshot? benchmarkMarket,
    FeeModel feeModel = const FeeModel(),
bool checkEntryZone = true,
bool checkEntryConfirmation = true,
bool checkLiquidity = true,
bool checkStructuralTarget = true,
bool checkMarketContext = true,
  }) {
    final RadarSignal? executionSignal =
        _activeTrackedSignal(market.symbol, trackedSignals) ??
        _preview(market, feeModel);
    final DecisionSnapshot decision = DecisionEngine.build(
      market,
      executionSignal: executionSignal,
    );
    return DecisionReadinessAnalysis(
      executionSignal: executionSignal,
      decision: decision,
      readiness: EntryReadinessGate.evaluate(
        market: market,
        decision: decision,
        signal: executionSignal,
        benchmarkMarket: benchmarkMarket,
        feeModel: feeModel,
        signalId: executionSignal?.id,
        evaluatedAt: market.updatedAt,
checkEntryZone: checkEntryZone,
checkEntryConfirmation: checkEntryConfirmation,
checkLiquidity: checkLiquidity,
checkStructuralTarget: checkStructuralTarget,
checkMarketContext: checkMarketContext,
    );
);
  }

  static RadarSignal? _activeTrackedSignal(
    String symbol,
    Iterable<RadarSignal> signals,
  ) {
    final List<RadarSignal> candidates =
        signals
            .where(
              (RadarSignal signal) =>
                  signal.symbol == symbol &&
                  signal.style == SignalStyle.standard &&
                  signal.status.isActive,
            )
            .toList(growable: false)
          ..sort(
            (RadarSignal first, RadarSignal second) =>
                second.time.compareTo(first.time),
          );
    return candidates.isEmpty ? null : candidates.first;
  }

  static RadarSignal? _preview(MarketSnapshot market, FeeModel feeModel) {
    final RadarSignal? rawSignal = SignalEngine.createSignal(market);
    return rawSignal == null
        ? null
        : PhaseAEngine.preview(
            market: market,
            signal: rawSignal,
            feeModel: feeModel,
          );
  }
}

class DecisionReadinessAnalysis {
  const DecisionReadinessAnalysis({
    required this.executionSignal,
    required this.decision,
    required this.readiness,
  });

  final RadarSignal? executionSignal;
  final DecisionSnapshot decision;
  final EntryReadinessResult readiness;
}
