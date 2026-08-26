import '../models/chart_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';

class ChartOverlayEngine {
  const ChartOverlayEngine._();

  static ChartOverlayData build({
    required MarketSnapshot market,
    required ChartTimeframe timeframe,
    required List<Candle> candles,
    required TimeframeAnalysis? analysis,
    required RadarSignal? signal,
    required DecisionSnapshot decision,
  }) {
    return ChartOverlayData(
      symbol: market.symbol,
      timeframe: timeframe,
      analysis: analysis,
      signal: signal,
      decision: decision,
      heavyLevels: _heavyLevels(analysis, market.ticker.price),
      structureMarkers: _structureMarkers(candles),
      events: _events(candles, analysis, signal),
      priceMagnet: market.magnetPrice,
      expectedLow: market.expectedLow,
      expectedHigh: market.expectedHigh,
    );
  }

  static List<ChartLevel> _heavyLevels(
    TimeframeAnalysis? analysis,
    double price,
  ) {
    if (analysis == null) return const <ChartLevel>[];
    final List<ChartLevel> result = <ChartLevel>[];
    if (analysis.support != null) {
      result.add(
        ChartLevel(
          label: 'Heavy Support',
          lower: analysis.support!,
          upper: analysis.support!,
          bias: Bias.bullish,
          detail: 'Текущая поддержка из общего анализа таймфрейма.',
          strength: 70,
        ),
      );
    }
    if (analysis.resistance != null) {
      result.add(
        ChartLevel(
          label: 'Heavy Resistance',
          lower: analysis.resistance!,
          upper: analysis.resistance!,
          bias: Bias.bearish,
          detail: 'Текущее сопротивление из общего анализа таймфрейма.',
          strength: 70,
        ),
      );
    }
    for (final PriceZone zone in analysis.orderBlocks.take(3)) {
      result.add(
        ChartLevel(
          label: 'OB level',
          lower: zone.lower,
          upper: zone.upper,
          bias: zone.bias,
          detail: 'Order Block ${zone.timeframe}. Визуальный агрегат уровня.',
          strength: 65,
        ),
      );
    }
    for (final PriceZone zone in analysis.fairValueGaps.take(3)) {
      result.add(
        ChartLevel(
          label: 'FVG level',
          lower: zone.lower,
          upper: zone.upper,
          bias: zone.bias,
          detail:
              'Fair Value Gap ${zone.timeframe}. Визуальный агрегат уровня.',
          strength: 55,
        ),
      );
    }
    result.sort((ChartLevel first, ChartLevel second) {
      return (first.midpoint - price).abs().compareTo(
        (second.midpoint - price).abs(),
      );
    });
    return List<ChartLevel>.unmodifiable(result.take(6));
  }

  static List<ChartStructureMarker> _structureMarkers(List<Candle> candles) {
    final List<ChartStructureMarker> result = <ChartStructureMarker>[];
    double? previousHigh;
    double? previousLow;
    for (int index = 2; index < candles.length - 2; index++) {
      final Candle current = candles[index];
      final bool high =
          current.high > candles[index - 1].high &&
          current.high > candles[index - 2].high &&
          current.high >= candles[index + 1].high &&
          current.high >= candles[index + 2].high;
      final bool low =
          current.low < candles[index - 1].low &&
          current.low < candles[index - 2].low &&
          current.low <= candles[index + 1].low &&
          current.low <= candles[index + 2].low;
      if (high) {
        final String label = previousHigh == null || current.high > previousHigh
            ? 'HH'
            : 'LH';
        result.add(
          ChartStructureMarker(
            index: index,
            price: current.high,
            label: label,
            bias: label == 'HH' ? Bias.bullish : Bias.bearish,
          ),
        );
        previousHigh = current.high;
      }
      if (low) {
        final String label = previousLow == null || current.low > previousLow
            ? 'HL'
            : 'LL';
        result.add(
          ChartStructureMarker(
            index: index,
            price: current.low,
            label: label,
            bias: label == 'HL' ? Bias.bullish : Bias.bearish,
          ),
        );
        previousLow = current.low;
      }
    }
    final int start = result.length > 40 ? result.length - 40 : 0;
    return List<ChartStructureMarker>.unmodifiable(result.sublist(start));
  }

