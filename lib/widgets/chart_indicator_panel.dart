import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engines/chart_indicator_engine.dart';
import '../models/chart_models.dart';
import '../models/market_models.dart';
import '../services/chart_view_controller.dart';

class ChartIndicatorPanel extends StatefulWidget {
  const ChartIndicatorPanel({
    super.key,
    required this.indicator,
    required this.candles,
    required this.viewportController,
    required this.settingsController,
  });

  final ChartIndicator indicator;
  final List<Candle> candles;
  final ChartViewportController viewportController;
  final ChartSettingsController settingsController;

  @override
  State<ChartIndicatorPanel> createState() => _ChartIndicatorPanelState();
}

class _ChartIndicatorPanelState extends State<ChartIndicatorPanel> {
  late ChartIndicatorData _data;

  @override
  void initState() {
    super.initState();
    _data = ChartIndicatorEngine.calculate(widget.candles);
    widget.viewportController.addListener(_rebuild);
    widget.settingsController.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant ChartIndicatorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.candles != widget.candles) {
      _data = ChartIndicatorEngine.calculate(widget.candles);
    }
    if (oldWidget.viewportController != widget.viewportController) {
      oldWidget.viewportController.removeListener(_rebuild);
      widget.viewportController.addListener(_rebuild);
    }
    if (oldWidget.settingsController != widget.settingsController) {
      oldWidget.settingsController.removeListener(_rebuild);
      widget.settingsController.addListener(_rebuild);
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
    final bool collapsed = widget.settingsController.indicatorCollapsed(
      widget.indicator,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1523),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 30,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 10),
                Text(
                  widget.indicator.label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: collapsed ? 'Развернуть' : 'Свернуть',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.settingsController
                      .toggleIndicatorCollapsed(widget.indicator),
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.keyboard_arrow_up_rounded,
                    size: 17,
                  ),
                ),
                IconButton(
                  tooltip: 'Скрыть',
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => widget.settingsController.toggleIndicator(
                    widget.indicator,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 15),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
          if (!collapsed)
            SizedBox(
              height: 82,
              child: CustomPaint(
                painter: _IndicatorPainter(
                  indicator: widget.indicator,
                  candles: widget.candles,
                  data: _data,
                  start: widget.viewportController.startIndex(
                    widget.candles.length,
                  ),
                  end: widget.viewportController.endIndex(
                    widget.candles.length,
                  ),
                  textDirection: Directionality.of(context),
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }
}

class _IndicatorPainter extends CustomPainter {
  const _IndicatorPainter({
    required this.indicator,
    required this.candles,
    required this.data,
    required this.start,
    required this.end,
    required this.textDirection,
  });

  final ChartIndicator indicator;
  final List<Candle> candles;
  final ChartIndicatorData data;
  final int start;
  final int end;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (end <= start || size.width < 50 || size.height < 20) return;
    const double left = 12;
    const double right = 60;
    const double top = 3;
    const double bottom = 5;
    final Rect plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final double step = plot.width / (end - start);
    switch (indicator) {
      case ChartIndicator.volume:
        _drawVolume(canvas, plot, step);
        break;
      case ChartIndicator.rsi:
        _drawRsi(canvas, plot, step);
        break;
      case ChartIndicator.macd:
        _drawMacd(canvas, plot, step);
        break;
      case ChartIndicator.atr:
        _drawAtr(canvas, plot, step);
        break;
      case ChartIndicator.ema20:
      case ChartIndicator.ema50:
      case ChartIndicator.ema200:
      case ChartIndicator.vwap:
        break;
    }
  }

  void _drawVolume(Canvas canvas, Rect plot, double step) {
    double maximum = 0;
    for (int index = start; index < end; index++) {
      maximum = math.max(maximum, candles[index].volume);
    }
    if (maximum <= 0) return;
    for (int index = start; index < end; index++) {
      final Candle candle = candles[index];
      final double height = candle.volume / maximum * plot.height;
      final double x = plot.left + step * (index - start + 0.5);
      canvas.drawRect(
        Rect.fromLTWH(
          x - math.max(0.5, step * 0.28),
          plot.bottom - height,
          math.max(1, step * 0.56),
          height,
        ),
        Paint()
          ..color =
              (candle.isBullish
                      ? const Color(0xFF45D69A)
                      : const Color(0xFFFF5C7C))
                  .withValues(alpha: 0.65),
      );
    }
    _label(canvas, _compact(maximum), Offset(plot.right + 5, plot.top));
  }

  void _drawRsi(Canvas canvas, Rect plot, double step) {
    double y(double value) => plot.bottom - value / 100 * plot.height;
    _guide(canvas, plot, y(70), '70');
    _guide(canvas, plot, y(30), '30');
    _series(canvas, plot, step, data.rsi, y, const Color(0xFFA78BFA));
    final double? value = _last(data.rsi);
    if (value != null) {
      _label(
        canvas,
        value.toStringAsFixed(1),
        Offset(plot.right + 5, y(value) - 6),
      );
    }
  }

  void _drawMacd(Canvas canvas, Rect plot, double step) {
    final List<double> values = <double>[];
    for (int index = start; index < end; index++) {
      for (final double? value in <double?>[
        data.macd[index],
        data.macdSignal[index],
        data.macdHistogram[index],
      ]) {
        if (value != null) values.add(value);
      }
    }
    if (values.isEmpty) return;
    final double maximum = values.fold<double>(0, (double max, double value) {
      return math.max(max, value.abs());
    });
    final double safeMaximum = maximum == 0 ? 1 : maximum;
    double y(double value) =>
        plot.center.dy - value / safeMaximum * plot.height * 0.45;
    canvas.drawLine(
      Offset(plot.left, y(0)),
      Offset(plot.right, y(0)),
      Paint()..color = Colors.white12,
    );
    for (int index = start; index < end; index++) {
      final double value = data.macdHistogram[index] ?? 0;
      final double x = plot.left + step * (index - start + 0.5);
      canvas.drawRect(
        Rect.fromLTRB(
          x - math.max(0.5, step * 0.25),
          math.min(y(0), y(value)),
          x + math.max(0.5, step * 0.25),
          math.max(y(0), y(value)),
        ),
        Paint()
          ..color =
              (value >= 0 ? const Color(0xFF45D69A) : const Color(0xFFFF5C7C))
                  .withValues(alpha: 0.55),
      );
    }
    _series(canvas, plot, step, data.macd, y, const Color(0xFF5B8CFF));
    _series(canvas, plot, step, data.macdSignal, y, const Color(0xFFFFC857));
  }

  void _drawAtr(Canvas canvas, Rect plot, double step) {
    final List<double> values = <double>[];
    for (int index = start; index < end; index++) {
      final double? value = data.atr[index];
      if (value != null) values.add(value);
    }
    if (values.isEmpty) return;
    final double minimum = values.reduce(math.min);
    final double maximum = values.reduce(math.max);
    final double range = maximum == minimum ? 1 : maximum - minimum;
    double y(double value) =>
        plot.bottom - (value - minimum) / range * plot.height;
    _series(canvas, plot, step, data.atr, y, const Color(0xFF36CFC9));
    final double? value = _last(data.atr);
    if (value != null) {
      _label(canvas, _price(value), Offset(plot.right + 5, y(value) - 6));
    }
  }

  void _series(
    Canvas canvas,
    Rect plot,
    double step,
    List<double?> values,
    double Function(double) y,
    Color color,
  ) {
    final Path path = Path();
    bool started = false;
    for (int index = start; index < end; index++) {
      final double? value = values[index];
      if (value == null) continue;
      final double x = plot.left + step * (index - start + 0.5);
      if (!started) {
        path.moveTo(x, y(value));
        started = true;
      } else {
        path.lineTo(x, y(value));
      }
    }
    if (started) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _guide(Canvas canvas, Rect plot, double y, String label) {
    canvas.drawLine(
      Offset(plot.left, y),
      Offset(plot.right, y),
      Paint()..color = Colors.white12,
    );
    _label(canvas, label, Offset(plot.right + 5, y - 6));
  }

  double? _last(List<double?> values) {
    for (int index = end - 1; index >= start; index--) {
      if (values[index] != null) return values[index];
    }
    return null;
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: Colors.white38, fontSize: 8),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _compact(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  String _price(double value) {
    if (value >= 1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(6);
  }

  @override
  bool shouldRepaint(covariant _IndicatorPainter oldDelegate) => true;
}
