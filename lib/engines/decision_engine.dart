import '../models/decision_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';

/// Converts already-computed [MarketSnapshot] values into one immutable
/// decision contract. It deliberately does not inspect or recalculate candles.
class DecisionEngine {
  const DecisionEngine._();

  static DecisionSnapshot build(MarketSnapshot market) {
    final TimeframeAnalysis one = market.oneMinute;
    final TimeframeAnalysis five = market.fiveMinutes;
    final TimeframeAnalysis fifteen = market.fifteenMinutes;
    final TimeframeAnalysis hour = market.oneHour;
    final TradePlan plan = market.tradePlan;
    final DecisionAction action = switch (market.signal) {
      'ПОКУПКА' => DecisionAction.long,
      'ПРОДАЖА' => DecisionAction.short,
      _ => DecisionAction.wait,
    };
    final Bias scenarioBias = plan.bias;
    final EntryDecision entryDecision = _entryDecision(
      action: action,
      bias: scenarioBias,
      price: market.ticker.price,
      entryLow: plan.entryLow,
      entryHigh: plan.entryHigh,
      atr: fifteen.atr,
    );
    final MarketRegimeHint regime = _regime(fifteen.trend, hour.trend);
    final DataQuality dataQuality = _dataQuality(market);
    final double entryMidpoint = (plan.entryLow + plan.entryHigh) / 2.0;
    final double risk = (entryMidpoint - plan.stop).abs();
    final double reward = (plan.tp1 - entryMidpoint).abs();
    final double riskReward = risk == 0.0 ? 0.0 : reward / risk;
    final double price = market.ticker.price;
    final double expectedMovePercent = price == 0.0
        ? 0.0
        : ((market.expectedHigh - market.expectedLow).abs() / 2.0) /
              price *
              100.0;

    final List<ReasonCode> reasons = <ReasonCode>[];
    final List<ReasonCode> warnings = <ReasonCode>[];
    final List<ReasonCode> invalidations = <ReasonCode>[];

    _addTimeframeReason(reasons, one.trend, '1m', scenarioBias);
    _addTimeframeReason(reasons, five.trend, '5m', scenarioBias);
    _addTimeframeReason(reasons, fifteen.trend, '15m', scenarioBias);
    _addTimeframeReason(reasons, hour.trend, '1h', scenarioBias);

    final bool higherTimeframesAligned =
        fifteen.trend == scenarioBias && hour.trend == scenarioBias;
    if (higherTimeframesAligned &&
        five.trend != Bias.neutral &&
        five.trend != scenarioBias) {
      _addUnique(
        warnings,
        five.trend == Bias.bullish
            ? ReasonCode.bullish5mCorrection
            : ReasonCode.bearish5mCorrection,
      );
      _addUnique(warnings, ReasonCode.correctionNotFinished);
    }

    if (_hasTimeframeConflict(five, fifteen, hour)) {
      _addUnique(warnings, ReasonCode.timeframeConflict);
    }

    if (fifteen.structure.bos == scenarioBias) {
      _addUnique(reasons, ReasonCode.bosConfirmed);
    } else {
      _addUnique(warnings, ReasonCode.noStructureConfirmation);
    }

    if (fifteen.structure.choch != Bias.neutral) {
      if (fifteen.structure.choch == scenarioBias) {
        _addUnique(
          reasons,
          scenarioBias == Bias.bullish
              ? ReasonCode.bullishChoch
              : ReasonCode.bearishChoch,
        );
      } else {
        _addUnique(warnings, ReasonCode.chochWarning);
        _addUnique(
          warnings,
          fifteen.structure.choch == Bias.bullish
              ? ReasonCode.bullishChoch
              : ReasonCode.bearishChoch,
        );
      }
    }

    final Bias macdBias = fifteen.macd.histogram > 0.0
        ? Bias.bullish
        : fifteen.macd.histogram < 0.0
        ? Bias.bearish
        : Bias.neutral;
    if (macdBias == scenarioBias) {
      _addUnique(reasons, ReasonCode.macdAligned);
    } else if (macdBias != Bias.neutral) {
      _addUnique(warnings, ReasonCode.macdOpposes);
    }

    final bool emaBullish =
        fifteen.ema20 > fifteen.ema50 && fifteen.ema50 > fifteen.ema200;
    final bool emaBearish =
        fifteen.ema20 < fifteen.ema50 && fifteen.ema50 < fifteen.ema200;
    if ((scenarioBias == Bias.bullish && emaBullish) ||
        (scenarioBias == Bias.bearish && emaBearish)) {
      _addUnique(reasons, ReasonCode.emaAligned);
    } else if (emaBullish || emaBearish) {
      _addUnique(warnings, ReasonCode.emaOpposes);
    }

    final bool rsiAligned = scenarioBias == Bias.bullish
        ? fifteen.rsi >= 50.0 && fifteen.rsi <= 70.0
        : fifteen.rsi <= 50.0 && fifteen.rsi >= 30.0;
    if (rsiAligned) {
      _addUnique(reasons, ReasonCode.rsiAligned);
    }
    if (fifteen.rsi > 70.0 || fifteen.rsi < 30.0) {
      _addUnique(warnings, ReasonCode.rsiOverextended);
    }

    if (fifteen.relativeVolume >= 1.2) {
      _addUnique(reasons, ReasonCode.rvolHigh);
    } else if (fifteen.relativeVolume < 0.8) {
      _addUnique(warnings, ReasonCode.rvolLow);
    } else {
      _addUnique(warnings, ReasonCode.rvolAverage);
    }

    if (price > 0.0 && fifteen.atr / price >= 0.02) {
      _addUnique(warnings, ReasonCode.atrHigh);
    }

    if (_hasZone(fifteen.orderBlocks, scenarioBias)) {
      _addUnique(
        reasons,
        scenarioBias == Bias.bullish
            ? ReasonCode.bullishOrderBlock
            : ReasonCode.bearishOrderBlock,
      );
    }
    if (_hasZone(fifteen.fairValueGaps, scenarioBias)) {
      _addUnique(reasons, ReasonCode.fvgConfluence);
    }

    if (scenarioBias == Bias.bullish) {
      if (fifteen.liquidity.above != null) {
        _addUnique(reasons, ReasonCode.liquidityAbove);
      }
      if (fifteen.liquidity.below != null && !fifteen.liquidity.sweepBelow) {
        _addUnique(warnings, ReasonCode.liquidityBelow);
      }
    } else {
      if (fifteen.liquidity.below != null) {
        _addUnique(reasons, ReasonCode.liquidityBelow);
      }
      if (fifteen.liquidity.above != null && !fifteen.liquidity.sweepAbove) {
        _addUnique(warnings, ReasonCode.liquidityAbove);
      }
    }
    final bool alignedSweep = scenarioBias == Bias.bullish
        ? fifteen.liquidity.sweepBelow
        : fifteen.liquidity.sweepAbove;
    if (alignedSweep) {
      _addUnique(reasons, ReasonCode.liquiditySweep);
    }

    switch (entryDecision) {
      case EntryDecision.enterNow:
        _addUnique(reasons, ReasonCode.entryAtGoodZone);
        break;
      case EntryDecision.waitForZone:
        _addUnique(warnings, ReasonCode.waitForEntryZone);
        break;
      case EntryDecision.tooLate:
        _addUnique(warnings, ReasonCode.entryTooLate);
        break;
    }

    if (riskReward >= 1.0) {
      _addUnique(reasons, ReasonCode.riskRewardGood);
    } else {
      _addUnique(warnings, ReasonCode.riskRewardPoor);
    }
    if (action == DecisionAction.wait) {
      _addUnique(warnings, ReasonCode.noTradeConditions);
    }
    if (dataQuality == DataQuality.low) {
      _addUnique(warnings, ReasonCode.dataQualityLow);
    }

    if (scenarioBias == Bias.bullish) {
      _addUnique(invalidations, ReasonCode.invalidationBelowStop);
      if (fifteen.support != null) {
        _addUnique(invalidations, ReasonCode.closeBelowSupport);
      }
      _addUnique(invalidations, ReasonCode.bearishChoch);
    } else {
      _addUnique(invalidations, ReasonCode.invalidationAboveStop);
      if (fifteen.resistance != null) {
        _addUnique(invalidations, ReasonCode.closeAboveResistance);
      }
      _addUnique(invalidations, ReasonCode.bullishChoch);
    }

    return DecisionSnapshot(
      symbol: market.symbol,
      timestamp: market.updatedAt,
      price: price,
      decision: action,
      signalScore: market.strength,
      marketRegime: regime,
      selectedStrategy: 'STANDARD_CONFIRMATION_V1',
      entryDecision: entryDecision,
      entryLow: plan.entryLow,
      entryHigh: plan.entryHigh,
      stop: plan.stop,
      tp1: plan.tp1,
      tp2: plan.tp2,
      riskReward: riskReward,
      leverage: plan.leverage,
      expectedMovePercent: expectedMovePercent,
      priceMagnet: market.magnetPrice,
      timeframeTrends: Map<String, Bias>.unmodifiable(<String, Bias>{
        '1м': one.trend,
        '5м': five.trend,
        '15м': fifteen.trend,
        '1ч': hour.trend,
      }),
      correctionState: _correctionState(
        five: five.trend,
        fifteen: fifteen.trend,
        hour: hour.trend,
        scenario: scenarioBias,
      ),
      bos: fifteen.structure.bos,
      choch: fifteen.structure.choch,
      support: fifteen.support,
      resistance: fifteen.resistance,
      orderBlocks: List<PriceZone>.unmodifiable(fifteen.orderBlocks),
      fairValueGaps: List<PriceZone>.unmodifiable(fifteen.fairValueGaps),
      liquidity: fifteen.liquidity,
      atr: fifteen.atr,
      relativeVolume: fifteen.relativeVolume,
      rsi: fifteen.rsi,
      macd: fifteen.macd,
      ema20: fifteen.ema20,
      ema50: fifteen.ema50,
      ema200: fifteen.ema200,
      dataQuality: dataQuality,
      reasonCodes: List<ReasonCode>.unmodifiable(reasons),
      warningCodes: List<ReasonCode>.unmodifiable(warnings),
      invalidationCodes: List<ReasonCode>.unmodifiable(invalidations),
    );
  }

