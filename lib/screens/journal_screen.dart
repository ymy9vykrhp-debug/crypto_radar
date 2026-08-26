import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/backtest_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../widgets/product_components.dart';
import '../widgets/signal_table.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, required this.controller, this.symbol});

  final JournalController controller;
  final String? symbol;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<RadarSignal> signals = controller.signals
            .where(
              (RadarSignal signal) => symbol == null || signal.symbol == symbol,
            )
            .toList(growable: false);
        final JournalStatistics statistics = JournalStatistics.fromSignals(
          signals,
        );
        final double netR = signals.fold<double>(
          0,
          (double total, RadarSignal signal) => total + signal.resultR,
        );
        final double grossProfit = signals
            .where((RadarSignal signal) => signal.resultR > 0)
            .fold<double>(
              0,
              (double total, RadarSignal s) => total + s.resultR,
            );
        final double grossLoss = signals
            .where((RadarSignal signal) => signal.resultR < 0)
            .fold<double>(
              0,
              (double total, RadarSignal s) => total + s.resultR.abs(),
            );
        final double profitFactor = grossLoss == 0
            ? (grossProfit > 0 ? double.infinity : 0)
            : grossProfit / grossLoss;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Торговый журнал', 'Trading Journal'),
              subtitle: symbol == null
                  ? strings.localOnly
                  : '${symbol!} · ${strings.localOnly}',
              icon: Icons.menu_book_outlined,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 900 ? 5 : 2;
                final double width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _metric(
                      width,
                      strings.pick('Сегодня', 'Today'),
                      _todayCount(signals).toString(),
                      Icons.today_outlined,
                    ),
                    _metric(
                      width,
                      strings.pick('Сделки', 'Trades'),
                      statistics.trades.toString(),
                      Icons.swap_horiz_rounded,
                    ),
                    _metric(
                      width,
                      'Net R',
                      '${netR >= 0 ? '+' : ''}${netR.toStringAsFixed(2)}R',
                      Icons.show_chart_rounded,
                    ),
                    _metric(
                      width,
                      'Win Rate',
                      '${statistics.winRate.toStringAsFixed(1)}%',
                      Icons.percent_rounded,
                    ),
                    _metric(
                      width,
                      'Profit Factor',
                      profitFactor.isInfinite
                          ? '∞'
                          : profitFactor.toStringAsFixed(2),
                      Icons.balance_rounded,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SignalTable(
              signals: signals,
              symbol: symbol,
              mode: SignalTableMode.journal,
            ),
          ],
        );
      },
    );
  }

  Widget _metric(double width, String label, String value, IconData icon) {
    return SizedBox(
      width: width,
      height: 100,
      child: ProductMetricCard(label: label, value: value, icon: icon),
    );
  }
}

int _todayCount(List<RadarSignal> signals) {
  final DateTime now = DateTime.now();
  return signals.where((RadarSignal signal) {
    final DateTime local = signal.time.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }).length;
}
