import '../config/trading_safety_config.dart';
import '../models/execution_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import '../utils/exchange_decimal.dart';

class StopEngine {
  const StopEngine._();

  static StopPlan build({
    required RadarSignal signal,
    required TimeframeAnalysis analysis,
    required FalseBreakoutAnalysis falseBreakout,
    StopVariant variant = StopVariant.structuralAtr,
    InstrumentTradingRules? tradingRules,
    double observedSpread = 0.0,
    FeeModel feeModel = const FeeModel(),
  }) {
    final double entry = signal.entryPrice;
    if (tradingRules == null || !tradingRules.isComplete) {
      return StopPlan(
        variant: variant,
        invalidationPrice: signal.stop,
        stopPrice: signal.stop,
        buffer: 0.0,
        bufferAtr: 0.0,
        bufferPercent: 0.0,
        riskReward: 0.0,
        safe: false,
        quality: 0,
        reasonCodes: const <String>['INSTRUMENT_RULES_UNAVAILABLE'],
        structuralStopFound: false,
        bufferComplete: false,
      );
    }
    final double atr = analysis.atr;
    double? invalidation = findStructuralInvalidation(
      direction: signal.direction,
      analysis: analysis,
      entry: entry,
      seed: signal.structuralStop > 0.0
          ? signal.structuralStop
          : signal.invalidationPrice > 0.0
          ? signal.invalidationPrice
          : null,
    );
    if (falseBreakout.state == FalseBreakoutState.confirmed) {
      invalidation = _closerInvalidation(
        direction: signal.direction,
        entry: entry,
        current: invalidation,
        candidate: falseBreakout.level,
      );
    }
    if (invalidation == null || atr <= 0.0) {
      return StopPlan(
        variant: variant,
        invalidationPrice: invalidation ?? 0.0,
        stopPrice: 0.0,
        buffer: 0.0,
        bufferAtr: 0.0,
        bufferPercent: 0.0,
        riskReward: 0.0,
        safe: false,
        quality: 0,
        reasonCodes: <String>[
          if (invalidation == null) 'STRUCTURAL_STOP_MISSING',
          if (atr <= 0.0) 'ATR_UNAVAILABLE',
        ],
        structuralStopFound: invalidation != null,
        bufferComplete: false,
      );
    }
    final double tickSize = tradingRules.tickSize;
    final double typicalWick = _typicalAdverseWick(
      analysis.candles,
      signal.direction,
    );
    final double volatilityPercent = entry == 0.0 ? 0.0 : atr / entry;
    final double atrFactor = volatilityPercent >= 0.02
        ? 0.28
        : volatilityPercent >= 0.01
        ? 0.22
        : 0.16;

    double preferredBuffer;
    switch (variant) {
      case StopVariant.structural:
        preferredBuffer = tickSize * 3.0;
        break;
      case StopVariant.structuralAtr:
        preferredBuffer = _maxDouble(atr * atrFactor, tickSize * 3.0);
        break;
      case StopVariant.structuralWick:
        preferredBuffer = _maxDouble(
          _maxDouble(typicalWick * 1.15, atr * 0.10),
          tickSize * 3.0,
        );
        break;
    }
    final double slippageBuffer = entry * feeModel.stopSlippagePercent / 100.0;
    final double minimumBuffer = <double>[
      atr * TradingSafetyConfig.minStopAtrBuffer,
      observedSpread.abs() * TradingSafetyConfig.spreadBufferMultiplier,
      slippageBuffer * TradingSafetyConfig.slippageBufferMultiplier,
      tickSize * TradingSafetyConfig.tickBufferMultiplier,
    ].reduce(_maxDouble);
    double buffer = _maxDouble(preferredBuffer, minimumBuffer);
    if (falseBreakout.state == FalseBreakoutState.confirmed) {
      buffer = _maxDouble(buffer, falseBreakout.overshoot * 1.20);
    }

    final bool bullish = signal.direction == SignalDirection.long;
    final double rawStop = bullish
        ? invalidation - buffer
        : invalidation + buffer;
    final double stop = bullish
        ? ExchangeDecimal.floorToStep(rawStop, tickSize)
        : ExchangeDecimal.ceilToStep(rawStop, tickSize);
    final double riskDistance = (entry - stop).abs();
    final double rewardDistance = (signal.tp1 - entry).abs();
    final double riskReward = riskDistance == 0.0
        ? 0.0
        : rewardDistance / riskDistance;
    final double maximumDistance = signal.style == SignalStyle.scalp
        ? _maxDouble(atr * 1.35, entry * 0.004)
        : _maxDouble(atr * 2.0, entry * 0.025);
    final bool tooFar = riskDistance > maximumDistance;
    final bool poorRiskReward = riskReward < 0.90;
    final double appliedBuffer = (stop - invalidation).abs();
    final bool tooTight = appliedBuffer + tickSize * 0.1 < minimumBuffer;
    final bool safe = !tooFar && !poorRiskReward && !tooTight;

    int quality = variant == StopVariant.structuralAtr
        ? 78
        : variant == StopVariant.structuralWick
        ? 74
        : 55;
    if (falseBreakout.state == FalseBreakoutState.confirmed) {
      quality += 8;
    }
    if (!safe) {
      quality -= 35;
    }
    quality = _clampInt(quality, 0, 100);

    final List<String> codes = <String>[
      if (variant != StopVariant.structural) 'DYNAMIC_STOP_BUFFER',
      if (tooFar) 'SAFE_STOP_TOO_FAR',
      if (tooTight) 'STOP_TOO_TIGHT',
      if (poorRiskReward) 'RISK_REWARD_POOR',
      if (safe) 'RISK_REWARD_GOOD',
    ];
    return StopPlan(
      variant: variant,
      invalidationPrice: invalidation,
      stopPrice: stop,
      buffer: buffer,
      bufferAtr: atr == 0.0 ? 0.0 : buffer / atr,
      bufferPercent: entry == 0.0 ? 0.0 : buffer / entry * 100.0,
      riskReward: riskReward,
      safe: safe,
      quality: quality,
      reasonCodes: List<String>.unmodifiable(codes),
      structuralStopFound: true,
      bufferComplete: !tooTight,
      tooTight: tooTight,
    );
  }

