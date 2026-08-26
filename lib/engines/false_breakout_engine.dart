import '../models/execution_models.dart';
import '../models/market_models.dart';

class FalseBreakoutEngine {
  const FalseBreakoutEngine._();

  static FalseBreakoutAnalysis analyze({
    required TimeframeAnalysis analysis,
    required Bias scenarioDirection,
  }) {
    if (scenarioDirection == Bias.neutral || analysis.candles.length < 3) {
      return FalseBreakoutAnalysis.none;
    }
    final List<(double, String)> levels = _candidateLevels(
      analysis,
      scenarioDirection,
    );
    FalseBreakoutAnalysis best = FalseBreakoutAnalysis.none;
    for (final (double, String) candidate in levels) {
      final FalseBreakoutAnalysis result = _analyzeLevel(
        analysis: analysis,
        direction: scenarioDirection,
        level: candidate.$1,
        label: candidate.$2,
      );
      if (_rank(result.state) > _rank(best.state) ||
          (_rank(result.state) == _rank(best.state) &&
              result.score > best.score)) {
        best = result;
      }
    }
    return best;
  }

  static FalseBreakoutAnalysis _analyzeLevel({
    required TimeframeAnalysis analysis,
    required Bias direction,
    required double level,
    required String label,
  }) {
    final List<Candle> candles = analysis.candles;
    final int start = candles.length > 12 ? candles.length - 12 : 0;
    int pierceIndex = -1;
    for (int index = candles.length - 1; index >= start; index--) {
      final Candle candle = candles[index];
      final bool pierced = direction == Bias.bearish
          ? candle.high > level
          : candle.low < level;
      if (pierced) {
        pierceIndex = index;
        break;
      }
    }
    if (pierceIndex < 0) {
      return FalseBreakoutAnalysis.none;
    }

    final Candle pierce = candles[pierceIndex];
    final bool bearishScenario = direction == Bias.bearish;
    final bool closedBackInside = bearishScenario
        ? pierce.close < level
        : pierce.close > level;
    final Candle latest = candles.last;
    final bool reclaimed = bearishScenario
        ? latest.close < level
        : latest.close > level;
    final double body = (pierce.close - pierce.open).abs();
    final double rejectionWickSize = bearishScenario
        ? pierce.high - _maxDouble(pierce.open, pierce.close)
        : _minDouble(pierce.open, pierce.close) - pierce.low;
    final bool rejectionWick =
        rejectionWickSize >= pierce.range * 0.30 &&
        rejectionWickSize >= body * 0.65;
    final double averageVolume = _averagePreviousVolume(candles, pierceIndex);
    final bool volumeConfirmed =
        (averageVolume > 0.0 && pierce.volume >= averageVolume * 1.10) ||
        analysis.relativeVolume >= 1.20;
    final bool hasFollowingCandle = pierceIndex < candles.length - 1;
    final bool followThrough =
        hasFollowingCandle &&
        candles.sublist(pierceIndex + 1).any((Candle candle) {
          if (bearishScenario) {
            return candle.isBearish &&
                candle.close < level - analysis.atr * 0.03;
          }
          return candle.isBullish && candle.close > level + analysis.atr * 0.03;
        });
    final bool structureConfirmed =
        analysis.structure.bos == direction ||
        analysis.structure.choch == direction ||
        followThrough;

    double extreme = bearishScenario ? pierce.high : pierce.low;
    for (int index = pierceIndex + 1; index < candles.length; index++) {
      extreme = bearishScenario
          ? _maxDouble(extreme, candles[index].high)
          : _minDouble(extreme, candles[index].low);
    }
    final double overshoot = bearishScenario
        ? _maxDouble(0.0, extreme - level)
        : _maxDouble(0.0, level - extreme);
    final double overshootPercent = level == 0.0
        ? 0.0
        : overshoot / level * 100.0;
    final double overshootAtr = analysis.atr == 0.0
        ? 0.0
        : overshoot / analysis.atr;

    final bool confirmed =
        hasFollowingCandle &&
        closedBackInside &&
        reclaimed &&
        rejectionWick &&
        structureConfirmed;
    final FalseBreakoutState state = confirmed
        ? FalseBreakoutState.confirmed
        : FalseBreakoutState.possible;
    int score = 20;
    if (closedBackInside) score += 20;
    if (reclaimed && hasFollowingCandle) score += 15;
    if (rejectionWick) score += 15;
    if (volumeConfirmed) score += 10;
    if (structureConfirmed) score += 20;

    return FalseBreakoutAnalysis(
      state: state,
      level: level,
      levelLabel: label,
      direction: direction,
      score: _clampInt(score, 0, 100),
      pierced: true,
      closedBackInside: closedBackInside,
      reclaimed: reclaimed && hasFollowingCandle,
      rejectionWick: rejectionWick,
      volumeConfirmed: volumeConfirmed,
      structureConfirmed: structureConfirmed,
      liquiditySweepConfirmed: confirmed,
      overshoot: overshoot,
      overshootPercent: overshootPercent,
      overshootAtr: overshootAtr,
      eventTime: pierce.time,
    );
  }

  static List<(double, String)> _candidateLevels(
    TimeframeAnalysis analysis,
    Bias direction,
  ) {
    final List<(double, String)> result = <(double, String)>[];
    if (direction == Bias.bearish) {
      _addLevel(result, analysis.resistance, 'Resistance');
      _addLevel(result, analysis.liquidity.above, 'Liquidity Above');
      _addLevel(result, analysis.structure.lastSwingHigh, 'Swing High');
    } else {
      _addLevel(result, analysis.support, 'Support');
      _addLevel(result, analysis.liquidity.below, 'Liquidity Below');
      _addLevel(result, analysis.structure.lastSwingLow, 'Swing Low');
    }
    return result;
  }

  static void _addLevel(
    List<(double, String)> target,
    double? level,
    String label,
  ) {
    if (level == null || level <= 0.0) {
      return;
    }
    final bool duplicate = target.any(
      ((double, String) item) =>
          (item.$1 - level).abs() <= level.abs() * 0.00001,
    );
    if (!duplicate) {
      target.add((level, label));
    }
  }

  static double _averagePreviousVolume(List<Candle> candles, int pierceIndex) {
    final int start = pierceIndex > 20 ? pierceIndex - 20 : 0;
    if (pierceIndex <= start) {
      return 0.0;
    }
    double total = 0.0;
    for (int index = start; index < pierceIndex; index++) {
      total += candles[index].volume;
    }
    return total / (pierceIndex - start);
  }

  static int _rank(FalseBreakoutState state) {
    switch (state) {
      case FalseBreakoutState.none:
        return 0;
      case FalseBreakoutState.possible:
        return 1;
      case FalseBreakoutState.confirmed:
        return 2;
    }
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
  }

  static double _maxDouble(double first, double second) =>
      first >= second ? first : second;

  static double _minDouble(double first, double second) =>
      first <= second ? first : second;
}
