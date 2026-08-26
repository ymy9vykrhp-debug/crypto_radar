import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/market_models.dart';
import '../models/signal_models.dart';

class MarketCandlestickChart extends StatelessWidget {
  const MarketCandlestickChart({
    super.key,
    required this.analysis,
    this.signal,
    this.visibleBars = 120,
  });

  final TimeframeAnalysis analysis;
  final RadarSignal? signal;
  final int visibleBars;

  @override
  Widget build(BuildContext context) {
    final List<Candle> candles = analysis.candles.length <= visibleBars
        ? analysis.candles
        : analysis.candles.sublist(analysis.candles.length - visibleBars);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MarketChartPainter(
          candles: candles,
          analysis: analysis,
          signal: signal,
          textDirection: Directionality.of(context),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _MarketChartPainter extends CustomPainter {
  _MarketChartPainter({
    required this.candles,
    required this.analysis,
    required this.signal,
    required this.textDirection,
  });

  static const Color _green = Color(0xFF45D69A);
  static const Color _red = Color(0xFFFF5C7C);
  static const Color _blue = Color(0xFF5B8CFF);
  static const Color _amber = Color(0xFFFFC857);

  final List<Candle> candles;
  final TimeframeAnalysis analysis;
  final RadarSignal? signal;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || size.width < 180 || size.height < 140) {
      return;
    }
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
    for (final double? value in <double?>[
      analysis.support,
      analysis.resistance,
      analysis.liquidity.above,
      analysis.liquidity.below,
      signal?.entryLow,
      signal?.entryHigh,
      signal?.stop,
      signal?.tp1,
      signal?.tp2,
    ]) {
      if (value != null && value > 0) {
        minimum = math.min(minimum, value);
        maximum = math.max(maximum, value);
      }
    }
    final double baseRange = math.max(maximum - minimum, maximum.abs() * 0.002);
    minimum -= baseRange * 0.08;
    maximum += baseRange * 0.08;
    final double priceRange = maximum - minimum;
    double y(double price) =>
        plot.bottom - (price - minimum) / priceRange * plot.height;

    _drawGrid(canvas, plot, minimum, maximum, y);
    _drawZones(canvas, plot, y);
    _drawTradePlan(canvas, plot, y);

    final double step = plot.width / candles.length;
    final double bodyWidth = math.max(1.0, math.min(8.0, step * 0.64));
    for (int index = 0; index < candles.length; index++) {
      final Candle candle = candles[index];
      final double x = plot.left + step * (index + 0.5);
      final Color color = candle.isBullish ? _green : _red;
      canvas.drawLine(
        Offset(x, y(candle.high)),
        Offset(x, y(candle.low)),
        Paint()
          ..color = color
          ..strokeWidth = 1,
      );
      final double openY = y(candle.open);
      final double closeY = y(candle.close);
      final Rect body = Rect.fromLTRB(
        x - bodyWidth / 2,
        math.min(openY, closeY),
        x + bodyWidth / 2,
        math.max(openY, closeY) + (openY == closeY ? 1 : 0),
      );
      canvas.drawRect(body, Paint()..color = color);
    }

    _drawEma(canvas, plot, y, 20, _blue, step);
    _drawEma(canvas, plot, y, 50, _amber, step);
    _drawTimeLabels(canvas, plot, step);
    _drawLastPrice(canvas, plot, candles.last.close, y);
  }

  void _drawGrid(
    Canvas canvas,
    Rect plot,
    double minimum,
    double maximum,
    double Function(double) y,
  ) {
    final Paint grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (int index = 0; index <= 5; index++) {
      final double ratio = index / 5;
      final double price = maximum - (maximum - minimum) * ratio;
      final double lineY = y(price);
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(plot.right, lineY),
        grid,
      );
      _text(
        canvas,
        _price(price),
        Offset(plot.right + 7, lineY - 7),
        Colors.white54,
        10,
      );
    }
  }

