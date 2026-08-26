import 'package:crypto_radar/engines/chart_indicator_engine.dart';
import 'package:crypto_radar/models/chart_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/chart_view_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewport supports zoom, history pan, latest, fit and reset', () {
    final ChartViewportController controller = ChartViewportController();

    controller.setHistoryBars(500, 500);
    expect(controller.visibleCount(500), 500);

    controller.zoomIn(500);
    expect(controller.visibleCount(500), 400);

    controller.panPixels(100, 500, 500);
    expect(controller.rightOffset, greaterThan(0));
    expect(controller.isAtLatest, isFalse);

    controller.goToLatest();
    expect(controller.isAtLatest, isTrue);

    controller.zoomIn(500);
    controller.fitToScreen(500);
    expect(controller.zoom, 1);
    expect(controller.visibleCount(500), 500);

    controller.reset(500);
    expect(controller.historyBars, 100);
    expect(controller.visibleCount(500), 100);
  });

  test('WHY mode enables only reason-linked secondary layers', () {
    final ChartSettingsController settings = ChartSettingsController();
    expect(settings.layerEnabled(ChartLayer.fairValueGaps), isFalse);
    expect(settings.layerEnabled(ChartLayer.bos), isFalse);

    settings.toggleWhyMode();
    final Set<ChartLayer> effective = settings.effectiveLayers(<String>[
      'FVG_CONFLUENCE',
      'BOS_CONFIRMED',
      'LIQUIDITY_SWEEP',
    ]);

    expect(effective, contains(ChartLayer.fairValueGaps));
    expect(effective, contains(ChartLayer.bos));
    expect(effective, contains(ChartLayer.liquidity));
    expect(effective, contains(ChartLayer.liquiditySweep));
    expect(effective, isNot(contains(ChartLayer.orderBlocks)));
  });

  test('chart indicator calculation keeps candle alignment', () {
    final List<Candle> candles = List<Candle>.generate(240, (int index) {
      final double open = 100 + index * 0.1;
      final double close = open + (index.isEven ? 0.2 : -0.1);
      return Candle(
        time: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
        open: open,
        high: open + 0.5,
        low: open - 0.4,
        close: close,
        volume: 1000 + index.toDouble(),
      );
    });

    final ChartIndicatorData data = ChartIndicatorEngine.calculate(candles);

    expect(data.ema20.length, candles.length);
    expect(data.ema50.length, candles.length);
    expect(data.ema200.length, candles.length);
    expect(data.rsi.last, isNotNull);
    expect(data.macdHistogram.last, isNotNull);
    expect(data.atr.last, isNotNull);
    expect(data.vwap.last, isNotNull);
  });

  test('chart-only 4h timeframe maps to Bybit 240 minutes', () {
    expect(ChartTimeframe.fourHours.label, '4h');
    expect(ChartTimeframe.fourHours.bybitInterval, '240');
    expect(ChartTimeframe.fourHours.duration, const Duration(hours: 4));
  });
}
