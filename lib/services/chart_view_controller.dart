import 'package:flutter/foundation.dart';

import '../models/chart_models.dart';

class ChartViewportController extends ChangeNotifier {
  int _historyBars = 100;
  double _zoom = 1.0;
  double _rightOffset = 0.0;

  int get historyBars => _historyBars;
  double get zoom => _zoom;
  double get rightOffset => _rightOffset;
  bool get isAtLatest => _rightOffset < 0.5;

  int visibleCount(int total) {
    if (total <= 0) return 0;
    final int desired = (_historyBars / _zoom).round().clamp(20, _historyBars);
    return desired.clamp(1, total);
  }

  int endIndex(int total) {
    final int count = visibleCount(total);
    final int maximumOffset = total - count;
    final int offset = _rightOffset.round().clamp(0, maximumOffset);
    return total - offset;
  }

  int startIndex(int total) => endIndex(total) - visibleCount(total);

  List<T> visibleWindow<T>(List<T> source) {
    if (source.isEmpty) return <T>[];
    return source.sublist(startIndex(source.length), endIndex(source.length));
  }

  void setHistoryBars(int value, int total) {
    final int next = value.clamp(100, 500);
    if (_historyBars == next && _zoom == 1.0 && _rightOffset == 0.0) return;
    _historyBars = next;
    _zoom = 1.0;
    _rightOffset = 0.0;
    _clampOffset(total);
    notifyListeners();
  }

  void zoomIn(int total) => zoomBy(1.25, total);

  void zoomOut(int total) => zoomBy(0.80, total);

  void zoomBy(double factor, int total) {
    final double next = (_zoom * factor).clamp(1.0, 8.0);
    if ((next - _zoom).abs() < 0.0001) return;
    _zoom = next;
    _clampOffset(total);
    notifyListeners();
  }

  void panPixels(double deltaX, double plotWidth, int total) {
    if (plotWidth <= 0 || total <= 0) return;
    final double candlesPerPixel = visibleCount(total) / plotWidth;
    final double next = _rightOffset + deltaX * candlesPerPixel;
    final double maximum = (total - visibleCount(total)).toDouble();
    final double clamped = next.clamp(0.0, maximum);
    if ((clamped - _rightOffset).abs() < 0.01) return;
    _rightOffset = clamped;
    notifyListeners();
  }

  void goToLatest() {
    if (_rightOffset == 0.0) return;
    _rightOffset = 0.0;
    notifyListeners();
  }

  void fitToScreen(int total) {
    final bool changed = _zoom != 1.0 || _rightOffset != 0.0;
    _zoom = 1.0;
    _rightOffset = 0.0;
    _clampOffset(total);
    if (changed) notifyListeners();
  }

  void reset(int total) {
    final bool changed =
        _historyBars != 100 || _zoom != 1.0 || _rightOffset != 0.0;
    _historyBars = 100;
    _zoom = 1.0;
    _rightOffset = 0.0;
    _clampOffset(total);
    if (changed) notifyListeners();
  }

  void syncTotal(int total) {
    final double before = _rightOffset;
    _clampOffset(total);
    if ((before - _rightOffset).abs() > 0.01) notifyListeners();
  }

  void _clampOffset(int total) {
    final double maximum = (total - visibleCount(total))
        .clamp(0, total)
        .toDouble();
    _rightOffset = _rightOffset.clamp(0.0, maximum);
  }
}

class ChartSettingsController extends ChangeNotifier {
  final Set<ChartLayer> _layers = <ChartLayer>{
    ChartLayer.entry,
    ChartLayer.stop,
    ChartLayer.targets,
  };
  final Set<ChartIndicator> _indicators = <ChartIndicator>{
    ChartIndicator.ema20,
    ChartIndicator.ema50,
  };
  final Set<ChartIndicator> _collapsed = <ChartIndicator>{};
  bool _whyMode = false;

  Set<ChartLayer> get layers => Set<ChartLayer>.unmodifiable(_layers);
  Set<ChartIndicator> get indicators =>
      Set<ChartIndicator>.unmodifiable(_indicators);
  bool get whyMode => _whyMode;

  bool layerEnabled(ChartLayer layer) => _layers.contains(layer);
  bool indicatorEnabled(ChartIndicator indicator) =>
      _indicators.contains(indicator);
  bool indicatorCollapsed(ChartIndicator indicator) =>
      _collapsed.contains(indicator);

  void toggleLayer(ChartLayer layer) {
    _layers.contains(layer) ? _layers.remove(layer) : _layers.add(layer);
    notifyListeners();
  }

  void toggleIndicator(ChartIndicator indicator) {
    if (_indicators.contains(indicator)) {
      _indicators.remove(indicator);
      _collapsed.remove(indicator);
    } else {
      _indicators.add(indicator);
    }
    notifyListeners();
  }

  void toggleIndicatorCollapsed(ChartIndicator indicator) {
    _collapsed.contains(indicator)
        ? _collapsed.remove(indicator)
        : _collapsed.add(indicator);
    notifyListeners();
  }

  void toggleWhyMode() {
    _whyMode = !_whyMode;
    notifyListeners();
  }

  Set<ChartLayer> effectiveLayers(Iterable<String> reasonCodes) {
    final Set<ChartLayer> result = <ChartLayer>{..._layers};
    if (!_whyMode) return result;
    result.addAll(<ChartLayer>{
      ChartLayer.entry,
      ChartLayer.stop,
      ChartLayer.targets,
      ChartLayer.supportResistance,
      ChartLayer.priceMagnet,
      ChartLayer.expectedMove,
      ChartLayer.structure,
    });
    final Set<String> codes = reasonCodes.toSet();
    if (codes.any((String code) => code.contains('ORDER_BLOCK'))) {
      result.add(ChartLayer.orderBlocks);
    }
    if (codes.any((String code) => code.contains('FVG'))) {
      result.add(ChartLayer.fairValueGaps);
    }
    if (codes.any((String code) => code.contains('LIQUIDITY'))) {
      result.add(ChartLayer.liquidity);
    }
    if (codes.any((String code) => code.contains('SWEEP'))) {
      result.add(ChartLayer.liquiditySweep);
    }
    if (codes.any((String code) => code.contains('BOS'))) {
      result.add(ChartLayer.bos);
    }
    if (codes.any((String code) => code.contains('CHOCH'))) {
      result.add(ChartLayer.choch);
    }
    if (codes.any((String code) => code.contains('FALSE_BREAKOUT'))) {
      result.add(ChartLayer.falseBreakout);
    }
    return result;
  }
}
