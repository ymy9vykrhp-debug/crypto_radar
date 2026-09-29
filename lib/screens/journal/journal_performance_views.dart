import 'package:flutter/material.dart';

import '../../engines/journal_performance_engine.dart';
import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_components.dart';
import 'journal_ui_helpers.dart';

class JournalPerformanceView extends StatelessWidget {
  const JournalPerformanceView({
    super.key,
    required this.trades,
    required this.performance,
  });

  final List<TradeJournalEntry> trades;
  final PerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<JournalGroupPerformance> assets =
        JournalPerformanceEngine.byAsset(trades);
    final List<JournalGroupPerformance> sides = JournalPerformanceEngine.bySide(
      trades,
    );
    final List<JournalGroupPerformance> sources =
        JournalPerformanceEngine.bySource(trades);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Эффективность', 'Performance'),
          subtitle: strings.pick(
            'Только фактически закрытые Journal records — без Backtest',
            'Closed Journal records only — Backtest is not mixed in',
          ),
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 14),
        JournalMetricGrid(
          items: <JournalMetricItem>[
            JournalMetricItem(label: 'WINS', value: '${performance.wins}'),
            JournalMetricItem(label: 'LOSSES', value: '${performance.losses}'),
            JournalMetricItem(
              label: 'BREAK EVEN',
              value: '${performance.breakEven}',
            ),
            JournalMetricItem(
              label: 'AVERAGE R',
              value: journalR(performance.averageR),
            ),
            JournalMetricItem(
              label: 'AVERAGE WIN',
              value: journalMoney(performance.averageWin, signed: true),
            ),
            JournalMetricItem(
              label: 'AVERAGE LOSS',
              value: journalMoney(performance.averageLoss, signed: true),
            ),
            JournalMetricItem(
              label: 'BEST TRADE',
              value: performance.bestTrade == null
                  ? '—'
                  : journalMoney(performance.bestTrade!.netPnl, signed: true),
              caption: performance.bestTrade?.symbol,
            ),
            JournalMetricItem(
              label: 'WORST TRADE',
              value: performance.worstTrade == null
                  ? '—'
                  : journalMoney(performance.worstTrade!.netPnl, signed: true),
              caption: performance.worstTrade?.symbol,
            ),
            JournalMetricItem(
              label: 'BEST DAY',
              value: performance.bestDay == null
                  ? '—'
                  : journalMoney(performance.bestDay!.netPnl, signed: true),
              caption: performance.bestDay == null
                  ? null
                  : journalDate(performance.bestDay!.date),
            ),
            JournalMetricItem(
              label: 'WORST DAY',
              value: performance.worstDay == null
                  ? '—'
                  : journalMoney(performance.worstDay!.netPnl, signed: true),
              caption: performance.worstDay == null
                  ? null
                  : journalDate(performance.worstDay!.date),
            ),
            JournalMetricItem(
              label: 'WIN STREAK',
              value: '${performance.largestWinStreak}',
            ),
            JournalMetricItem(
              label: 'LOSS STREAK',
              value: '${performance.largestLossStreak}',
            ),
          ],
        ),
        const SizedBox(height: 14),
        JournalGroupTable(
          title: strings.pick('По активам', 'Asset Performance'),
          rows: assets,
        ),
        const SizedBox(height: 14),
        JournalGroupTable(title: 'LONG vs SHORT', rows: sides),
        const SizedBox(height: 14),
        JournalGroupTable(
          title: strings.pick('По источникам', 'Source Performance'),
          rows: sources,
        ),
      ],
    );
  }
}

class JournalStrategiesView extends StatelessWidget {
  const JournalStrategiesView({super.key, required this.trades});

  final List<TradeJournalEntry> trades;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: context.strings.pick('Стратегии', 'Strategies'),
          subtitle: context.strings.pick(
            'Статистика строится из реальных записей журнала',
            'Statistics are calculated from real journal records',
          ),
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 14),
        JournalGroupTable(
          title: 'STRATEGY PERFORMANCE',
          rows: JournalPerformanceEngine.byStrategy(trades),
        ),
      ],
    );
  }
}

class JournalMistakesView extends StatelessWidget {
  const JournalMistakesView({
    super.key,
    required this.trades,
    required this.performance,
  });