  /// Stable context codes stored with Journal and Backtest signal records.
  /// This works for both STANDARD and SCALP signals and only reads values that
  /// were already calculated by [SignalEngine].
  static List<String> persistedReasonCodesForSignal(RadarSignal signal) {
    final List<ReasonCode> codes = <ReasonCode>[];
    _addSignalTrendCode(codes, signal.trend1m, '1m', signal.direction.bias);
    _addSignalTrendCode(codes, signal.trend5m, '5m', signal.direction.bias);
    _addSignalTrendCode(codes, signal.trend15m, '15m', signal.direction.bias);
    _addSignalTrendCode(codes, signal.trend1h, '1h', signal.direction.bias);

    if (signal.bos == signal.direction.bias) {
      _addUnique(codes, ReasonCode.bosConfirmed);
    } else {
      _addUnique(codes, ReasonCode.noStructureConfirmation);
    }
    if (signal.choch != Bias.neutral && signal.choch != signal.direction.bias) {
      _addUnique(codes, ReasonCode.chochWarning);
    }
    if (signal.relativeVolume >= 1.2) {
      _addUnique(codes, ReasonCode.rvolHigh);
    } else if (signal.relativeVolume < 0.8) {
      _addUnique(codes, ReasonCode.rvolLow);
    } else {
      _addUnique(codes, ReasonCode.rvolAverage);
    }
    final Bias macdBias = signal.macd > 0.0
        ? Bias.bullish
        : signal.macd < 0.0
        ? Bias.bearish
        : Bias.neutral;
    if (macdBias == signal.direction.bias) {
      _addUnique(codes, ReasonCode.macdAligned);
    } else if (macdBias != Bias.neutral) {
      _addUnique(codes, ReasonCode.macdOpposes);
    }
    final bool emaBullish =
        signal.ema20 > signal.ema50 && signal.ema50 > signal.ema200;
    final bool emaBearish =
        signal.ema20 < signal.ema50 && signal.ema50 < signal.ema200;
    if ((signal.direction == SignalDirection.long && emaBullish) ||
        (signal.direction == SignalDirection.short && emaBearish)) {
      _addUnique(codes, ReasonCode.emaAligned);
    } else if (emaBullish || emaBearish) {
      _addUnique(codes, ReasonCode.emaOpposes);
    }
    final bool rsiAligned = signal.direction == SignalDirection.long
        ? signal.rsi >= 50.0 && signal.rsi <= 70.0
        : signal.rsi <= 50.0 && signal.rsi >= 30.0;
    if (rsiAligned) {
      _addUnique(codes, ReasonCode.rsiAligned);
    }
    if (signal.rsi > 70.0 || signal.rsi < 30.0) {
      _addUnique(codes, ReasonCode.rsiOverextended);
    }
    if (signal.fvgBias == signal.direction.bias) {
      _addUnique(codes, ReasonCode.fvgConfluence);
    }
    if (signal.orderBlockBias == signal.direction.bias) {
      _addUnique(
        codes,
        signal.direction == SignalDirection.long
            ? ReasonCode.bullishOrderBlock
            : ReasonCode.bearishOrderBlock,
      );
    }
    if (signal.liquidityBias == signal.direction.bias) {
      _addUnique(codes, ReasonCode.liquiditySweep);
    }
    final double reward = (signal.tp1 - signal.entryPrice).abs();
    final double rewardRisk = signal.risk == 0.0 ? 0.0 : reward / signal.risk;
    _addUnique(
      codes,
      rewardRisk >= 1.0 ? ReasonCode.riskRewardGood : ReasonCode.riskRewardPoor,
    );
    _addUnique(codes, ReasonCode.entryAtGoodZone);
    return codes
        .map<String>((ReasonCode reason) => reason.code)
        .toList(growable: false);
  }