  void _drawZones(Canvas canvas, Rect plot, double Function(double) y) {
    final List<PriceZone> zones = <PriceZone>[
      ...analysis.fairValueGaps.take(4),
      ...analysis.orderBlocks.take(4),
    ];
    for (final PriceZone zone in zones) {
      final Color color = zone.bias == Bias.bullish ? _green : _red;
      final double top = y(zone.upper);
      final double bottom = y(zone.lower);
      final Rect rect = Rect.fromLTRB(
        plot.left,
        math.min(top, bottom),
        plot.right,
        math.max(top, bottom),
      );
      if (!rect.overlaps(plot)) continue;
      canvas.drawRect(
        rect.intersect(plot),
        Paint()..color = color.withValues(alpha: 0.055),
      );
    }
    _horizontalLevel(canvas, plot, analysis.support, y, _green, 'SUPPORT');
    _horizontalLevel(canvas, plot, analysis.resistance, y, _red, 'RESIST');
    _horizontalLevel(
      canvas,
      plot,
      analysis.liquidity.above,
      y,
      _amber,
      'LIQ ↑',
      dashed: true,
    );
    _horizontalLevel(
      canvas,
      plot,
      analysis.liquidity.below,
      y,
      _amber,
      'LIQ ↓',
      dashed: true,
    );
  }

  void _drawTradePlan(Canvas canvas, Rect plot, double Function(double) y) {
    final RadarSignal? current = signal;
    if (current == null) return;
    final Rect entry = Rect.fromLTRB(
      plot.left,
      math.min(y(current.entryHigh), y(current.entryLow)),
      plot.right,
      math.max(y(current.entryHigh), y(current.entryLow)),
    ).intersect(plot);
    canvas.drawRect(entry, Paint()..color = _blue.withValues(alpha: 0.16));
    _horizontalLevel(
      canvas,
      plot,
      current.entryPrice,
      y,
      _blue,
      'ENTRY',
      width: 2,
    );
    _horizontalLevel(canvas, plot, current.stop, y, _red, 'STOP', width: 2);
    _horizontalLevel(canvas, plot, current.tp1, y, _green, 'TP1', width: 2);
    _horizontalLevel(canvas, plot, current.tp2, y, _green, 'TP2', dashed: true);
  }

  void _horizontalLevel(
    Canvas canvas,
    Rect plot,
    double? price,
    double Function(double) y,
    Color color,
    String label, {
    bool dashed = false,
    double width = 1,
  }) {
    if (price == null || price <= 0) return;
    final double lineY = y(price);
    if (lineY < plot.top || lineY > plot.bottom) return;
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = width;
    if (dashed) {
      for (double x = plot.left; x < plot.right; x += 10) {
        canvas.drawLine(
          Offset(x, lineY),
          Offset(math.min(x + 5, plot.right), lineY),
          paint,
        );
      }
    } else {
      canvas.drawLine(
        Offset(plot.left, lineY),
        Offset(plot.right, lineY),
        paint,
      );
    }
    _text(
      canvas,
      '$label ${_price(price)}',
      Offset(plot.left + 4, lineY - 15),
      color,
      9,
    );
  }

  void _drawEma(
    Canvas canvas,
    Rect plot,
    double Function(double) y,
    int period,
    Color color,
    double step,
  ) {
    if (candles.isEmpty) return;
    final double multiplier = 2 / (period + 1);
    double ema = candles.first.close;
    final Path path = Path();
    for (int index = 0; index < candles.length; index++) {
      ema += (candles[index].close - ema) * multiplier;
      final double x = plot.left + step * (index + 0.5);
      final double pointY = y(ema);
      if (index == 0) {
        path.moveTo(x, pointY);
      } else {
        path.lineTo(x, pointY);
      }
    }
    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
    canvas.restore();
  }

  void _drawTimeLabels(Canvas canvas, Rect plot, double step) {
    for (final int index in <int>[0, candles.length ~/ 2, candles.length - 1]) {
      final DateTime time = candles[index].time.toLocal();
      final String label =
          '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
      final double x = plot.left + step * (index + 0.5);
      _text(canvas, label, Offset(x - 16, plot.bottom + 8), Colors.white38, 9);
    }
  }

  void _drawLastPrice(
    Canvas canvas,
    Rect plot,
    double price,
    double Function(double) y,
  ) {
    final double lineY = y(price);
    final Paint paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (double x = plot.left; x < plot.right; x += 6) {
      canvas.drawLine(
        Offset(x, lineY),
        Offset(math.min(x + 3, plot.right), lineY),
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
    final TextPainter painter = TextPainter(
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
    painter.paint(canvas, offset);
  }

  String _price(double value) {
    if (value >= 1000) return value.toStringAsFixed(1);
    if (value >= 1) return value.toStringAsFixed(3);
    return value.toStringAsFixed(6);
  }

  @override
  bool shouldRepaint(covariant _MarketChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.analysis != analysis ||
        oldDelegate.signal != signal;
  }
}
