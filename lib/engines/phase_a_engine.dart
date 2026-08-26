import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import 'entry_engine.dart';
import 'false_breakout_engine.dart';
import 'stop_engine.dart';

class PhaseAEngine {
  const PhaseAEngine._();

  static RadarSignal prepare({
    required MarketSnapshot market,
    required RadarSignal signal,
    EntryVariant entryVariant = EntryVariant.bosConfirmation,
    StopVariant stopVariant = StopVariant.structuralAtr,
    String profileId = 'live_confirmed',
  }) {
    final TimeframeAnalysis trigger = _triggerAnalysis(market, signal);
    final FalseBreakoutAnalysis falseBreakout = FalseBreakoutEngine.analyze(
      analysis: trigger,
      scenarioDirection: signal.direction.bias,
    );
    final StopPlan stopPlan = StopEngine.build(
      signal: signal,
      analysis: trigger,
      falseBreakout: falseBreakout,
      variant: stopVariant,
    );
    final EntryAssessment entry = EntryEngine.assess(
      signal: signal,
      market: market,
      falseBreakout: falseBreakout,
      stopIsSafe: stopPlan.safe,
      variant: entryVariant,
    );
    final SignalQualityScores qualities = _qualities(
      direction: market.strength,
      entry: entry.entryQuality,
      stopPlan: stopPlan,
    );
    final List<String> codes = _mergeCodes(<Iterable<String>>[
      signal.reasonCodes,
      const <String>['SETUP_FOUND'],
      stopPlan.reasonCodes,
      entry.reasonCodes,
    ]);
    final String preparedId = signal.id.endsWith(':$profileId')
        ? signal.id
        : '${signal.id}:$profileId';
    final SignalStage initialStage = entryVariant.mode == EntryMode.aggressive
        ? entry.stage
        : SignalStage.setupFound;
    final DateTime? initialConfirmationTime =
        initialStage == SignalStage.entryConfirmed
        ? _evaluationTime(market, signal)
        : null;

    return signal.copyWith(
      id: preparedId,
      stage: initialStage,
      entryMode: entryVariant.mode,
      entryVariant: entryVariant,
      stopVariant: stopVariant,
      executionProfileId: profileId,
      qualities: qualities,
      invalidationPrice: stopPlan.invalidationPrice,
      structuralStop: stopPlan.invalidationPrice,
      stop: stopPlan.stopPrice,
      stopBuffer: stopPlan.buffer,
      stopBufferAtr: stopPlan.bufferAtr,
      stopIsSafe: stopPlan.safe,
      executionAction: entryVariant.mode == EntryMode.aggressive
          ? entry.action
          : stopPlan.safe
          ? 'SETUP FOUND: ждём зону и подтверждающий триггер.'
          : 'NO TRADE: безопасный Stop слишком далеко или R:R слабый.',
      falseBreakoutState: falseBreakout.state,
      falseBreakoutLevel: falseBreakout.level,
      falseBreakoutScore: falseBreakout.score,
      liquiditySweepConfirmed: falseBreakout.liquiditySweepConfirmed,
      entryConfirmedTime: initialConfirmationTime,
      reasonCodes: codes,
    );
  }

  static RadarSignal update({
    required MarketSnapshot market,
    required RadarSignal signal,
  }) {
    if (signal.status != SignalStatus.waitingEntry ||
        signal.stage == SignalStage.entryConfirmed) {
      return signal;
    }
    final TimeframeAnalysis trigger = _triggerAnalysis(market, signal);
    final FalseBreakoutAnalysis falseBreakout = FalseBreakoutEngine.analyze(
      analysis: trigger,
      scenarioDirection: signal.direction.bias,
    );
    final StopPlan stopPlan = StopEngine.build(
      signal: signal,
      analysis: trigger,
      falseBreakout: falseBreakout,
      variant: signal.stopVariant,
    );
    final EntryAssessment entry = EntryEngine.assess(
      signal: signal,
      market: market,
      falseBreakout: falseBreakout,
      stopIsSafe: stopPlan.safe,
    );
    final SignalQualityScores qualities = _qualities(
      direction: signal.qualities.direction > 0
          ? signal.qualities.direction
          : market.strength,
      entry: entry.entryQuality,
      stopPlan: stopPlan,
    );
    final DateTime? confirmationTime = entry.stage == SignalStage.entryConfirmed
        ? signal.entryConfirmedTime ?? _evaluationTime(market, signal)
        : signal.entryConfirmedTime;
    final List<String> codes = _mergeCodes(<Iterable<String>>[
      signal.reasonCodes,
      stopPlan.reasonCodes,
      entry.reasonCodes,
    ]);

    return signal.copyWith(
      stage: entry.stage,
      qualities: qualities,
      invalidationPrice: stopPlan.invalidationPrice,
      structuralStop: stopPlan.invalidationPrice,
      stop: stopPlan.stopPrice,
      stopBuffer: stopPlan.buffer,
      stopBufferAtr: stopPlan.bufferAtr,
      stopIsSafe: stopPlan.safe,
      executionAction: entry.action,
      falseBreakoutState: falseBreakout.state,
      falseBreakoutLevel: falseBreakout.level,
      falseBreakoutScore: falseBreakout.score,
      liquiditySweepConfirmed: falseBreakout.liquiditySweepConfirmed,
      entryConfirmedTime: confirmationTime,
      reasonCodes: codes,
    );
  }

  static RadarSignal preview({
    required MarketSnapshot market,
    required RadarSignal signal,
  }) {
    final RadarSignal prepared = prepare(market: market, signal: signal);
    return update(market: market, signal: prepared);
  }

  static TimeframeAnalysis _triggerAnalysis(
    MarketSnapshot market,
    RadarSignal signal,
  ) {
    return signal.style == SignalStyle.scalp
        ? market.oneMinute
        : market.fiveMinutes;
  }

  static DateTime _evaluationTime(MarketSnapshot market, RadarSignal signal) {
    if (signal.style == SignalStyle.scalp) {
      return market.oneMinute.candles.last.time.add(const Duration(minutes: 1));
    }
    return market.fiveMinutes.candles.last.time.add(const Duration(minutes: 5));
  }

  static SignalQualityScores _qualities({
    required int direction,
    required int entry,
    required StopPlan stopPlan,
  }) {
    final int risk = !stopPlan.safe
        ? 35
        : stopPlan.riskReward >= 1.5
        ? 90
        : stopPlan.riskReward >= 1.0
        ? 76
        : 58;
    return SignalQualityScores(
      direction: _clampInt(direction, 0, 100),
      entry: _clampInt(entry, 0, 100),
      stop: stopPlan.quality,
      risk: risk,
    );
  }

  static List<String> _mergeCodes(List<Iterable<String>> groups) {
    final List<String> result = <String>[];
    for (final Iterable<String> group in groups) {
      for (final String code in group) {
        if (!result.contains(code)) {
          result.add(code);
        }
      }
    }
    return List<String>.unmodifiable(result);
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }
}
