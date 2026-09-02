import '../models/execution_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
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
    FeeModel feeModel = const FeeModel(),
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
      tradingRules: market.tradingRules,
      observedSpread: market.ticker.spread,
      feeModel: feeModel,
    );
    final EntryAssessment entry = EntryEngine.assess(
      signal: signal,
      market: market,
      falseBreakout: falseBreakout,
      stopIsSafe: stopPlan.safe,
      variant: entryVariant,
    );
    final SignalQualityScores qualities = _qualities(
      market: market,
      direction: market.strength,
      entry: entry.entryQuality,
      stopPlan: stopPlan,
      falseBreakout: falseBreakout,
    );
    final bool dataBlocked =
        market.dataIntegrity.checkedAt != null &&
        market.dataIntegrity.hasCriticalIssue;
    final SignalQualityScores effectiveQualities = dataBlocked
        ? SignalQualityScores(
            direction: qualities.direction,
            entry: 0,
            stop: stopPlan.quality,
            risk: 0,
            location: qualities.location,
            liquidity: qualities.liquidity,
            data: 0,
            setup: qualities.setup,
          )
        : qualities;
    final List<String> codes = _mergeCodes(<Iterable<String>>[
      signal.reasonCodes,
      const <String>['SETUP_FOUND'],
      stopPlan.reasonCodes,
      entry.reasonCodes,
      if (dataBlocked) market.dataIntegrity.issues,
    ]);
    final String preparedId = signal.id.endsWith(':$profileId')
        ? signal.id
        : '${signal.id}:$profileId';
    final SignalStage initialStage = dataBlocked
        ? SignalStage.setupFound
        : entryVariant.mode == EntryMode.aggressive
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
      qualities: effectiveQualities,
      invalidationPrice: stopPlan.invalidationPrice,
      structuralStop: stopPlan.invalidationPrice,
      stop: stopPlan.stopPrice,
      stopBuffer: stopPlan.buffer,
      stopBufferAtr: stopPlan.bufferAtr,
      stopIsSafe: stopPlan.safe && !dataBlocked,
      executionAction: dataBlocked
          ? 'NO TRADE: критические рыночные данные отсутствуют или устарели.'
          : entryVariant.mode == EntryMode.aggressive
          ? entry.action
          : !stopPlan.structuralStopFound
          ? 'NO TRADE: структурная отмена сетапа не определена.'
          : stopPlan.tooTight
          ? 'NO TRADE: Stop слишком близко к структурной отмене.'
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
    FeeModel feeModel = const FeeModel(),
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
      tradingRules: market.tradingRules,
      observedSpread: market.ticker.spread,
      feeModel: feeModel,
    );
    final EntryAssessment entry = EntryEngine.assess(
      signal: signal,
      market: market,
      falseBreakout: falseBreakout,
      stopIsSafe: stopPlan.safe,
    );
    final SignalQualityScores qualities = _qualities(
      market: market,
      direction: signal.qualities.direction > 0
          ? signal.qualities.direction
          : market.strength,
      entry: entry.entryQuality,
      stopPlan: stopPlan,
      falseBreakout: falseBreakout,
    );
    final bool dataBlocked =
        market.dataIntegrity.checkedAt != null &&
        market.dataIntegrity.hasCriticalIssue;
    final SignalQualityScores effectiveQualities = dataBlocked
        ? SignalQualityScores(
            direction: qualities.direction,
            entry: 0,
            stop: stopPlan.quality,
            risk: 0,
            location: qualities.location,
            liquidity: qualities.liquidity,
            data: 0,
            setup: qualities.setup,
          )
        : qualities;
    final SignalStage effectiveStage = dataBlocked
        ? SignalStage.setupFound
        : entry.stage;
    final DateTime? confirmationTime =
        effectiveStage == SignalStage.entryConfirmed
        ? signal.entryConfirmedTime ?? _evaluationTime(market, signal)
        : signal.entryConfirmedTime;
    final List<String> codes = _mergeCodes(<Iterable<String>>[
      signal.reasonCodes,
      stopPlan.reasonCodes,
      entry.reasonCodes,
      if (dataBlocked) market.dataIntegrity.issues,
    ]);

    return signal.copyWith(
      stage: effectiveStage,
      qualities: effectiveQualities,
      invalidationPrice: stopPlan.invalidationPrice,
      structuralStop: stopPlan.invalidationPrice,
      stop: stopPlan.stopPrice,
      stopBuffer: stopPlan.buffer,
      stopBufferAtr: stopPlan.bufferAtr,
      stopIsSafe: stopPlan.safe && !dataBlocked,
      executionAction: dataBlocked
          ? 'NO TRADE: критические рыночные данные отсутствуют или устарели.'
          : !stopPlan.structuralStopFound
          ? 'NO TRADE: структурная отмена сетапа не определена.'
          : stopPlan.tooTight
          ? 'NO TRADE: Stop слишком близко к структурной отмене.'
          : entry.action,
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
    FeeModel feeModel = const FeeModel(),
  }) {
    final RadarSignal prepared = prepare(
      market: market,
      signal: signal,
      feeModel: feeModel,
    );
    return update(market: market, signal: prepared, feeModel: feeModel);
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
    required MarketSnapshot market,
    required int direction,
    required int entry,
    required StopPlan stopPlan,
    required FalseBreakoutAnalysis falseBreakout,
  }) {
    final int risk = !stopPlan.safe
        ? 35
        : stopPlan.riskReward >= 1.5
        ? 90
        : stopPlan.riskReward >= 1.0
        ? 76
        : 58;
    final int location = _locationQuality(market);
    final int liquidity = falseBreakout.state == FalseBreakoutState.confirmed
        ? 92
        : falseBreakout.state == FalseBreakoutState.possible
        ? 58
        : market.fifteenMinutes.liquidity.sweepAbove ||
              market.fifteenMinutes.liquidity.sweepBelow
        ? 78
        : 35;
    final int data = switch (market.dataIntegrity.level) {
      MarketDataQualityLevel.high => 95,
      MarketDataQualityLevel.medium => 65,
      MarketDataQualityLevel.low => 0,
    };
    final int setup = ((direction + location + liquidity) / 3.0).round();
    return SignalQualityScores(
      direction: _clampInt(direction, 0, 100),
      entry: _clampInt(entry, 0, 100),
      stop: stopPlan.quality,
      risk: risk,
      location: location,
      liquidity: liquidity,
      data: data,
      setup: _clampInt(setup, 0, 100),
    );
  }

  static int _locationQuality(MarketSnapshot market) {
    final TimeframeAnalysis analysis = market.fifteenMinutes;
    final double price = market.ticker.price;
    final double atr = analysis.atr;
    if (price <= 0.0 || atr <= 0.0) return 0;
    int quality = 30;
    final Iterable<double> levels = <double?>[
      analysis.support,
      analysis.resistance,
      analysis.structure.lastSwingHigh,
      analysis.structure.lastSwingLow,
    ].whereType<double>();
    if (levels.any((double level) => (level - price).abs() <= atr * 0.5)) {
      quality += 30;
    }
    final Iterable<PriceZone> zones = <PriceZone>[
      ...analysis.orderBlocks,
      ...analysis.fairValueGaps,
    ];
    if (zones.any(
      (PriceZone zone) =>
          price >= zone.lower - atr * 0.25 && price <= zone.upper + atr * 0.25,
    )) {
      quality += 25;
    }
    final double? support = analysis.support;
    final double? resistance = analysis.resistance;
    if (support != null && resistance != null && resistance > support) {
      final double position = (price - support) / (resistance - support);
      if (position >= 0.4 && position <= 0.6) quality -= 20;
    }
    return _clampInt(quality, 0, 100);
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
