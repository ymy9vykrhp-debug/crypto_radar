import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../engines/chart_indicator_engine.dart';
import '../models/chart_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/chart_view_controller.dart';

class MarketCandlestickChart extends StatefulWidget {
  const MarketCandlestickChart({
    super.key,
    required this.candles,
    required this.overlay,
    required this.viewportController,
    required this.settingsController,
    this.onHit,
  });

  final List<Candle> candles;
  final ChartOverlayData overlay;
  final ChartViewportController viewportController;
  final ChartSettingsController settingsController;
  final ValueChanged<ChartHit>? onHit;

  @override
  State<MarketCandlestickChart> createState() => _MarketCandlestickChartState();
}

class _MarketCandlestickChartState extends State<MarketCandlestickChart> {
  Offset? _crosshair;
  int? _lockedCandleIndex;
  Offset? _lastFocalPoint;
  double _lastScale = 1.0;
  late ChartIndicatorData _indicatorData;

  @override
  void initState() {
    super.initState();
    _indicatorData = ChartIndicatorEngine.calculate(widget.candles);
    widget.viewportController.addListener(_rebuild);
    widget.settingsController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant MarketCandlestickChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewportController != widget.viewportController) {
      oldWidget.viewportController.removeListener(_rebuild);
      widget.viewportController.addListener(_rebuild);
    }
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.removeListener(_rebuild);
      widget.settingsController.addListener(_rebuild);
    }
    if (oldWidget.candles != widget.candles) {
      _indicatorData = ChartIndicatorEngine.calculate(widget.candles);
      widget.viewportController.syncTotal(widget.candles.length);
      _crosshair = null;
      _lockedCandleIndex = null;
    }
  }

  @override
  void dispose() {
    widget.viewportController.removeListener(_rebuild);
    widget.settingsController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return const Center(child: Text('Нет свечей для отображения'));
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(constraints.maxWidth, constraints.maxHeight);
        final int start = widget.viewportController.startIndex(
          widget.candles.length,
        );
        final int end = widget.viewportController.endIndex(
          widget.candles.length,
        );
        final List<Candle> visible = widget.candles.sublist(start, end);
        final Set<ChartLayer> layers = widget.settingsController
            .effectiveLayers(_reasonCodes());
        final _ChartGeometry geometry = _ChartGeometry.calculate(
          size: size,
          candles: visible,
          visibleStart: start,
          overlay: widget.overlay,
          layers: layers,
        );
        final int? crosshairIndex = _selectedIndex(geometry);
        return Listener(
          onPointerSignal: (PointerSignalEvent event) {
            if (event is PointerScrollEvent) {
              widget.viewportController.zoomBy(
                event.scrollDelta.dy < 0 ? 1.18 : 0.84,
                widget.candles.length,
              );
            }
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.precise,
            onHover: (PointerHoverEvent event) {
              if (_lockedCandleIndex == null) {
                setState(() => _crosshair = event.localPosition);
              }
            },
            onExit: (_) {
              if (_lockedCandleIndex == null) {
                setState(() => _crosshair = null);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (ScaleStartDetails details) {
                _lastFocalPoint = details.localFocalPoint;
                _lastScale = 1.0;
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                final Offset previous =
                    _lastFocalPoint ?? details.localFocalPoint;
                final double deltaX = details.localFocalPoint.dx - previous.dx;
                if (deltaX.abs() > 0.1) {
                  widget.viewportController.panPixels(
                    deltaX,
                    geometry.plot.width,
                    widget.candles.length,
                  );
                }
                if ((details.scale - _lastScale).abs() > 0.015) {
                  widget.viewportController.zoomBy(
                    details.scale / _lastScale,
                    widget.candles.length,
                  );
                }
                _lastFocalPoint = details.localFocalPoint;
                _lastScale = details.scale;
              },
              onScaleEnd: (_) {
                _lastFocalPoint = null;
                _lastScale = 1.0;
              },
              onTapUp: (TapUpDetails details) {
                _handleTap(details.localPosition, geometry, layers);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: <Widget>[
                    RepaintBoundary(
                      child: CustomPaint(
                        painter: _MarketChartPainter(
                          allCandles: widget.candles,
                          visibleCandles: visible,
                          visibleStart: start,
                          overlay: widget.overlay,
                          layers: layers,
                          indicators: widget.settingsController.indicators,
                          indicatorData: _indicatorData,
                          geometry: geometry,
                          crosshairIndex: crosshairIndex,
                          crosshairY: _crosshair?.dy,
                          whyMode: widget.settingsController.whyMode,
                          textDirection: Directionality.of(context),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    if (crosshairIndex != null)
                      Positioned(
                        top: 8,
                        right: 98,
                        child: _CandleTooltip(
                          candle: widget.candles[crosshairIndex],
                          locked: _lockedCandleIndex != null,
                        ),
                      ),
                    if (!widget.viewportController.isAtLatest)
                      Positioned(
                        right: 102,
                        bottom: 34,
                        child: Material(
                          color: const Color(0xFF1A2638),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: widget.viewportController.goToLatest,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(Icons.skip_next_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text('К текущей свече'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<String> _reasonCodes() sync* {
    for (final ReasonCode reason in widget.overlay.decision.reasonCodes) {
      yield reason.code;
    }
    for (final ReasonCode warning in widget.overlay.decision.warningCodes) {
      yield warning.code;
    }
    yield* widget.overlay.signal?.reasonCodes ?? const <String>[];
  }

  int? _selectedIndex(_ChartGeometry geometry) {
    if (_lockedCandleIndex != null) return _lockedCandleIndex;
    final Offset? point = _crosshair;
    if (point == null || !geometry.plot.contains(point)) return null;
    return geometry.indexAt(point.dx);
  }

  void _handleTap(
    Offset point,
    _ChartGeometry geometry,
    Set<ChartLayer> layers,
  ) {
    if (!geometry.plot.contains(point)) return;
    final ChartHit? objectHit = _hitObject(point, geometry, layers);
    if (objectHit != null) {
      widget.onHit?.call(objectHit);
      return;
    }
    final int index = geometry.indexAt(point.dx);
    setState(() {
      _lockedCandleIndex = _lockedCandleIndex == index ? null : index;
      _crosshair = point;
    });
    final Candle candle = widget.candles[index];
    widget.onHit?.call(
      ChartHit(
        kind: ChartHitKind.candle,
        title: 'Свеча ${_dateTime(candle.time)}',
        candle: candle,
        details: _candleDetails(candle),
      ),
    );
  }

  ChartHit? _hitObject(
    Offset point,
    _ChartGeometry geometry,
    Set<ChartLayer> layers,
  ) {
    final List<_HitPrice> prices = <_HitPrice>[];
    final RadarSignal? signal = widget.overlay.signal;
    if (signal != null) {
      if (layers.contains(ChartLayer.entry)) {
        prices.add(
          _HitPrice(
            signal.entryPrice,
            ChartHit(
              kind: ChartHitKind.entry,
              title: 'Entry Zone',
              price: signal.entryPrice,
              details: <String, String>{
                'Диапазон':
                    '${_price(signal.entryLow)} — ${_price(signal.entryHigh)}',
                'Сторона': signal.direction.label,
                'Стадия': signal.stage.code,
                'Режим': signal.entryMode.label,
                'Действие': signal.executionAction,
              },
            ),
          ),
        );
      }
      if (layers.contains(ChartLayer.stop)) {
        prices.add(
          _HitPrice(
            signal.stop,
            ChartHit(
              kind: ChartHitKind.stop,
              title: 'Stop / Invalidation',
              price: signal.stop,
              details: <String, String>{
                'Stop': _price(signal.stop),
                'Invalidation': _price(signal.invalidationPrice),
                'Buffer': _price(signal.stopBuffer),
                'Buffer ATR': signal.stopBufferAtr.toStringAsFixed(2),
              },
            ),
          ),
        );
      }
      if (layers.contains(ChartLayer.targets)) {
        prices.addAll(<_HitPrice>[
          _HitPrice(
            signal.tp1,
            ChartHit(
              kind: ChartHitKind.target,
              title: 'Take Profit 1',
              price: signal.tp1,
              details: <String, String>{'TP1': _price(signal.tp1)},
            ),
          ),
          _HitPrice(
            signal.tp2,
            ChartHit(
              kind: ChartHitKind.target,
              title: 'Take Profit 2',
              price: signal.tp2,
              details: <String, String>{'TP2': _price(signal.tp2)},
            ),
          ),
        ]);
      }
    }
    final TimeframeAnalysis? analysis = widget.overlay.analysis;
    if (analysis != null && layers.contains(ChartLayer.supportResistance)) {
      if (analysis.support != null) {
        prices.add(
          _HitPrice(
            analysis.support!,
            ChartHit(
              kind: ChartHitKind.level,
              title: 'Support',
              price: analysis.support,
              details: <String, String>{
                'Цена': _price(analysis.support!),
                'Таймфрейм': widget.overlay.timeframe.label,
                'Источник': 'Текущий TimeframeAnalysis',
              },
            ),
          ),
        );
      }
      if (analysis.resistance != null) {
        prices.add(
          _HitPrice(
            analysis.resistance!,
            ChartHit(
              kind: ChartHitKind.level,
              title: 'Resistance',
              price: analysis.resistance,
              details: <String, String>{
                'Цена': _price(analysis.resistance!),
                'Таймфрейм': widget.overlay.timeframe.label,
                'Источник': 'Текущий TimeframeAnalysis',
              },
            ),
          ),
        );
      }
    }
    if (layers.contains(ChartLayer.heavyLevels)) {
      for (final ChartLevel level in widget.overlay.heavyLevels) {
        prices.add(
          _HitPrice(
            level.midpoint,
            ChartHit(
              kind: ChartHitKind.level,
              title: level.label,
              price: level.midpoint,
              details: <String, String>{
                'Зона': '${_price(level.lower)} — ${_price(level.upper)}',
                'Сила': '${level.strength}/100',
                'Описание': level.detail,
              },
            ),
          ),
        );
      }
    }
    _HitPrice? nearest;
    double nearestDistance = 11;
    for (final _HitPrice candidate in prices) {
      final double distance = (geometry.y(candidate.price) - point.dy).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = candidate;
      }
    }
    if (nearest != null) return nearest.hit;

    if (signal != null) {
      final int signalIndex = _nearestTimeIndex(widget.candles, signal.time);
      if (signalIndex >= geometry.visibleStart &&
          signalIndex < geometry.visibleEnd) {
        final double x = geometry.x(signalIndex);
        final double y = geometry.y(signal.referencePrice);
        if ((Offset(x, y) - point).distance <= 14) {
          return ChartHit(
            kind: ChartHitKind.signal,
            title: '${signal.direction.label} • ${signal.stage.code}',
            price: signal.referencePrice,
            details: <String, String>{
              'Score': signal.score.toString(),
              'Профиль': signal.executionProfileId,
              'Entry': _price(signal.entryPrice),
              'Stop': _price(signal.stop),
              'TP1': _price(signal.tp1),
              'TP2': _price(signal.tp2),
              'Действие': signal.executionAction,
            },
          );
        }
      }
    }
    return null;
  }
}

class _MarketChartPainter extends CustomPainter {
  _MarketChartPainter({
    required this.allCandles,
    required this.visibleCandles,
    required this.visibleStart,
    required this.overlay,
    required this.layers,
    required this.indicators,
    required this.indicatorData,
    required this.geometry,
    required this.crosshairIndex,
    required this.crosshairY,
    required this.whyMode,
    required this.textDirection,
  });

  static const Color _green = Color(0xFF45D69A);
  static const Color _red = Color(0xFFFF5C7C);
  static const Color _blue = Color(0xFF5B8CFF);
  static const Color _amber = Color(0xFFFFC857);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _cyan = Color(0xFF36CFC9);

  final List<Candle> allCandles;
  final List<Candle> visibleCandles;
  final int visibleStart;
  final ChartOverlayData overlay;
  final Set<ChartLayer> layers;
  final Set<ChartIndicator> indicators;
  final ChartIndicatorData indicatorData;
  final _ChartGeometry geometry;
  final int? crosshairIndex;
  final double? crosshairY;
  final bool whyMode;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (visibleCandles.isEmpty || geometry.plot.width <= 1) return;
    _drawGrid(canvas);
    _drawExpectedMove(canvas);
    _drawZones(canvas);
    _drawTradePlan(canvas);
    _drawCandles(canvas);
    _drawIndicatorOverlays(canvas);
    _drawStructure(canvas);
    _drawSignal(canvas);
    _drawLastPrice(canvas);
    _drawCrosshair(canvas);
    if (whyMode) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          geometry.plot.deflate(1),
          const Radius.circular(10),
        ),
        Paint()
          ..color = _amber.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      _text(
        canvas,
        'WHY MODE • реальные причины решения',
        Offset(geometry.plot.left + 8, geometry.plot.top + 7),
        _amber,
        10,
      );
    }
  }

  void _drawGrid(Canvas canvas) {
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int index = 0; index <= 5; index++) {
      final double ratio = index / 5;
      final double price = geometry.maximum - geometry.range * ratio;
      final double lineY = geometry.y(price);
      canvas.drawLine(
        Offset(geometry.plot.left, lineY),
        Offset(geometry.plot.right, lineY),
        grid,
      );
      _text(
        canvas,
        _price(price),
        Offset(geometry.plot.right + 7, lineY - 7),
        Colors.white54,
        10,
      );
    }
    final List<int> timeIndexes = <int>[
      visibleStart,
      visibleStart + visibleCandles.length ~/ 2,
      visibleStart + visibleCandles.length - 1,
    ];
    for (final int index in timeIndexes.toSet()) {
      final double x = geometry.x(index);
      canvas.drawLine(
        Offset(x, geometry.plot.top),
        Offset(x, geometry.plot.bottom),
        grid,
      );
      _text(
        canvas,
        _shortTime(allCandles[index].time),
        Offset(x - 20, geometry.plot.bottom + 8),
        Colors.white38,
        9,
      );
    }
  }

  void _drawExpectedMove(Canvas canvas) {
    if (layers.contains(ChartLayer.expectedMove)) {
      final Rect band = Rect.fromLTRB(
        geometry.plot.left,
        geometry.y(overlay.expectedHigh),
        geometry.plot.right,
        geometry.y(overlay.expectedLow),
      ).intersect(geometry.plot);
      canvas.drawRect(band, Paint()..color = _purple.withValues(alpha: 0.06));
      _text(
        canvas,
        'EXPECTED MOVE',
        Offset(geometry.plot.right - 92, band.top + 3),
        _purple,
        9,
      );
    }
    if (layers.contains(ChartLayer.priceMagnet)) {
      _horizontalLevel(
        canvas,
        overlay.priceMagnet,
        _purple,
        'MAGNET',
        dashed: true,
      );
    }
  }

  void _drawZones(Canvas canvas) {
    final TimeframeAnalysis? analysis = overlay.analysis;
    if (analysis != null) {
      if (layers.contains(ChartLayer.fairValueGaps)) {
        for (final PriceZone zone in analysis.fairValueGaps.take(8)) {
          _zone(canvas, zone.lower, zone.upper, zone.bias, 'FVG');
        }
      }
      if (layers.contains(ChartLayer.orderBlocks)) {
        for (final PriceZone zone in analysis.orderBlocks.take(8)) {
          _zone(canvas, zone.lower, zone.upper, zone.bias, 'OB');
        }
      }
      if (layers.contains(ChartLayer.supportResistance)) {
        _horizontalLevel(canvas, analysis.support, _green, 'SUPPORT');
        _horizontalLevel(canvas, analysis.resistance, _red, 'RESIST');
      }
      if (layers.contains(ChartLayer.liquidity)) {
        _horizontalLevel(
          canvas,
          analysis.liquidity.above,
          _amber,
          'LIQ ↑',
          dashed: true,
        );
        _horizontalLevel(
          canvas,
          analysis.liquidity.below,
          _amber,
          'LIQ ↓',
          dashed: true,
        );
      }
      if (layers.contains(ChartLayer.bos) &&
          analysis.structure.bos != Bias.neutral) {
        final double? level = analysis.structure.bos == Bias.bullish
            ? analysis.structure.lastSwingHigh
            : analysis.structure.lastSwingLow;
        _horizontalLevel(canvas, level, _green, 'BOS', dashed: true);
      }
      if (layers.contains(ChartLayer.choch) &&
          analysis.structure.choch != Bias.neutral) {
        final double? level = analysis.structure.choch == Bias.bullish
            ? analysis.structure.lastSwingHigh
            : analysis.structure.lastSwingLow;
        _horizontalLevel(canvas, level, _amber, 'CHOCH', dashed: true);
      }
      if (layers.contains(ChartLayer.liquiditySweep) &&
          (analysis.liquidity.sweepAbove || analysis.liquidity.sweepBelow)) {
        final Candle last = visibleCandles.last;
        final String label = analysis.liquidity.sweepBelow
            ? 'SWEEP BELOW'
            : 'SWEEP ABOVE';
        _eventLabel(
          canvas,
          visibleStart + visibleCandles.length - 1,
          analysis.liquidity.sweepBelow ? last.low : last.high,
          label,
          _amber,
        );
      }
    }
    if (layers.contains(ChartLayer.heavyLevels)) {
      for (final ChartLevel level in overlay.heavyLevels) {
        _zone(
          canvas,
          level.lower,
          level.upper,
          level.bias,
          'HEAVY ${level.strength}',
          alpha: 0.10,
        );
      }
    }
  }

  void _drawTradePlan(Canvas canvas) {
    final RadarSignal? signal = overlay.signal;
    if (signal == null) return;
    if (layers.contains(ChartLayer.entry)) {
      final Rect entry = Rect.fromLTRB(
        geometry.plot.left,
        math.min(geometry.y(signal.entryHigh), geometry.y(signal.entryLow)),
        geometry.plot.right,
        math.max(geometry.y(signal.entryHigh), geometry.y(signal.entryLow)),
      ).intersect(geometry.plot);
      canvas.drawRect(entry, Paint()..color = _blue.withValues(alpha: 0.15));
      _horizontalLevel(canvas, signal.entryPrice, _blue, 'ENTRY', width: 2);
    }
    if (layers.contains(ChartLayer.stop)) {
      _horizontalLevel(canvas, signal.stop, _red, 'STOP', width: 2);
    }
    if (layers.contains(ChartLayer.targets)) {
      _horizontalLevel(canvas, signal.tp1, _green, 'TP1', width: 2);
      _horizontalLevel(canvas, signal.tp2, _green, 'TP2', dashed: true);
    }
    if (layers.contains(ChartLayer.falseBreakout) &&
        signal.falseBreakoutState != FalseBreakoutState.none) {
      _horizontalLevel(
        canvas,
        signal.falseBreakoutLevel,
        _amber,
        signal.falseBreakoutState.code,
        dashed: true,
      );
    }
  }

  void _drawCandles(Canvas canvas) {
    final double bodyWidth = math.max(
      1.0,
      math.min(10.0, geometry.step * 0.64),
    );
    canvas.save();
    canvas.clipRect(geometry.plot);
    for (int local = 0; local < visibleCandles.length; local++) {
      final int index = visibleStart + local;
      final Candle candle = visibleCandles[local];
      final double x = geometry.x(index);
      final Color color = candle.isBullish ? _green : _red;
      canvas.drawLine(
        Offset(x, geometry.y(candle.high)),
        Offset(x, geometry.y(candle.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      );
      final double openY = geometry.y(candle.open);
      final double closeY = geometry.y(candle.close);
      canvas.drawRect(
        Rect.fromLTRB(
          x - bodyWidth / 2,
          math.min(openY, closeY),
          x + bodyWidth / 2,
          math.max(openY, closeY) + (openY == closeY ? 1 : 0),
        ),
        Paint()..color = color,
      );
    }
    canvas.restore();
  }

  void _drawIndicatorOverlays(Canvas canvas) {
    if (indicators.contains(ChartIndicator.ema20)) {
      _lineSeries(canvas, indicatorData.ema20, _blue, 1.3);
    }
    if (indicators.contains(ChartIndicator.ema50)) {
      _lineSeries(canvas, indicatorData.ema50, _amber, 1.3);
    }
    if (indicators.contains(ChartIndicator.ema200)) {
      _lineSeries(canvas, indicatorData.ema200, _purple, 1.5);
    }
    if (indicators.contains(ChartIndicator.vwap)) {
      _lineSeries(canvas, indicatorData.vwap, _cyan, 1.4);
    }
  }

  void _lineSeries(
    Canvas canvas,
    List<double?> values,
    Color color,
    double width,
  ) {
    final Path path = Path();
    bool started = false;
    for (int index = visibleStart; index < geometry.visibleEnd; index++) {
      final double? value = index < values.length ? values[index] : null;
      if (value == null) continue;
      final double x = geometry.x(index);
      final double y = geometry.y(value);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (!started) return;
    canvas.save();
    canvas.clipRect(geometry.plot);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.92)
        ..strokeWidth = width
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  void _drawStructure(Canvas canvas) {
    if (layers.contains(ChartLayer.structure)) {
      for (final ChartStructureMarker marker in overlay.structureMarkers) {
        if (marker.index < visibleStart ||
            marker.index >= geometry.visibleEnd) {
          continue;
        }
        _eventLabel(
          canvas,
          marker.index,
          marker.price,
          marker.label,
          marker.bias == Bias.bullish ? _green : _red,
          compact: true,
        );
      }
    }
    for (final ChartVisualEvent event in overlay.events) {
      final bool visible = switch (event.label) {
        'CONFIRMED BOS' => layers.contains(ChartLayer.bos),
        String value when value.contains('CHOCH') => layers.contains(
          ChartLayer.choch,
        ),
        String value when value.contains('FALSE_BREAKOUT') => layers.contains(
          ChartLayer.falseBreakout,
        ),
        _ => layers.contains(ChartLayer.structure),
      };
      if (!visible ||
          event.index < visibleStart ||
          event.index >= geometry.visibleEnd) {
        continue;
      }
      _eventLabel(
        canvas,
        event.index,
        event.price,
        event.label,
        event.bias == Bias.bullish
            ? _green
            : event.bias == Bias.bearish
            ? _red
            : _amber,
      );
    }
  }

  void _drawSignal(Canvas canvas) {
    final RadarSignal? signal = overlay.signal;
    if (signal == null) return;
    final int index = _nearestTimeIndex(allCandles, signal.time);
    if (index < visibleStart || index >= geometry.visibleEnd) return;
    final double x = geometry.x(index);
    final double y = geometry.y(signal.referencePrice);
    final Color color = signal.direction == SignalDirection.long
        ? _green
        : _red;
    final Path marker = Path();
    if (signal.direction == SignalDirection.long) {
      marker
        ..moveTo(x, y - 10)
        ..lineTo(x - 6, y)
        ..lineTo(x + 6, y)
        ..close();
    } else {
      marker
        ..moveTo(x, y + 10)
        ..lineTo(x - 6, y)
        ..lineTo(x + 6, y)
        ..close();
    }
    canvas.drawPath(marker, Paint()..color = color);
    _text(canvas, signal.direction.label, Offset(x + 8, y - 7), color, 9);
  }

  void _drawLastPrice(Canvas canvas) {
    final double price = visibleCandles.last.close;
    final double lineY = geometry.y(price);
    _dashedLine(canvas, lineY, Colors.white38, 3, 3);
  }

  void _drawCrosshair(Canvas canvas) {
    final int? index = crosshairIndex;
    if (index == null || index < visibleStart || index >= geometry.visibleEnd) {
      return;
    }
    final double x = geometry.x(index);
    final double y = (crosshairY ?? geometry.y(allCandles[index].close)).clamp(
      geometry.plot.top,
      geometry.plot.bottom,
    );
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    _dashedVertical(canvas, x, paint);
    _dashedLine(canvas, y, paint.color, 4, 4);
    final double price = geometry.priceAt(y);
    canvas.drawRect(
      Rect.fromLTWH(geometry.plot.right + 3, y - 9, 85, 18),
      Paint()..color = const Color(0xFF334155),
    );
    _text(
      canvas,
      _price(price),
      Offset(geometry.plot.right + 8, y - 7),
      Colors.white,
      10,
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 34, geometry.plot.bottom + 4, 68, 18),
      Paint()..color = const Color(0xFF334155),
    );
    _text(
      canvas,
      _shortTime(allCandles[index].time),
      Offset(x - 29, geometry.plot.bottom + 7),
      Colors.white,
      9,
    );
  }

  void _zone(
    Canvas canvas,
    double lower,
    double upper,
    Bias bias,
    String label, {
    double alpha = 0.065,
  }) {
    if (lower <= 0 || upper <= 0) return;
    final Color color = bias == Bias.bullish
        ? _green
        : bias == Bias.bearish
        ? _red
        : _amber;
    final Rect rect = Rect.fromLTRB(
      geometry.plot.left,
      math.min(geometry.y(upper), geometry.y(lower)),
      geometry.plot.right,
      math.max(geometry.y(upper), geometry.y(lower)),
    );
    if (!rect.overlaps(geometry.plot)) return;
    final Rect visible = rect.intersect(geometry.plot);
    canvas.drawRect(visible, Paint()..color = color.withValues(alpha: alpha));
    _text(
      canvas,
      label,
      Offset(geometry.plot.right - 72, visible.top + 2),
      color,
      8,
    );
  }

  void _horizontalLevel(
    Canvas canvas,
    double? price,
    Color color,
    String label, {
    bool dashed = false,
    double width = 1,
  }) {
    if (price == null || price <= 0) return;
    final double lineY = geometry.y(price);
    if (lineY < geometry.plot.top || lineY > geometry.plot.bottom) return;
    if (dashed) {
      _dashedLine(canvas, lineY, color.withValues(alpha: 0.88), 6, 5);
    } else {
      canvas.drawLine(
        Offset(geometry.plot.left, lineY),
        Offset(geometry.plot.right, lineY),
        Paint()
          ..color = color.withValues(alpha: 0.88)
          ..strokeWidth = width,
      );
    }
    _text(
      canvas,
      '$label ${_price(price)}',
      Offset(geometry.plot.left + 5, lineY - 14),
      color,
      8.5,
    );
  }

  void _eventLabel(
    Canvas canvas,
    int index,
    double price,
    String label,
    Color color, {
    bool compact = false,
  }) {
    final double x = geometry.x(index);
    final double y = geometry.y(price);
    final TextPainter painter = _textPainter(label, color, compact ? 8 : 9);
    final double left = (x - painter.width / 2).clamp(
      geometry.plot.left,
      geometry.plot.right - painter.width - 8,
    );
    final double top = (y - painter.height - 12).clamp(
      geometry.plot.top + 18,
      geometry.plot.bottom - painter.height,
    );
    final Rect background = Rect.fromLTWH(
      left - 4,
      top - 2,
      painter.width + 8,
      painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(background, const Radius.circular(4)),
      Paint()..color = const Color(0xFF0B1220).withValues(alpha: 0.88),
    );
    painter.paint(canvas, Offset(left, top));
  }

  void _dashedLine(
    Canvas canvas,
    double y,
    Color color,
    double dash,
    double gap,
  ) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (
      double x = geometry.plot.left;
      x < geometry.plot.right;
      x += dash + gap
    ) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dash, geometry.plot.right), y),
        paint,
      );
    }
  }

  void _dashedVertical(Canvas canvas, double x, Paint paint) {
    for (double y = geometry.plot.top; y < geometry.plot.bottom; y += 8) {
      canvas.drawLine(
        Offset(x, y),
        Offset(x, math.min(y + 4, geometry.plot.bottom)),
        paint,
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    Color color,
    double size,
  ) {
    _textPainter(value, color, size).paint(canvas, offset);
  }

  TextPainter _textPainter(String value, Color color, double size) {
    return TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: textDirection,
      maxLines: 1,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) => true;
}

class _ChartGeometry {
  const _ChartGeometry({
    required this.plot,
    required this.minimum,
    required this.maximum,
    required this.visibleStart,
    required this.visibleEnd,
    required this.step,
  });

  final Rect plot;
  final double minimum;
  final double maximum;
  final int visibleStart;
  final int visibleEnd;
  final double step;

  double get range => maximum - minimum;

  double y(double price) =>
      plot.bottom - (price - minimum) / range * plot.height;

  double x(int absoluteIndex) =>
      plot.left + step * (absoluteIndex - visibleStart + 0.5);

  double priceAt(double y) => minimum + (plot.bottom - y) / plot.height * range;

  int indexAt(double x) {
    final int local = ((x - plot.left) / step).floor().clamp(
      0,
      visibleEnd - visibleStart - 1,
    );
    return visibleStart + local;
  }

  static _ChartGeometry calculate({
    required Size size,
    required List<Candle> candles,
    required int visibleStart,
    required ChartOverlayData overlay,
    required Set<ChartLayer> layers,
  }) {
    const double left = 12;
    const double right = 92;
    const double top = 18;
    const double bottom = 30;
    final Rect plot = Rect.fromLTRB(
      left,
      top,
      math.max(left + 1, size.width - right),
      math.max(top + 1, size.height - bottom),
    );
    double minimum = candles.first.low;
    double maximum = candles.first.high;
    for (final Candle candle in candles) {
      minimum = math.min(minimum, candle.low);
      maximum = math.max(maximum, candle.high);
    }
    void include(double? price) {
      if (price == null || price <= 0) return;
      minimum = math.min(minimum, price);
      maximum = math.max(maximum, price);
    }

    final RadarSignal? signal = overlay.signal;
    if (signal != null) {
      if (layers.contains(ChartLayer.entry)) {
        include(signal.entryLow);
        include(signal.entryHigh);
      }
      if (layers.contains(ChartLayer.stop)) include(signal.stop);
      if (layers.contains(ChartLayer.targets)) {
        include(signal.tp1);
        include(signal.tp2);
      }
      if (layers.contains(ChartLayer.falseBreakout)) {
        include(signal.falseBreakoutLevel);
      }
    }
    final TimeframeAnalysis? analysis = overlay.analysis;
    if (analysis != null) {
      if (layers.contains(ChartLayer.supportResistance)) {
        include(analysis.support);
        include(analysis.resistance);
      }
      if (layers.contains(ChartLayer.liquidity)) {
        include(analysis.liquidity.above);
        include(analysis.liquidity.below);
      }
    }
    if (layers.contains(ChartLayer.priceMagnet)) include(overlay.priceMagnet);
    if (layers.contains(ChartLayer.expectedMove)) {
      include(overlay.expectedLow);
      include(overlay.expectedHigh);
    }
    final double baseRange = math.max(maximum - minimum, maximum.abs() * 0.002);
    minimum -= baseRange * 0.08;
    maximum += baseRange * 0.08;
    return _ChartGeometry(
      plot: plot,
      minimum: minimum,
      maximum: maximum,
      visibleStart: visibleStart,
      visibleEnd: visibleStart + candles.length,
      step: plot.width / candles.length,
    );
  }
}

class _CandleTooltip extends StatelessWidget {
  const _CandleTooltip({required this.candle, required this.locked});

  final Candle candle;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final double rangePercent = candle.open == 0
        ? 0
        : candle.range / candle.open * 100;
    final double bodyPercent = candle.open == 0
        ? 0
        : (candle.close - candle.open).abs() / candle.open * 100;
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xEE111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          '${locked ? '● ' : ''}${_dateTime(candle.time)}  '
          'O ${_price(candle.open)}  H ${_price(candle.high)}  '
          'L ${_price(candle.low)}  C ${_price(candle.close)}\n'
          'Volume ${_compactNumber(candle.volume)}  '
          'Range ${rangePercent.toStringAsFixed(3)}%  '
          'Body ${bodyPercent.toStringAsFixed(3)}%  '
          '${candle.isBullish ? 'BULLISH' : 'BEARISH'}',
          style: TextStyle(
            fontSize: 10,
            height: 1.45,
            color: candle.isBullish
                ? const Color(0xFF62E6A7)
                : const Color(0xFFFF6B86),
          ),
        ),
      ),
    );
  }
}

class _HitPrice {
  const _HitPrice(this.price, this.hit);

  final double price;
  final ChartHit hit;
}

Map<String, String> _candleDetails(Candle candle) {
  final double rangePercent = candle.open == 0
      ? 0
      : candle.range / candle.open * 100;
  final double bodyPercent = candle.open == 0
      ? 0
      : (candle.close - candle.open).abs() / candle.open * 100;
  return <String, String>{
    'Time': _dateTime(candle.time),
    'Open': _price(candle.open),
    'High': _price(candle.high),
    'Low': _price(candle.low),
    'Close': _price(candle.close),
    'Volume': _compactNumber(candle.volume),
    'Range': '${rangePercent.toStringAsFixed(3)}%',
    'Body': '${bodyPercent.toStringAsFixed(3)}%',
    'Direction': candle.isBullish ? 'BULLISH' : 'BEARISH',
  };
}

int _nearestTimeIndex(List<Candle> candles, DateTime time) {
  int best = 0;
  int distance = (candles.first.time.difference(time).inMilliseconds).abs();
  for (int index = 1; index < candles.length; index++) {
    final int next = (candles[index].time.difference(time).inMilliseconds)
        .abs();
    if (next < distance) {
      distance = next;
      best = index;
    }
  }
  return best;
}

String _shortTime(DateTime source) {
  final DateTime time = source.toLocal();
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String _dateTime(DateTime source) {
  final DateTime time = source.toLocal();
  return '${time.day.toString().padLeft(2, '0')}.'
      '${time.month.toString().padLeft(2, '0')} '
      '${_shortTime(time)}';
}

String _price(double value) {
  if (value >= 1000) return value.toStringAsFixed(1);
  if (value >= 1) return value.toStringAsFixed(3);
  return value.toStringAsFixed(6);
}

String _compactNumber(double value) {
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}
