import 'package:flutter/material.dart';

import '../../engines/journal_performance_engine.dart';
import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../widgets/product_components.dart';
import 'journal_ui_helpers.dart';
import 'manual_trade_dialog.dart';

class JournalCalendarView extends StatefulWidget {
  const JournalCalendarView({
    super.key,
    required this.controller,
    required this.trades,
  });

  final JournalController controller;
  final List<TradeJournalEntry> trades;

  @override
  State<JournalCalendarView> createState() => _JournalCalendarViewState();
}

class _JournalCalendarViewState extends State<JournalCalendarView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<DailyJournalSummary> summaries =
        JournalPerformanceEngine.calendar(
          widget.trades,
          settings: widget.controller.journalSettings,
        );
    final Map<String, DailyJournalSummary> byDay =
        <String, DailyJournalSummary>{
          for (final DailyJournalSummary day in summaries)
            dateKey(day.date): day,
        };
    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final int leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final List<Widget> cells = <Widget>[
      for (int index = 0; index < leading; index++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        _dayCell(
          context,
          DateTime(_month.year, _month.month, day),
          byDay[dateKey(DateTime(_month.year, _month.month, day))],
        ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Торговый календарь', 'Trading Calendar'),
          subtitle: strings.pick(
            'Net PnL, Net R и количество закрытых сделок по дням',
            'Net PnL, Net R and closed trade count by day',
          ),
          icon: Icons.calendar_month_outlined,
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month - 1),
                      ),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        _monthLabel(_month, strings),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(
                        () => _month = DateTime(_month.year, _month.month + 1),
                      ),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 7,
                  childAspectRatio: 1.15,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  children: <Widget>[
                    for (final String label in _weekdayLabels(strings))
                      Center(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ...cells,
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    DailyJournalSummary? summary,
  ) {
    final bool hasNote = widget.controller
        .reviewText(JournalReviewPeriod.day, day)
        .trim()
        .isNotEmpty;
    final Color color = tradeResultColor(context, summary?.netPnl ?? 0);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _openDay(context, day, summary),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: summary == null
              ? Theme.of(context).colorScheme.surfaceContainerLow
              : color.withValues(alpha: 0.10),
          border: Border.all(
            color: summary == null
                ? Theme.of(context).colorScheme.outlineVariant
                : color.withValues(alpha: 0.45),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '${day.day}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                if (hasNote)
                  Icon(Icons.note_alt_outlined, size: 14, color: color),
              ],
            ),
            if (summary != null) ...<Widget>[
              const Spacer(),
              Text(
                journalMoney(summary.netPnl, signed: true),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
              Text(
                '${journalR(summary.netR)} · ${summary.trades.length}T',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDay(
    BuildContext context,
    DateTime day,
    DailyJournalSummary? summary,
  ) async {
    final TextEditingController note = TextEditingController(
      text: widget.controller.reviewText(JournalReviewPeriod.day, day),
    );
    final AppStrings strings = context.strings;
    final bool? save = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          '${strings.pick('Разбор дня', 'Day Review')} · ${journalDate(day)}',
        ),
        content: SizedBox(
          width: 700,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (summary == null)
                  Text(
                    strings.pick('Закрытых сделок нет.', 'No closed trades.'),
                  )
                else ...<Widget>[
                  JournalMetricGrid(
                    items: <JournalMetricItem>[
                      JournalMetricItem(
                        label: 'TRADES',
                        value: '${summary.trades.length}',
                        caption: '${summary.wins}W · ${summary.losses}L',
                      ),
                      JournalMetricItem(
                        label: 'NET PNL',
                        value: journalMoney(summary.netPnl, signed: true),
                        color: tradeResultColor(context, summary.netPnl),
                      ),
                      JournalMetricItem(
                        label: 'NET R',
                        value: journalR(summary.netR),
                      ),
                      JournalMetricItem(
                        label: 'WIN RATE',
                        value: '${summary.winRate.toStringAsFixed(1)}%',
                      ),
                      JournalMetricItem(
                        label: 'PROFIT FACTOR',
                        value: summary.profitFactor.isInfinite
                            ? '∞'
                            : summary.profitFactor.toStringAsFixed(2),
                      ),
                      JournalMetricItem(
                        label: 'DAILY DRAWDOWN',
                        value: journalMoney(-summary.dailyDrawdown),
                      ),
                      JournalMetricItem(
                        label: 'DISCIPLINE',
                        value: '${summary.disciplineScore}/100',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (summary.bestTrade != null)
                    Text(
                      'Best: ${summary.bestTrade!.symbol} '
                      '${journalMoney(summary.bestTrade!.netPnl, signed: true)}',
                    ),
                  if (summary.worstTrade != null)
                    Text(
                      'Worst: ${summary.worstTrade!.symbol} '
                      '${journalMoney(summary.worstTrade!.netPnl, signed: true)}',
                    ),
                  const Divider(height: 24),
                  ...summary.trades.map<Widget>(
                    (TradeJournalEntry trade) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => openTradeDetail(
                        context,
                        controller: widget.controller,
                        trade: trade,
                      ),
                      title: Text(
                        '${trade.symbol} · ${trade.side.name.toUpperCase()}',
                      ),
                      subtitle: Text(
                        '${journalTime(trade.tradeTime)} · ${trade.strategy}',
                      ),
                      trailing: Text(
                        journalMoney(trade.netPnl, signed: true),
                        style: TextStyle(
                          color: tradeResultColor(context, trade.netPnl),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: strings.pick('Заметки дня', 'Day Notes'),
                    hintText: strings.pick(
                      'Что происходило, что улучшить, какие сетапы работали?',
                      'What happened, what should improve, which setups worked?',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.pick('Отмена', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.pick('Сохранить заметку', 'Save Note')),
          ),
        ],
      ),
    );
    if (save == true) {
      await widget.controller.saveReviewNote(
        JournalReviewNote(
          period: JournalReviewPeriod.day,
          periodStart: day,
          text: note.text.trim(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    note.dispose();
  }
}

List<String> _weekdayLabels(AppStrings strings) => strings.isRussian
    ? const <String>['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС']
    : const <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

String _monthLabel(DateTime value, AppStrings strings) {
  const List<String> ru = <String>[
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];
  const List<String> en = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${(strings.isRussian ? ru : en)[value.month - 1]} ${value.year}';
}
