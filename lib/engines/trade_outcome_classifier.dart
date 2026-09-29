import '../models/execution_models.dart';
import '../models/signal_models.dart';

class TradeOutcomeClassifier {
  const TradeOutcomeClassifier._();

  static RadarSignal classify(RadarSignal signal) {
    if (signal.entryTime == null || signal.status.isActive) return signal;
    final Set<TradeOutcomeFlag> outcomes = <TradeOutcomeFlag>{
      ...signal.outcomeFlags,
    };
    final Set<TradeQualityFlag> quality = <TradeQualityFlag>{
      ...signal.qualityFlags,
    };
    final double effectiveResult = signal.hasCostAwareResult
        ? signal.netResultR
        : signal.resultR;

    if (effectiveResult > 0.0 || signal.stopThenTarget) {
      quality.add(TradeQualityFlag.goodDirection);
    } else if (signal.status == SignalStatus.stopped) {
      outcomes.add(TradeOutcomeFlag.directionWrong);
    }
    if (signal.qualities.location >= 70) {
      quality.add(TradeQualityFlag.goodLocation);
    }
    if (signal.qualities.entry >= 70) {
      quality.add(TradeQualityFlag.goodEntry);
    } else if (signal.status == SignalStatus.stopped) {
      outcomes.add(TradeOutcomeFlag.entryTooEarly);
    }
    if (signal.qualities.stop >= 70) {
      quality.add(TradeQualityFlag.goodStop);
    }
    if (signal.qualities.risk >= 70) {
      quality.add(TradeQualityFlag.goodRisk);
    } else if (signal.status == SignalStatus.stopped) {
      outcomes.add(TradeOutcomeFlag.badRiskReward);
    }
    if (signal.entryConfirmedTime == null &&
        signal.entryMode == EntryMode.confirmed) {
      outcomes.add(TradeOutcomeFlag.noConfirmation);
    }
    if (signal.stopThenTarget) {
      outcomes
        ..remove(TradeOutcomeFlag.directionWrong)
        ..add(TradeOutcomeFlag.stopThenTarget)
        ..add(TradeOutcomeFlag.liquiditySweepBeforeMove);
      if (signal.overshootAtr <= 0.75) {
        outcomes.add(TradeOutcomeFlag.stopTooTight);
      }
      if (signal.falseBreakoutState != FalseBreakoutState.none) {
        outcomes.add(TradeOutcomeFlag.stopInLiquidity);
      }
    } else if (signal.status == SignalStatus.stopped &&
        signal.overshootAtr >= 1.0 &&
        !signal.reclaimedLevel) {
      outcomes.add(TradeOutcomeFlag.realInvalidation);
    }
    if (signal.falseBreakoutState == FalseBreakoutState.confirmed) {
      outcomes.add(TradeOutcomeFlag.falseBreakout);
    }
    if (signal.hasCostAwareResult) {
      quality.add(TradeQualityFlag.planFollowed);
    }
    if (quality.contains(TradeQualityFlag.goodDirection) &&
        quality.contains(TradeQualityFlag.goodEntry) &&
        quality.contains(TradeQualityFlag.goodStop) &&
        quality.contains(TradeQualityFlag.goodRisk)) {
      quality.add(TradeQualityFlag.goodTrade);
    }
    if (effectiveResult <= 0.0 &&
        quality.length >= 4 &&
        !outcomes.contains(TradeOutcomeFlag.realInvalidation)) {
      outcomes.add(TradeOutcomeFlag.goodSetupBadExecution);
    }
    if (effectiveResult <= 0.0 && outcomes.isEmpty) {
      outcomes.add(TradeOutcomeFlag.unknown);
    }
    return signal.copyWith(
      outcomeFlags: List<TradeOutcomeFlag>.unmodifiable(outcomes),
      qualityFlags: List<TradeQualityFlag>.unmodifiable(quality),
    );
  }
}
