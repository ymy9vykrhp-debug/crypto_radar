import 'decision_models.dart';
import 'market_models.dart';
import 'signal_models.dart';

enum ChartTimeframe {
  oneMinute,
  fiveMinutes,
  fifteenMinutes,
  oneHour,
  fourHours,
}

extension ChartTimeframeText on ChartTimeframe {
  String get label {
    switch (this) {
      case ChartTimeframe.oneMinute:
        return '1m';
      case ChartTimeframe.fiveMinutes:
        return '5m';
      case ChartTimeframe.fifteenMinutes:
        return '15m';
      case ChartTimeframe.oneHour:
        return '1h';
      case ChartTimeframe.fourHours:
        return '4h';
    }
  }

  String get bybitInterval {
    switch (this) {
      case ChartTimeframe.oneMinute:
        return '1';
      case ChartTimeframe.fiveMinutes:
        return '5';
      case ChartTimeframe.fifteenMinutes:
        return '15';
      case ChartTimeframe.oneHour:
        return '60';
      case ChartTimeframe.fourHours:
        return '240';
    }
  }

  Duration get duration {
    switch (this) {
      case ChartTimeframe.oneMinute:
        return const Duration(minutes: 1);
      case ChartTimeframe.fiveMinutes:
        return const Duration(minutes: 5);
      case ChartTimeframe.fifteenMinutes:
        return const Duration(minutes: 15);
      case ChartTimeframe.oneHour:
        return const Duration(hours: 1);
      case ChartTimeframe.fourHours:
        return const Duration(hours: 4);
    }
  }
}

enum ChartLayer {
  entry,
  stop,
  targets,
  supportResistance,
  heavyLevels,
  liquidity,
  fairValueGaps,
  orderBlocks,
  structure,
  bos,
  choch,
  falseBreakout,
  liquiditySweep,
  priceMagnet,
  expectedMove,
}

extension ChartLayerText on ChartLayer {
  String get label {
    switch (this) {
      case ChartLayer.entry:
        return 'Entry';
      case ChartLayer.stop:
        return 'Stop';
      case ChartLayer.targets:
        return 'TP1 / TP2';
      case ChartLayer.supportResistance:
        return 'Support / Resistance';
      case ChartLayer.heavyLevels:
        return 'Heavy Levels';
      case ChartLayer.liquidity:
        return 'Liquidity';
      case ChartLayer.fairValueGaps:
        return 'FVG';
      case ChartLayer.orderBlocks:
        return 'Order Blocks';
      case ChartLayer.structure:
        return 'HH / HL / LH / LL';
      case ChartLayer.bos:
        return 'BOS';
      case ChartLayer.choch:
        return 'CHOCH';
      case ChartLayer.falseBreakout:
        return 'False Breakout';
      case ChartLayer.liquiditySweep:
        return 'Liquidity Sweep';
      case ChartLayer.priceMagnet:
        return 'Price Magnet';
      case ChartLayer.expectedMove:
        return 'Expected Move';
    }
  }
}

enum ChartIndicator { ema20, ema50, ema200, volume, rsi, macd, atr, vwap }

extension ChartIndicatorText on ChartIndicator {
  String get label {
    switch (this) {
      case ChartIndicator.ema20:
        return 'EMA20';
      case ChartIndicator.ema50:
        return 'EMA50';
      case ChartIndicator.ema200:
        return 'EMA200';
      case ChartIndicator.volume:
        return 'Volume';
      case ChartIndicator.rsi:
        return 'RSI';
      case ChartIndicator.macd:
        return 'MACD';
      case ChartIndicator.atr:
        return 'ATR';
      case ChartIndicator.vwap:
        return 'VWAP';
    }
  }

  bool get usesSubpanel =>
      this == ChartIndicator.volume ||
      this == ChartIndicator.rsi ||
      this == ChartIndicator.macd ||
      this == ChartIndicator.atr;
}

enum ChartHitKind { candle, level, entry, stop, target, signal, structure }

class ChartHit {
  const ChartHit({
    required this.kind,
    required this.title,
    required this.details,
    this.price,
    this.candle,
  });

  final ChartHitKind kind;
  final String title;
  final Map<String, String> details;
  final double? price;
  final Candle? candle;
}

class ChartLevel {
  const ChartLevel({
    required this.label,
    required this.lower,
    required this.upper,
    required this.bias,
    required this.detail,
    this.strength = 50,
  });

  final String label;
  final double lower;
  final double upper;
  final Bias bias;
  final String detail;
  final int strength;

  double get midpoint => (lower + upper) / 2;
}

class ChartStructureMarker {
  const ChartStructureMarker({
    required this.index,
    required this.price,
    required this.label,
    required this.bias,
  });

  final int index;
  final double price;
  final String label;
  final Bias bias;
}

class ChartVisualEvent {
  const ChartVisualEvent({
    required this.index,
    required this.price,
    required this.label,
    required this.bias,
    required this.detail,
  });

  final int index;
  final double price;
  final String label;
  final Bias bias;
  final String detail;
}

class ChartOverlayData {
  const ChartOverlayData({
    required this.symbol,
    required this.timeframe,
    required this.analysis,
    required this.signal,
    required this.decision,
    required this.heavyLevels,
    required this.structureMarkers,
    required this.events,
    required this.priceMagnet,
    required this.expectedLow,
    required this.expectedHigh,
  });

  final String symbol;
  final ChartTimeframe timeframe;
  final TimeframeAnalysis? analysis;
  final RadarSignal? signal;
  final DecisionSnapshot decision;
  final List<ChartLevel> heavyLevels;
  final List<ChartStructureMarker> structureMarkers;
  final List<ChartVisualEvent> events;
  final double priceMagnet;
  final double expectedLow;
  final double expectedHigh;
}
