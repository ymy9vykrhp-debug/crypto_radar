// Extracted from the verified working radar.
enum Bias { bullish, bearish, neutral }

extension BiasText on Bias {
  String get label {
    switch (this) {
      case Bias.bullish:
        return 'LONG';
      case Bias.bearish:
        return 'SHORT';
      case Bias.neutral:
        return 'НЕЙТРАЛЬНО';
    }
  }
}

enum ZoneKind { fairValueGap, orderBlock }

class Candle {
  const Candle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  bool get isBullish => close >= open;
  bool get isBearish => close < open;
  double get range => high - low;
}

class PriceZone {
  const PriceZone({
    required this.lower,
    required this.upper,
    required this.bias,
    required this.kind,
    required this.timeframe,
  });

  final double lower;
  final double upper;
  final Bias bias;
  final ZoneKind kind;
  final String timeframe;

  double get midpoint => (lower + upper) / 2.0;
}

class SwingPoint {
  const SwingPoint({
    required this.index,
    required this.price,
    required this.isHigh,
  });

  final int index;
  final double price;
  final bool isHigh;
}

class TickerStats {
  const TickerStats({
    required this.price,
    required this.change24hPercent,
    required this.turnover24h,
  });

  final double price;
  final double change24hPercent;
  final double turnover24h;
}

class MacdResult {
  const MacdResult({
    required this.macd,
    required this.signal,
    required this.histogram,
  });

  final double macd;
  final double signal;
  final double histogram;
}

class IchimokuResult {
  const IchimokuResult({
    required this.conversion,
    required this.base,
    required this.spanA,
    required this.spanB,
    required this.bias,
  });

  final double conversion;
  final double base;
  final double spanA;
  final double spanB;
  final Bias bias;
}

class FibonacciResult {
  const FibonacciResult({
    required this.swingLow,
    required this.swingHigh,
    required this.nearestLevel,
    required this.ratio,
  });

  final double swingLow;
  final double swingHigh;
  final double nearestLevel;
  final double ratio;
}

class StructureResult {
  const StructureResult({
    required this.highLabel,
    required this.lowLabel,
    required this.bias,
    required this.bos,
    required this.choch,
    required this.lastSwingHigh,
    required this.lastSwingLow,
  });

  final String highLabel;
  final String lowLabel;
  final Bias bias;
  final Bias bos;
  final Bias choch;
  final double? lastSwingHigh;
  final double? lastSwingLow;
}

class LiquidityResult {
  const LiquidityResult({
    required this.above,
    required this.below,
    required this.sweepAbove,
    required this.sweepBelow,
  });

  final double? above;
  final double? below;
  final bool sweepAbove;
  final bool sweepBelow;
}

class TimeframeAnalysis {
  const TimeframeAnalysis({
    required this.name,
    required this.candles,
    required this.price,
    required this.ema20,
    required this.ema50,
    required this.ema200,
    required this.rsi,
    required this.macd,
    required this.relativeVolume,
    required this.atr,
    required this.trend,
    required this.ichimoku,
    required this.fibonacci,
    required this.structure,
    required this.support,
    required this.resistance,
    required this.liquidity,
    required this.fairValueGaps,
    required this.orderBlocks,
  });

  final String name;
  final List<Candle> candles;
  final double price;
  final double ema20;
  final double ema50;
  final double ema200;
  final double rsi;
  final MacdResult macd;
  final double relativeVolume;
  final double atr;
  final Bias trend;
  final IchimokuResult ichimoku;
  final FibonacciResult fibonacci;
  final StructureResult structure;
  final double? support;
  final double? resistance;
  final LiquidityResult liquidity;
  final List<PriceZone> fairValueGaps;
  final List<PriceZone> orderBlocks;
}

class ConfirmationItem {
  const ConfirmationItem({
    required this.name,
    required this.value,
    required this.bias,
    required this.weight,
  });

  final String name;
  final String value;
  final Bias bias;
  final int weight;
}

class TradePlan {
  const TradePlan({
    required this.bias,
    required this.entryLow,
    required this.entryHigh,
    required this.stop,
    required this.tp1,
    required this.tp2,
    required this.leverage,
    required this.reason,
  });

  final Bias bias;
  final double entryLow;
  final double entryHigh;
  final double stop;
  final double tp1;
  final double tp2;
  final int leverage;
  final String reason;
}

class MarketSnapshot {
  const MarketSnapshot({
    required this.symbol,
    required this.ticker,
    required this.oneMinute,
    required this.fiveMinutes,
    required this.fifteenMinutes,
    required this.oneHour,
    required this.confirmations,
    required this.longScore,
    required this.shortScore,
    required this.signal,
    required this.strength,
    required this.magnetPrice,
    required this.magnetLabel,
    required this.potentialPercent,
    required this.expectedLow,
    required this.expectedHigh,
    required this.tradePlan,
    required this.updatedAt,
  });

  final String symbol;
  final TickerStats ticker;
  final TimeframeAnalysis oneMinute;
  final TimeframeAnalysis fiveMinutes;
  final TimeframeAnalysis fifteenMinutes;
  final TimeframeAnalysis oneHour;
  final List<ConfirmationItem> confirmations;
  final int longScore;
  final int shortScore;
  final String signal;
  final int strength;
  final double magnetPrice;
  final String magnetLabel;
  final double potentialPercent;
  final double expectedLow;
  final double expectedHigh;
  final TradePlan tradePlan;
  final DateTime updatedAt;
}
