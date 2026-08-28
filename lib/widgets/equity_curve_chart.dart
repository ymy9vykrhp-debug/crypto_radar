import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engines/journal_performance_engine.dart';
import '../localization/app_strings.dart';
import '../screens/journal/journal_ui_helpers.dart';

class EquityCurveChart extends StatefulWidget {
  const EquityCurveChart({super.key, required this.points});

  final List<EquityPoint> points;

  @override
  State<EquityCurveChart> createState() => _EquityCurveChartState();
}

class _EquityCurveChartState extends State<EquityCurveChart> {
  final TransformationController _transformation = TransformationController();
  EquityPoint? _selected;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.length < 2) {
      return Center(
        child: Text(
          context.strings.pick(
            'Добавьте закрытые сделки, чтобы построить Equity Curve.',
            'Add closed trades to build the Equity Curve.',
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              context.strings.pick(
                'Колесо / жест: масштаб · drag: перемещение',
                'Scroll / pinch: zoom · drag: pan',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Reset zoom',
              onPressed: () => _transformation.value = Matrix4.identity(),
              icon: const Icon(Icons.fit_screen_rounded),
            ),
          ],
        ),
        if (_selected != null)
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${journalDate(_selected!.time)} ${journalTime(_selected!.time)} · '
              '${journalMoney(_selected!.balance)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        const SizedBox(height: 6),
        Expanded(
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _transformation,
              minScale: 1,
              maxScale: 5,
              panEnabled: true,
              scaleEnabled: true,
              constrained: true,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (TapDownDetails details) {
                      final double width = math.max(constraints.maxWidth, 1);
                      final int index =
                          ((details.localPosition.dx / width) *
                                  (widget.points.length - 1))
                              .round()
                              .clamp(0, widget.points.length - 1);
                      setState(() => _selected = widget.points[index]);
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _EquityCurvePainter(
                        points: widget.points,
                        color: Theme.of(context).colorScheme.primary,
                        gridColor: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EquityCurvePainter extends CustomPainter {
  const _EquityCurvePainter({
    required this.points,
    required this.color,
    required this.gridColor,
  });

  final List<EquityPoint> points;
  final Color color;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = 12;
    const double top = 10;
    const double bottom = 18;
    final double width = math.max(size.width - left * 2, 1);
    final double height = math.max(size.height - top - bottom, 1);
    final double minimum = points
        .map<double>((EquityPoint point) => point.balance)
        .reduce(math.min);
    final double maximum = points
        .map<double>((EquityPoint point) => point.balance)
        .reduce(math.max);
    final double span = math.max(maximum - minimum, 0.01);
    final Paint grid = Paint()
      ..color = gridColor.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (int row = 0; row <= 4; row++) {
      final double y = top + height * row / 4;
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
    }
    final Path path = Path();
    for (int index = 0; index < points.length; index++) {
      final double x = left + width * index / (points.length - 1);
      final double normalized = (points[index].balance - minimum) / span;
      final double y = top + height * (1 - normalized);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_EquityCurvePainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.gridColor != gridColor;
}