  final List<TradeJournalEntry> trades;
  final PerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    const Set<TradeTag> mistakeTags = <TradeTag>{
      TradeTag.badEntry,
      TradeTag.early,
      TradeTag.late,
      TradeTag.fomo,
      TradeTag.revenge,
      TradeTag.noConfirmation,
    };
    final Map<TradeTag, int> counts = <TradeTag, int>{};
    for (final TradeJournalEntry trade in trades) {
      for (final TradeTag tag in trade.tags.where(mistakeTags.contains)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<MapEntry<TradeTag, int>> rows = counts.entries.toList()
      ..sort(
        (MapEntry<TradeTag, int> first, MapEntry<TradeTag, int> second) =>
            second.value.compareTo(first.value),
      );
    final Color scoreColor = performance.disciplineScore >= 80
        ? semantic.bullish
        : performance.disciplineScore >= 60
        ? semantic.warning
        : semantic.bearish;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Ошибки и дисциплина', 'Mistakes & Discipline'),
          subtitle: strings.pick(
            'Счёт снижают только структурные факты и выбранные теги — текст заметки не считается доказательством ошибки.',
            'Only structural facts and selected tags lower the score; note text is not treated as proof.',
          ),
          icon: Icons.psychology_alt_outlined,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 145,
          child: ProductMetricCard(
            label: 'DISCIPLINE SCORE',
            value: '${performance.disciplineScore}/100',
            caption: strings.pick(
              'Risk, confirmation, R:R, revenge/FOMO tags',
              'Risk, confirmation, R:R, revenge/FOMO tags',
            ),
            icon: Icons.verified_user_outlined,
            color: scoreColor,
            emphasis: true,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.pick('Частые ошибки', 'Most Common Mistakes'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  Text(strings.noData)
                else
                  ...rows.map<Widget>(
                    (MapEntry<TradeTag, int> row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: semantic.warning,
                      ),
                      title: Text(tradeTagLabel(row.key)),
                      trailing: Text(
                        '${row.value}',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class JournalReportsView extends StatelessWidget {
  const JournalReportsView({
    super.key,
    required this.controller,
    required this.trades,
  });

  final JournalController controller;
  final List<TradeJournalEntry> trades;

  @override
  Widget build(BuildContext context) {
    final List<JournalPeriodSummary> weeks = JournalPerformanceEngine.weekly(
      trades,
      controller.journalSettings,
    );
    final List<JournalPeriodSummary> months = JournalPerformanceEngine.monthly(
      trades,
      controller.journalSettings,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: context.strings.pick('Отчёты', 'Reports'),
          subtitle: context.strings.pick(
            'Недельные и месячные итоги с отдельными заметками',
            'Weekly and monthly summaries with separate notes',
          ),
          icon: Icons.summarize_outlined,
        ),
        const SizedBox(height: 14),
        _reportSection(
          context,
          title: 'WEEKLY REVIEW',
          period: JournalReviewPeriod.week,
          rows: weeks,
        ),
        const SizedBox(height: 14),
        _reportSection(
          context,
          title: 'MONTHLY REVIEW',
          period: JournalReviewPeriod.month,
          rows: months,
        ),
      ],
    );
  }

  Widget _reportSection(
    BuildContext context, {
    required String title,
    required JournalReviewPeriod period,
    required List<JournalPeriodSummary> rows,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(context.strings.noData)
          else
            ...rows
                .take(12)
                .map<Widget>(
                  (JournalPeriodSummary row) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '${journalDate(row.start)} – ${journalDate(row.end)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${row.trades} trades · ${journalMoney(row.netPnl, signed: true)} · '
                      '${journalR(row.netR)} · ${row.winRate.toStringAsFixed(1)}% WR',
                    ),
                    trailing: IconButton(
                      tooltip: 'Notes',
                      onPressed: () =>
                          _editReviewNote(context, period, row.start),
                      icon: const Icon(Icons.note_alt_outlined),
                    ),
                    children: <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 24,
                          runSpacing: 10,
                          children: <Widget>[
                            _value('PF', _factor(row.profitFactor)),
                            _value('Drawdown', journalMoney(-row.drawdown)),
                            _value(
                              'Best Day',
                              row.bestDay == null
                                  ? '—'
                                  : journalMoney(
                                      row.bestDay!.netPnl,
                                      signed: true,
                                    ),
                            ),
                            _value(
                              'Worst Day',
                              row.worstDay == null
                                  ? '—'
                                  : journalMoney(
                                      row.worstDay!.netPnl,
                                      signed: true,
                                    ),
                            ),
                            if (period == JournalReviewPeriod.month)
                              _value(
                                'Best Week',
                                row.bestWeek == null
                                    ? '—'
                                    : '${journalDate(row.bestWeek!.start)} · '
                                          '${journalMoney(row.bestWeek!.netPnl, signed: true)}',
                              ),
                            if (period == JournalReviewPeriod.month)
                              _value(
                                'Worst Week',
                                row.worstWeek == null
                                    ? '—'
                                    : '${journalDate(row.worstWeek!.start)} · '
                                          '${journalMoney(row.worstWeek!.netPnl, signed: true)}',
                              ),
                            _value(
                              'Best Strategy',
                              row.bestStrategy.isEmpty ? '—' : row.bestStrategy,
                            ),
                            _value(
                              'Worst Strategy',
                              row.worstStrategy.isEmpty
                                  ? '—'
                                  : row.worstStrategy,
                            ),
                            _value(
                              'Best Asset',
                              row.bestAsset.isEmpty ? '—' : row.bestAsset,
                            ),
                            _value(
                              'Worst Asset',
                              row.worstAsset.isEmpty ? '—' : row.worstAsset,
                            ),
                            _value(
                              'Main Mistake',
                              row.mostCommonMistake == null
                                  ? '—'
                                  : tradeTagLabel(row.mostCommonMistake!),
                            ),
                            _value('Discipline', '${row.disciplineScore}/100'),
                          ],
                        ),
                      ),
                      if (controller.reviewText(period, row.start).isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: Text(
                              controller.reviewText(period, row.start),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ],
      ),
    ),
  );

  Widget _value(String label, String value) => SizedBox(
    width: 150,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 11)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  Future<void> _editReviewNote(
    BuildContext context,
    JournalReviewPeriod period,
    DateTime start,
  ) async {
    final TextEditingController text = TextEditingController(
      text: controller.reviewText(period, start),
    );
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          period == JournalReviewPeriod.week ? 'Weekly Notes' : 'Monthly Notes',
        ),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: text,
            maxLines: 8,
            decoration: const InputDecoration(
              hintText: 'Review and improvements',
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.pick('Отмена', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.pick('Сохранить', 'Save')),
          ),
        ],
      ),
    );
    if (save == true) {
      await controller.saveReviewNote(
        JournalReviewNote(
          period: period,
          periodStart: start,
          text: text.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    text.dispose();
  }
}

class JournalGroupTable extends StatelessWidget {
  const JournalGroupTable({super.key, required this.title, required this.rows});

  final String title;
  final List<JournalGroupPerformance> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(context.strings.noData)
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const <DataColumn>[
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Trades'), numeric: true),
                    DataColumn(label: Text('W/L')),
                    DataColumn(label: Text('Win Rate'), numeric: true),
                    DataColumn(label: Text('Avg R'), numeric: true),
                    DataColumn(label: Text('Net R'), numeric: true),
                    DataColumn(label: Text('PnL'), numeric: true),
                    DataColumn(label: Text('PF'), numeric: true),
                    DataColumn(label: Text('Drawdown'), numeric: true),
                  ],
                  rows: rows
                      .map<DataRow>(
                        (JournalGroupPerformance row) => DataRow(
                          cells: <DataCell>[
                            DataCell(Text(row.label)),
                            DataCell(Text('${row.trades}')),
                            DataCell(Text('${row.wins}/${row.losses}')),
                            DataCell(
                              Text('${row.winRate.toStringAsFixed(1)}%'),
                            ),
                            DataCell(Text(journalR(row.averageR))),
                            DataCell(Text(journalR(row.netR))),
                            DataCell(
                              Text(journalMoney(row.netPnl, signed: true)),
                            ),
                            DataCell(Text(_factor(row.profitFactor))),
                            DataCell(Text(journalMoney(-row.drawdown))),
                          ],
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _factor(double value) =>
    value.isInfinite ? '∞' : value.toStringAsFixed(2);