  static List<ChartVisualEvent> _events(
    List<Candle> candles,
    TimeframeAnalysis? analysis,
    RadarSignal? signal,
  ) {
    if (candles.isEmpty) return const <ChartVisualEvent>[];
    final List<ChartVisualEvent> events = <ChartVisualEvent>[];
    final int lastIndex = candles.length - 1;
    final Candle last = candles.last;
    final Bias trend = analysis?.trend ?? _visualTrend(candles);
    events.add(
      ChartVisualEvent(
        index: lastIndex,
        price: trend == Bias.bearish ? last.low : last.high,
        label: trend == Bias.bullish
            ? 'TREND ↑'
            : trend == Bias.bearish
            ? 'TREND ↓'
            : 'RANGE',
        bias: trend,
        detail: 'Текущий тренд выбранного графического таймфрейма.',
      ),
    );
    if (candles.length >= 3 && trend != Bias.neutral) {
      final Candle previous = candles[candles.length - 2];
      final Candle before = candles[candles.length - 3];
      final bool correction = trend == Bias.bullish
          ? last.close < previous.close
          : last.close > previous.close;
      final bool correctionEnded = trend == Bias.bullish
          ? previous.close < before.close && last.close > previous.high
          : previous.close > before.close && last.close < previous.low;
      final bool continuation = trend == Bias.bullish
          ? last.close > previous.high
          : last.close < previous.low;
      if (correction) {
        events.add(
          ChartVisualEvent(
            index: lastIndex,
            price: last.close,
            label: 'CORRECTION',
            bias: Bias.neutral,
            detail: 'Последняя свеча движется против текущего тренда.',
          ),
        );
      }
      if (correctionEnded) {
        events.add(
          ChartVisualEvent(
            index: lastIndex,
            price: last.close,
            label: 'CORRECTION END',
            bias: trend,
            detail:
                'Цена закрылась за экстремумом предыдущей коррекционной свечи.',
          ),
        );
      } else if (continuation) {
        events.add(
          ChartVisualEvent(
            index: lastIndex,
            price: last.close,
            label: 'CONTINUATION',
            bias: trend,
            detail: 'Закрытие продолжает импульс по направлению тренда.',
          ),
        );
      }
    }
    final StructureResult? structure = analysis?.structure;
    if (structure?.choch != null && structure!.choch != Bias.neutral) {
      events.add(
        ChartVisualEvent(
          index: lastIndex,
          price: last.close,
          label: 'POSSIBLE REVERSAL • CHOCH',
          bias: structure.choch,
          detail: 'Текущий анализ отметил смену характера структуры.',
        ),
      );
    }
    if (structure?.bos != null && structure!.bos != Bias.neutral) {
      events.add(
        ChartVisualEvent(
          index: lastIndex,
          price: last.close,
          label: 'CONFIRMED BOS',
          bias: structure.bos,
          detail: 'Текущий анализ отметил подтверждённый слом структуры.',
        ),
      );
    }
    if (signal != null && signal.falseBreakoutState.name != 'none') {
      events.add(
        ChartVisualEvent(
          index: lastIndex,
          price: signal.falseBreakoutLevel > 0
              ? signal.falseBreakoutLevel
              : last.close,
          label: signal.falseBreakoutState.code,
          bias: signal.direction.bias,
          detail: 'Состояние False Breakout из текущего сигнала.',
        ),
      );
    }
    return List<ChartVisualEvent>.unmodifiable(events);
  }

  static Bias _visualTrend(List<Candle> candles) {
    if (candles.length < 50) return Bias.neutral;
    final double fast = _averageClose(candles, 20);
    final double slow = _averageClose(candles, 50);
    if (fast > slow) return Bias.bullish;
    if (fast < slow) return Bias.bearish;
    return Bias.neutral;
  }

  static double _averageClose(List<Candle> candles, int count) {
    final int start = candles.length - count;
    double total = 0;
    for (int index = start; index < candles.length; index++) {
      total += candles[index].close;
    }
    return total / count;
  }
}
