import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';

class EntryEngine {
  const EntryEngine._();

  static EntryAssessment assess({
    required RadarSignal signal,
    required MarketSnapshot market,
    required FalseBreakoutAnalysis falseBreakout,
    required bool stopIsSafe,
    EntryVariant? variant,
  }) {
    final EntryVariant selectedVariant = variant ?? signal.entryVariant;
    final TimeframeAnalysis trigger = signal.style == SignalStyle.scalp
        ? market.oneMinute
        : market.fiveMinutes;
    final Bias direction = signal.direction.bias;
    final double price = market.ticker.price;
    final double tolerance = trigger.atr * 0.12;
    final bool zoneReached =
        price >= signal.entryLow - tolerance &&
        price <= signal.entryHigh + tolerance;
    final bool localStructureConfirmed =
        signal.direction == SignalDirection.long
        ? trigger.structure.lowLabel == 'HL' ||
              trigger.structure.bias == Bias.bullish
        : trigger.structure.highLabel == 'LH' ||
              trigger.structure.bias == Bias.bearish;
    final bool bosConfirmed =
        trigger.structure.bos == direction ||
        market.fifteenMinutes.structure.bos == direction;
    final bool chochConfirmed =
        trigger.structure.choch == direction ||
        market.fifteenMinutes.structure.choch == direction;
    final Candle latest = trigger.candles.last;
    final double body = (latest.close - latest.open).abs();
    final double directionalWick = signal.direction == SignalDirection.long
        ? _minDouble(latest.open, latest.close) - latest.low
        : latest.high - _maxDouble(latest.open, latest.close);
    final bool directionCandle = signal.direction == SignalDirection.long
        ? latest.isBullish
        : latest.isBearish;
    final bool confirmationCandle =
        directionCandle &&
        (body >= latest.range * 0.30 || directionalWick >= latest.range * 0.35);
    final bool volumeConfirmed = trigger.relativeVolume >= 0.80;
    final bool retestConfirmed =
        zoneReached &&
        (latest.low <= signal.entryHigh && latest.high >= signal.entryLow);
    final bool correctionEnded =
        market.fiveMinutes.trend == direction &&
        (localStructureConfirmed || bosConfirmed || chochConfirmed);

    final bool triggerConfirmed;
    switch (selectedVariant) {
      case EntryVariant.immediate:
        triggerConfirmed = true;
        break;
      case EntryVariant.zone:
        triggerConfirmed = zoneReached;
        break;
      case EntryVariant.correctionEnd:
        triggerConfirmed = zoneReached && correctionEnded && confirmationCandle;
        break;
      case EntryVariant.bosConfirmation:
        triggerConfirmed =
            zoneReached &&
            bosConfirmed &&
            confirmationCandle &&
            (localStructureConfirmed || chochConfirmed || volumeConfirmed);
        break;
      case EntryVariant.falseBreakoutReclaim:
        triggerConfirmed =
            falseBreakout.state == FalseBreakoutState.confirmed &&
            falseBreakout.reclaimed &&
            confirmationCandle;
        break;
      case EntryVariant.falseBreakoutBosRetest:
        triggerConfirmed =
            falseBreakout.state == FalseBreakoutState.confirmed &&
            falseBreakout.reclaimed &&
            bosConfirmed &&
            retestConfirmed &&
            confirmationCandle;
        break;
    }

    final SignalStage stage;
    final String action;
    if (!stopIsSafe) {
      stage = SignalStage.waitForTrigger;
      action = 'NO TRADE: безопасный Stop слишком далеко или R:R слабый.';
    } else if (triggerConfirmed) {
      stage = SignalStage.entryConfirmed;
      action = 'ENTRY READY: подтверждения для входа выполнены.';
    } else if (!zoneReached && selectedVariant != EntryVariant.immediate) {
      stage = SignalStage.waitForZone;
      action = 'Не входить: ждём возврат цены в Entry Zone.';
    } else {
      stage = SignalStage.waitForTrigger;
      action = falseBreakout.state == FalseBreakoutState.possible
          ? 'Не входить: возможен sweep, но возврат и структура ещё не подтверждены.'
          : 'Не входить: ждём завершение коррекции и структурный триггер.';
    }

    int quality = selectedVariant.mode == EntryMode.aggressive ? 38 : 30;
    if (zoneReached) quality += 15;
    if (localStructureConfirmed) quality += 12;
    if (bosConfirmed) quality += 18;
    if (chochConfirmed) quality += 8;
    if (confirmationCandle) quality += 10;
    if (volumeConfirmed) quality += 5;
    if (retestConfirmed) quality += 5;
    if (falseBreakout.state == FalseBreakoutState.confirmed) quality += 18;
    if (!stopIsSafe) quality = _minInt(quality, 45);
    quality = _clampInt(quality, 0, 100);

    final List<String> codes = <String>[
      selectedVariant.mode == EntryMode.confirmed
          ? 'CONFIRMED_ENTRY'
          : 'AGGRESSIVE_ENTRY',
      if (zoneReached) 'ENTRY_ZONE_REACHED',
      if (localStructureConfirmed) 'LOCAL_STRUCTURE_CONFIRMED',
      if (bosConfirmed) 'BOS_CONFIRMED',
      if (chochConfirmed) 'CHOCH_RECLAIM_CONFIRMED',
      if (confirmationCandle) 'CONFIRMATION_CANDLE_CLOSED',
      if (volumeConfirmed) 'ENTRY_VOLUME_CONFIRMED',
      if (retestConfirmed) 'ZONE_RETEST_CONFIRMED',
      if (correctionEnded) 'CORRECTION_ENDED',
      if (falseBreakout.state == FalseBreakoutState.possible)
        'FALSE_BREAKOUT_POSSIBLE',
      if (falseBreakout.state == FalseBreakoutState.confirmed)
        'FALSE_BREAKOUT_CONFIRMED',
      if (falseBreakout.reclaimed) 'RECLAIM_CONFIRMED',
      if (falseBreakout.liquiditySweepConfirmed) 'LIQUIDITY_SWEEP_CONFIRMED',
      if (stage == SignalStage.waitForZone) 'WAIT_FOR_ENTRY_ZONE',
      if (stage == SignalStage.waitForTrigger) 'WAIT_FOR_TRIGGER',
      if (stage == SignalStage.entryConfirmed) 'ENTRY_CONFIRMED',
    ];

    return EntryAssessment(
      stage: stage,
      zoneReached: zoneReached,
      localStructureConfirmed: localStructureConfirmed,
      bosConfirmed: bosConfirmed,
      chochConfirmed: chochConfirmed,
      confirmationCandle: confirmationCandle,
      volumeConfirmed: volumeConfirmed,
      retestConfirmed: retestConfirmed,
      falseBreakout: falseBreakout,
      entryQuality: quality,
      action: action,
      reasonCodes: List<String>.unmodifiable(codes),
    );
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  static int _minInt(int first, int second) => first <= second ? first : second;

  static double _maxDouble(double first, double second) =>
      first >= second ? first : second;

  static double _minDouble(double first, double second) =>
      first <= second ? first : second;
}
