import 'dart:math' as math;

import '../models/market_models.dart';

enum AdaptiveGridMode { neutral, long, short, off }

enum AdaptiveGridState { ready, wait, danger, off }

extension AdaptiveGridModeText on AdaptiveGridMode {
  String get label => switch (this) {
    AdaptiveGridMode.neutral => 'NEUTRAL',
    AdaptiveGridMode.long => 'LONG',
    AdaptiveGridMode.short => 'SHORT',
    AdaptiveGridMode.off => 'OFF',
  };
}

extension AdaptiveGridStateText on AdaptiveGridState {
  String get label => switch (this) {
    AdaptiveGridState.ready => 'GRID READY',
    AdaptiveGridState.wait => 'GRID WAIT',
    AdaptiveGridState.danger => 'GRID DANGER',
    AdaptiveGridState.off => 'GRID OFF',
  };
}

/// Analysis-only futures-grid assessment.
///
/// Scores are deterministic heuristics, not profit probabilities. This engine
/// never places orders and deliberately refuses to invent a range when the
/// current structure does not expose usable boundaries.
class AdaptiveGridAssessment {
  const AdaptiveGridAssessment({
    required this.state,
    required this.mode,
    required this.rangeLow,
    required this.rangeHigh,
    required this.pricePositionPercent,
    required this.rangeQuality,
    required this.breakoutRisk,
    required this.stepPercent,
    required this.levels,
    required this.recommendedLeverage,
    required this.reasons,
  });

  final AdaptiveGridState state;
  final AdaptiveGridMode mode;
  final double rangeLow;
  final double rangeHigh;
  final double pricePositionPercent;
  final int rangeQuality;
  final int breakoutRisk;
  final double stepPercent;
  final int levels;
  final int recommendedLeverage;
  final List<String> reasons;

  bool get hasRange => rangeLow > 0 && rangeHigh > rangeLow;
  double get rangeWidthPercent =>
      !hasRange ? 0 : (rangeHigh - rangeLow) / rangeLow * 100;
}

class AdaptiveGridEngine {
  const AdaptiveGridEngine._();

