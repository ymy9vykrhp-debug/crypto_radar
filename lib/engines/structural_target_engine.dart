import '../models/market_models.dart';
import '../models/signal_models.dart';

class StructuralTargetPlan {
  const StructuralTargetPlan({
    required this.tp1,
    required this.tp2,
    required this.tp1Label,
    required this.tp2Label,
    required this.valid,
  });

  final double tp1;
  final double tp2;
  final String tp1Label;
  final String tp2Label;
  final bool valid;
}

class StructuralObstacle {
  const StructuralObstacle({required this.price, required this.label});

  final double price;
  final String label;
}

/// Selects only levels already present in market structure.
///
/// No ATR or reward-multiple target is invented here. The nearest confirmed
/// level is TP1; if it is too close, the readiness gate waits for a better
/// entry instead of skipping it in favour of a prettier distant target.
class StructuralTargetEngine {
  const StructuralTargetEngine._();

  static StructuralTargetPlan build({
    required TimeframeAnalysis analysis,
    required SignalDirection direction,
    required double entryLow,
    required double entryHigh,
    double tickSize = 0.0,
  }) {
    final List<StructuralObstacle> candidates = levels(
      analysis: analysis,
      direction: direction,
      entryLow: entryLow,
      entryHigh: entryHigh,
      tickSize: tickSize,
    );
    if (candidates.isEmpty) {
      return const StructuralTargetPlan(
        tp1: 0.0,
        tp2: 0.0,
        tp1Label: 'STRUCTURAL_TARGET_MISSING',
        tp2Label: 'STRUCTURAL_TARGET_MISSING',
        valid: false,
      );
    }
    final StructuralObstacle first = candidates.first;
    final StructuralObstacle second = candidates.length > 1
        ? candidates[1]
        : first;
    return StructuralTargetPlan(
      tp1: first.price,
      tp2: second.price,
      tp1Label: first.label,
      tp2Label: second.label,
      valid: true,
    );
  }

  static List<StructuralObstacle> levels({
    required TimeframeAnalysis analysis,
    required SignalDirection direction,
    required double entryLow,
    required double entryHigh,
    double tickSize = 0.0,
  }) {
    final List<StructuralObstacle> result = <StructuralObstacle>[];
    final double boundary = direction == SignalDirection.long
        ? entryHigh
        : entryLow;
    void add(double? price, String label) {
      if (price == null || !price.isFinite || price <= 0.0) return;
      final bool inDirection = direction == SignalDirection.long
          ? price > boundary
          : price < boundary;
      if (!inDirection) return;
      final double tolerance = tickSize > 0.0
          ? tickSize * 2.0
          : _maxDouble(analysis.atr * 0.01, boundary.abs() * 0.000001);
      final int duplicate = result.indexWhere(
        (StructuralObstacle item) => (item.price - price).abs() <= tolerance,
      );
      if (duplicate < 0) {
        result.add(StructuralObstacle(price: price, label: label));
      }
    }

    add(analysis.resistance, 'Resistance');
    add(analysis.support, 'Support');
    add(analysis.structure.lastSwingHigh, 'Swing High');
    add(analysis.structure.lastSwingLow, 'Swing Low');
    add(analysis.liquidity.above, 'Liquidity Above');
    add(analysis.liquidity.below, 'Liquidity Below');
    add(analysis.fibonacci.nearestLevel, 'Fibonacci');
    for (final PriceZone zone in analysis.orderBlocks) {
      add(zone.lower, 'Order Block');
      add(zone.upper, 'Order Block');
    }
    for (final PriceZone zone in analysis.fairValueGaps) {
      add(zone.lower, 'FVG');
      add(zone.upper, 'FVG');
    }
    result.sort((StructuralObstacle first, StructuralObstacle second) {
      return direction == SignalDirection.long
          ? first.price.compareTo(second.price)
          : second.price.compareTo(first.price);
    });
    return List<StructuralObstacle>.unmodifiable(result);
  }

  static bool isConfirmedTarget({
    required TimeframeAnalysis analysis,
    required SignalDirection direction,
    required double entryLow,
    required double entryHigh,
    required double target,
    double tickSize = 0.0,
  }) {
    final double tolerance = _maxDouble(
      tickSize * 2.0,
      _maxDouble(analysis.atr * 0.05, target.abs() * 0.00001),
    );
    return levels(
      analysis: analysis,
      direction: direction,
      entryLow: entryLow,
      entryHigh: entryHigh,
      tickSize: tickSize,
    ).any(
      (StructuralObstacle level) => (level.price - target).abs() <= tolerance,
    );
  }

  static StructuralObstacle? obstacleBeforeTarget({
    required TimeframeAnalysis analysis,
    required SignalDirection direction,
    required double entryLow,
    required double entryHigh,
    required double target,
    double tickSize = 0.0,
  }) {
    final double boundary = direction == SignalDirection.long
        ? entryHigh
        : entryLow;
    final double tolerance = _maxDouble(
      tickSize * 2.0,
      _maxDouble(analysis.atr * 0.03, target.abs() * 0.00001),
    );
    for (final StructuralObstacle level in levels(
      analysis: analysis,
      direction: direction,
      entryLow: entryLow,
      entryHigh: entryHigh,
      tickSize: tickSize,
    )) {
      if ((level.price - target).abs() <= tolerance) continue;
      final bool before = direction == SignalDirection.long
          ? level.price > boundary && level.price < target - tolerance
          : level.price < boundary && level.price > target + tolerance;
      if (before) return level;
    }
    return null;
  }

  static double _maxDouble(double first, double second) =>
      first >= second ? first : second;
}
