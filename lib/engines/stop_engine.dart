import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';

class StopEngine {
  const StopEngine._();

  static StopPlan build({
    required RadarSignal signal,
    required TimeframeAnalysis analysis,
    required FalseBreakoutAnalysis falseBreakout,
    StopVariant variant = StopVariant.structuralAtr,
  }) {
    final double entry = signal.entryPrice;
    final double atr = analysis.atr > 0.0 ? analysis.atr : entry * 0.005;
    final double invalidation = _invalidation(
      signal: signal,
      analysis: analysis,
      atr: atr,
    );
    final double tickSize = _estimatedTickSize(entry);
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

    double buffer;
    switch (variant) {
      case StopVariant.structural:
        buffer = tickSize * 2.0;
        break;
      case StopVariant.structuralAtr:
        buffer = _maxDouble(atr * atrFactor, tickSize * 3.0);
        break;
      case StopVariant.structuralWick:
        buffer = _maxDouble(
          _maxDouble(typicalWick * 1.15, atr * 0.10),
          tickSize * 3.0,
        );
        break;
    }
    if (falseBreakout.state == FalseBreakoutState.confirmed) {
      buffer = _maxDouble(buffer, falseBreakout.overshoot * 1.20);
    }

    final bool bullish = signal.direction == SignalDirection.long;
    final double stop = bullish ? invalidation - buffer : invalidation + buffer;
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
    final bool safe = !tooFar && !poorRiskReward;

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
    );
  }

  static double _invalidation({
    required RadarSignal signal,
    required TimeframeAnalysis analysis,
    required double atr,
  }) {
    final double entry = signal.entryPrice;
    final List<double> candidates = <double>[];
    if (signal.direction == SignalDirection.long) {
      _addBelow(candidates, analysis.structure.lastSwingLow, entry);
      _addBelow(candidates, analysis.support, entry);
      for (final PriceZone zone in analysis.orderBlocks) {
        if (zone.bias == Bias.bullish) {
          _addBelow(candidates, zone.lower, entry);
        }
      }
      _addBelow(candidates, signal.stop, entry);
      if (candidates.isEmpty) {
        return entry - atr;
      }
      return candidates.reduce(_maxDouble);
    }

    _addAbove(candidates, analysis.structure.lastSwingHigh, entry);
    _addAbove(candidates, analysis.resistance, entry);
    for (final PriceZone zone in analysis.orderBlocks) {
      if (zone.bias == Bias.bearish) {
        _addAbove(candidates, zone.upper, entry);
      }
    }
    _addAbove(candidates, signal.stop, entry);
    if (candidates.isEmpty) {
      return entry + atr;
    }
    return candidates.reduce(_minDouble);
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

  static double _estimatedTickSize(double price) {
    if (price >= 10000.0) {
      return 0.10;
    }
    if (price >= 100.0) {
      return 0.01;
    }
    if (price >= 1.0) {
      return 0.0001;
    }
    return 0.000001;
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