  static EntryDecision _entryDecision({
    required DecisionAction action,
    required Bias bias,
    required double price,
    required double entryLow,
    required double entryHigh,
    required double atr,
  }) {
    if (action == DecisionAction.wait) {
      return EntryDecision.waitForZone;
    }
    if (price >= entryLow && price <= entryHigh) {
      return EntryDecision.enterNow;
    }
    final double latePadding = atr * 0.25;
    final bool tooLate = bias == Bias.bullish
        ? price > entryHigh + latePadding
        : price < entryLow - latePadding;
    return tooLate ? EntryDecision.tooLate : EntryDecision.waitForZone;
  }

  static MarketRegimeHint _regime(Bias fifteen, Bias hour) {
    if (fifteen == Bias.bullish && hour == Bias.bullish) {
      return MarketRegimeHint.trendUp;
    }
    if (fifteen == Bias.bearish && hour == Bias.bearish) {
      return MarketRegimeHint.trendDown;
    }
    if (fifteen == Bias.neutral && hour == Bias.neutral) {
      return MarketRegimeHint.range;
    }
    return MarketRegimeHint.mixed;
  }

  static DataQuality _dataQuality(MarketSnapshot market) {
    final int minimum = <int>[
      market.oneMinute.candles.length,
      market.fiveMinutes.candles.length,
      market.fifteenMinutes.candles.length,
      market.oneHour.candles.length,
    ].reduce((int first, int second) => first < second ? first : second);
    if (minimum >= 200) {
      return DataQuality.high;
    }
    if (minimum >= 80) {
      return DataQuality.medium;
    }
    return DataQuality.low;
  }