  static double? findStructuralInvalidation({
    required SignalDirection direction,
    required TimeframeAnalysis analysis,
    required double entry,
    double? seed,
  }) {
    final List<double> candidates = <double>[];
    if (direction == SignalDirection.long) {
      _addBelow(candidates, analysis.structure.lastSwingLow, entry);
      _addBelow(candidates, analysis.support, entry);
      _addBelow(candidates, analysis.liquidity.below, entry);
      for (final PriceZone zone in analysis.orderBlocks) {
        if (zone.bias == Bias.bullish) {
          _addBelow(candidates, zone.lower, entry);
        }
      }
      for (final PriceZone zone in analysis.fairValueGaps) {
        if (zone.bias == Bias.bullish) {
          _addBelow(candidates, zone.lower, entry);
        }
      }
      _addBelow(candidates, seed, entry);
      if (candidates.isEmpty) return null;
      return candidates.reduce(_maxDouble);
    }

    _addAbove(candidates, analysis.structure.lastSwingHigh, entry);
    _addAbove(candidates, analysis.resistance, entry);
    _addAbove(candidates, analysis.liquidity.above, entry);
    for (final PriceZone zone in analysis.orderBlocks) {
      if (zone.bias == Bias.bearish) {
        _addAbove(candidates, zone.upper, entry);
      }
    }
    for (final PriceZone zone in analysis.fairValueGaps) {
      if (zone.bias == Bias.bearish) {
        _addAbove(candidates, zone.upper, entry);
      }
    }
    _addAbove(candidates, seed, entry);
    if (candidates.isEmpty) return null;
    return candidates.reduce(_minDouble);
  }

  static double? _closerInvalidation({
    required SignalDirection direction,
    required double entry,
    required double? current,
    required double candidate,
  }) {
    final bool valid = direction == SignalDirection.long
        ? candidate > 0.0 && candidate < entry
        : candidate > entry;
    if (!valid) return current;
    if (current == null) return candidate;
    return direction == SignalDirection.long
        ? _maxDouble(current, candidate)
        : _minDouble(current, candidate);
  }

  static double _typicalAdverseWick(
    List<Candle> candles,
    SignalDirection direction,
  ) {
    if (candles.isEmpty) {
      return 0.0;
    }
    final int start = candles.length > 30 ? candles.length - 30 : 0;
    double total = 0.0;
    int count = 0;
    for (int index = start; index < candles.length; index++) {
      final Candle candle = candles[index];
      final double wick = direction == SignalDirection.long
          ? _maxDouble(0.0, _minDouble(candle.open, candle.close) - candle.low)
          : _maxDouble(
              0.0,
              candle.high - _maxDouble(candle.open, candle.close),
            );
      total += wick;
      count++;
    }
    return count == 0 ? 0.0 : total / count;
  }

  static void _addBelow(List<double> target, double? value, double entry) {
    if (value != null && value > 0.0 && value < entry) {
      target.add(value);
    }
  }

  static void _addAbove(List<double> target, double? value, double entry) {
    if (value != null && value > entry) {
      target.add(value);
    }
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }
    if (value > maximum) {
      return maximum;
    }
    return value;
  }

  static double _maxDouble(double first, double second) =>
      first >= second ? first : second;

  static double _minDouble(double first, double second) =>
      first <= second ? first : second;
}