  static AdaptiveGridAssessment evaluate({
    required MarketSnapshot market,
    int maximumLeverage = 10,
  }) {
    final double price = market.ticker.price;
    final TimeframeAnalysis fast = market.fifteenMinutes;
    final TimeframeAnalysis slow = market.oneHour;
    final List<double> below = <double>[];
    final List<double> above = <double>[];

    void collect(TimeframeAnalysis frame) {
      for (final double? level in <double?>[
        frame.support,
        frame.liquidity.below,
        frame.structure.lastSwingLow,
      ]) {
        if (level != null && level.isFinite && level > 0 && level < price) {
          below.add(level);
        }
      }
      for (final double? level in <double?>[
        frame.resistance,
        frame.liquidity.above,
        frame.structure.lastSwingHigh,
      ]) {
        if (level != null && level.isFinite && level > price) {
          above.add(level);
        }
      }
    }

    collect(fast);
    collect(slow);
    final double rangeLow = below.isEmpty ? 0 : below.reduce(math.max);
    final double rangeHigh = above.isEmpty ? 0 : above.reduce(math.min);
    final bool hasRange =
        price > 0 && rangeLow > 0 && rangeHigh > rangeLow && price < rangeHigh;

    if (!hasRange || market.dataIntegrity.hasCriticalIssue) {
      return AdaptiveGridAssessment(
        state: AdaptiveGridState.off,
        mode: AdaptiveGridMode.off,
        rangeLow: rangeLow,
        rangeHigh: rangeHigh,
        pricePositionPercent: 0,
        rangeQuality: 0,
        breakoutRisk: 100,
        stepPercent: 0,
        levels: 0,
        recommendedLeverage: 1,
        reasons: <String>[
          if (market.dataIntegrity.hasCriticalIssue)
            'Критическая проблема качества рыночных данных',
          if (!hasRange)
            'Нет подтверждённых структурных границ вокруг текущей цены',
        ],
      );
    }

    final double width = rangeHigh - rangeLow;
    final double widthPercent = width / price * 100;
    final double position = ((price - rangeLow) / width * 100).clamp(0, 100).toDouble();
    final double atrPercent = fast.atr > 0 ? fast.atr / price * 100 : 0;

    final AdaptiveGridMode mode = _mode(fast, slow);
    int quality = 20; // A real structural range exists.
    final List<String> reasons = <String>[];

    if (widthPercent >= 2 && widthPercent <= 14) {
      quality += 20;
      reasons.add('Диапазон достаточно широкий для сетки');
    } else if (widthPercent >= 1.2 && widthPercent <= 20) {
      quality += 10;
      reasons.add('Диапазон рабочий, но не оптимальный по ширине');
    } else {
      reasons.add('Ширина диапазона неудобна для сетки');
    }

    if (atrPercent > 0 && atrPercent <= widthPercent / 3) {
      quality += 15;
      reasons.add('Волатильность помещается внутри структурного диапазона');
    } else if (atrPercent > 0 && atrPercent <= widthPercent / 2) {
      quality += 8;
    }

    final bool middle = position >= 22 && position <= 78;
    if (middle) {
      quality += mode == AdaptiveGridMode.neutral ? 20 : 12;
    } else {
      reasons.add('Цена близко к границе диапазона');
    }

    if (fast.relativeVolume >= 0.65 && fast.relativeVolume <= 1.65) {
      quality += 10;
    }
    if (fast.trend == slow.trend ||
        fast.trend == Bias.neutral ||
        slow.trend == Bias.neutral) {
      quality += 10;
    }
    if (market.ticker.hasMicrostructure && market.ticker.spreadPercent <= 0.20) {
      quality += 5;
    }
    quality = quality.clamp(0, 100).toInt();

    int breakoutRisk = 0;
    if (position >= 88 || position <= 12) breakoutRisk += 25;
    if (fast.structure.bos != Bias.neutral) breakoutRisk += 20;
    if (fast.structure.choch != Bias.neutral) breakoutRisk += 15;
    if (slow.structure.bos != Bias.neutral && slow.structure.bos == fast.structure.bos) {
      breakoutRisk += 15;
    }
    if (fast.relativeVolume >= 1.8) breakoutRisk += 15;
    if (atrPercent >= widthPercent / 2) breakoutRisk += 15;
    if (fast.trend != Bias.neutral &&
        slow.trend == fast.trend &&
        mode != AdaptiveGridMode.neutral) {
      breakoutRisk += 5;
    }
    breakoutRisk = breakoutRisk.clamp(0, 100).toInt();

    final AdaptiveGridState state;
    if (breakoutRisk >= 70) {
      state = AdaptiveGridState.danger;
      reasons.add('Высокий риск выхода из диапазона — новые наращивания не нужны');
    } else if (quality >= 70 && breakoutRisk < 45) {
      state = AdaptiveGridState.ready;
      reasons.add('Диапазон подходит для анализа Grid');
    } else {
      state = AdaptiveGridState.wait;
      reasons.add('Ждать более чистого диапазона или снижения breakout risk');
    }

    final double rawStep = atrPercent > 0 ? atrPercent * 0.8 : widthPercent / 10;
    final double stepPercent = rawStep.clamp(0.35, 2.50).toDouble();
    final int levels = (widthPercent / stepPercent)
        .round()
        .clamp(4, 24)
        .toInt();
    final int cap = maximumLeverage.clamp(1, 10).toInt();
    final int recommendedLeverage = _recommendedLeverage(
      quality: quality,
      breakoutRisk: breakoutRisk,
      cap: cap,
    );

    return AdaptiveGridAssessment(
      state: state,
      mode: state == AdaptiveGridState.off ? AdaptiveGridMode.off : mode,
      rangeLow: rangeLow,
      rangeHigh: rangeHigh,
      pricePositionPercent: position,
      rangeQuality: quality,
      breakoutRisk: breakoutRisk,
      stepPercent: stepPercent,
      levels: levels,
      recommendedLeverage: recommendedLeverage,
      reasons: List<String>.unmodifiable(reasons),
    );
  }

  static AdaptiveGridMode _mode(
    TimeframeAnalysis fast,
    TimeframeAnalysis slow,
  ) {
    if (fast.trend == Bias.bullish && slow.trend == Bias.bullish) {
      return AdaptiveGridMode.long;
    }
    if (fast.trend == Bias.bearish && slow.trend == Bias.bearish) {
      return AdaptiveGridMode.short;
    }
    return AdaptiveGridMode.neutral;
  }

  static int _recommendedLeverage({
    required int quality,
    required int breakoutRisk,
    required int cap,
  }) {
    final int recommendation;
    if (breakoutRisk >= 70) {
      recommendation = 1;
    } else if (quality >= 88 && breakoutRisk <= 25) {
      recommendation = 5;
    } else if (quality >= 75 && breakoutRisk <= 40) {
      recommendation = 3;
    } else {
      recommendation = 2;
    }
    return math.min(recommendation, cap);
  }
}