  static bool _hasTimeframeConflict(
    TimeframeAnalysis five,
    TimeframeAnalysis fifteen,
    TimeframeAnalysis hour,
  ) {
    final bool higherConflict =
        fifteen.trend != Bias.neutral &&
        hour.trend != Bias.neutral &&
        fifteen.trend != hour.trend;
    final bool lowerConflict =
        five.trend != Bias.neutral &&
        fifteen.trend != Bias.neutral &&
        five.trend != fifteen.trend;
    return higherConflict || lowerConflict;
  }

  static bool _hasZone(List<PriceZone> zones, Bias bias) {
    return zones.any((PriceZone zone) => zone.bias == bias);
  }

  static String _correctionState({
    required Bias five,
    required Bias fifteen,
    required Bias hour,
    required Bias scenario,
  }) {
    if (fifteen == scenario && hour == scenario && five != scenario) {
      return five == Bias.bullish
          ? 'BULLISH_5M_CORRECTION_ACTIVE'
          : five == Bias.bearish
          ? 'BEARISH_5M_CORRECTION_ACTIVE'
          : '5M_CORRECTION_UNCONFIRMED';
    }
    return 'NO_CONFIRMED_CORRECTION';
  }

  static void _addTimeframeReason(
    List<ReasonCode> target,
    Bias trend,
    String timeframe,
    Bias scenario,
  ) {
    if (trend == Bias.neutral || trend != scenario) {
      return;
    }
    final ReasonCode reason = switch ((timeframe, trend)) {
      ('1m', Bias.bullish) => ReasonCode.bullish1mStructure,
      ('1m', Bias.bearish) => ReasonCode.bearish1mStructure,
      ('5m', Bias.bullish) => ReasonCode.bullish5mStructure,
      ('5m', Bias.bearish) => ReasonCode.bearish5mStructure,
      ('15m', Bias.bullish) => ReasonCode.bullish15mStructure,
      ('15m', Bias.bearish) => ReasonCode.bearish15mStructure,
      ('1h', Bias.bullish) => ReasonCode.bullish1hStructure,
      ('1h', Bias.bearish) => ReasonCode.bearish1hStructure,
      _ => throw StateError('Unsupported timeframe/trend pair'),
    };
    _addUnique(target, reason);
  }

  static void _addSignalTrendCode(
    List<ReasonCode> target,
    Bias trend,
    String timeframe,
    Bias scenario,
  ) {
    if (trend != scenario || trend == Bias.neutral) {
      return;
    }
    _addTimeframeReason(target, trend, timeframe, scenario);
  }

  static void _addUnique(List<ReasonCode> target, ReasonCode reason) {
    if (!target.contains(reason)) {
      target.add(reason);
    }
  }
}
