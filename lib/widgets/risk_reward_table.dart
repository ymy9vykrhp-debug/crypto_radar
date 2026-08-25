import 'package:flutter/material.dart';

import '../models/signal_models.dart';

class RiskRewardTable extends StatelessWidget {
  const RiskRewardTable({super.key, required this.signal});

  final RadarSignal signal;

  @override
  Widget build(BuildContext context) {
    final List<RiskRewardEstimate> options = signal.riskRewardEstimates;
    final int recommended = signal.recommendedRiskReward.rewardMultiple;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Риск / прибыль',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'расчётное плечо до ${signal.leverage}×',
              style: const TextStyle(color: Colors.white60),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FlexColumnWidth(1.0),
            1: FlexColumnWidth(1.35),
            2: FlexColumnWidth(1.25),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.25),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: Colors.white12),
          ),
          children: <TableRow>[
            const TableRow(
              children: <Widget>[
                _TableCellText('R:R', header: true),
                _TableCellText('Цель', header: true),
                _TableCellText('Вероятность*', header: true),
                _TableCellText('EV', header: true),
                _TableCellText('Выбор', header: true),
              ],
            ),
            for (final RiskRewardEstimate option in options)
              TableRow(
                decoration: option.rewardMultiple == recommended
                    ? BoxDecoration(
                        color: const Color(0xFF62E6A7).withValues(alpha: 0.08),
                      )
                    : null,
                children: <Widget>[
                  _TableCellText(option.label),
                  _TableCellText(_price(option.targetPrice)),
                  _TableCellText(
                    '${option.probabilityPercent.toStringAsFixed(1)}%',
                  ),
                  _TableCellText(
                    '${option.expectedR >= 0.0 ? '+' : ''}'
                    '${option.expectedR.toStringAsFixed(2)}R',
                  ),
                  _TableCellText(
                    option.rewardMultiple == recommended
                        ? 'желательно'
                        : 'альтернатива',
                    highlighted: option.rewardMultiple == recommended,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          '* Оценка алгоритма по качеству текущего сигнала, не гарантия. '
          'Плечо увеличивает и прибыль, и убыток; предел — 10×.',
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText(
    this.text, {
    this.header = false,
    this.highlighted = false,
  });

  final String text;
  final bool header;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: highlighted
              ? const Color(0xFF62E6A7)
              : header
              ? Colors.white54
              : Colors.white,
          fontSize: header ? 11 : 12,
          fontWeight: header || highlighted ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }
}

String _price(double value) {
  if (value.abs() >= 1000.0) {
    return value.toStringAsFixed(2);
  }
  if (value.abs() >= 1.0) {
    return value.toStringAsFixed(4);
  }
  return value.toStringAsFixed(6);
}
