import 'package:flutter/material.dart';

import '../engines/journal_performance_engine.dart';
import '../localization/app_strings.dart';
import '../models/trading_journal_models.dart';
import '../services/journal_controller.dart';
import '../widgets/product_components.dart';
import 'journal/journal_calendar_view.dart';
import 'journal/journal_notes_view.dart';
import 'journal/journal_overview_view.dart';
import 'journal/journal_performance_views.dart';
import 'journal/journal_trades_view.dart';
import 'journal/journal_ui_helpers.dart';
import 'journal/manual_trade_dialog.dart';

enum JournalSection {
  overview,
  trades,
  calendar,
  performance,
  strategies,
  mistakes,
  notes,
  reports,
}

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key, required this.controller, this.symbol});

  final JournalController controller;
  final String? symbol;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  JournalSection _section = JournalSection.overview;
  late JournalFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = JournalFilter(symbol: widget.symbol ?? '');
  }

  @override
  void didUpdateWidget(JournalScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) {
      _filter = _filter.copyWith(symbol: widget.symbol ?? '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<TradeJournalEntry> filtered =
            JournalPerformanceEngine.filterTrades(
              widget.controller.trades,
              _filter,
            );
        final PerformanceSnapshot performance =
            JournalPerformanceEngine.performance(
              widget.controller.trades,
              widget.controller.journalSettings,
              _filter,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SectionHeading(
                      title: strings.pick('Торговый журнал', 'Trading Journal'),
                      subtitle: strings.localOnly,
                      icon: Icons.menu_book_outlined,
                      trailing: FilledButton.icon(
                        onPressed: () => openManualTradeEditor(
                          context,
                          controller: widget.controller,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: Text(
                          strings.pick('Добавить сделку', 'Add Trade'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: JournalSection.values
                            .map<Widget>(
                              (JournalSection section) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  selected: _section == section,
                                  avatar: Icon(_sectionIcon(section), size: 17),
                                  label: Text(_sectionLabel(strings, section)),
                                  onSelected: (_) =>
                                      setState(() => _section = section),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    if (_section != JournalSection.notes) ...<Widget>[
                      const SizedBox(height: 10),
                      _JournalFilterBar(
                        filter: _filter,
                        onChanged: (JournalFilter value) =>
                            setState(() => _filter = value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: switch (_section) {
                JournalSection.overview => JournalOverviewView(
                  controller: widget.controller,
                  trades: filtered,
                  performance: performance,
                ),
                JournalSection.trades => JournalTradesView(
                  controller: widget.controller,
                  trades: filtered,
                ),
                JournalSection.calendar => JournalCalendarView(
                  controller: widget.controller,
                  trades: filtered,
                ),
                JournalSection.performance => JournalPerformanceView(
                  trades: filtered,
                  performance: performance,
                ),
                JournalSection.strategies => JournalStrategiesView(
                  trades: filtered,
                ),
                JournalSection.mistakes => JournalMistakesView(
                  trades: filtered,
                  performance: performance,
                ),
                JournalSection.notes => JournalNotesView(
                  controller: widget.controller,
                ),
                JournalSection.reports => JournalReportsView(
                  controller: widget.controller,
                  trades: filtered,
                ),
              },
            ),
          ],
        );
      },
    );
  }
}

class _JournalFilterBar extends StatelessWidget {
  const _JournalFilterBar({required this.filter, required this.onChanged});

  final JournalFilter filter;
  final ValueChanged<JournalFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                for (final PerformancePeriod period in PerformancePeriod.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: FilterChip(
                      selected: filter.period == period,
                      label: Text(journalPeriodLabel(strings, period)),
                      onSelected: (_) =>
                          onChanged(filter.copyWith(period: period)),
                    ),
                  ),
                const SizedBox(width: 8),
                FilterChip(
                  selected: filter.source == null,
                  label: Text(strings.all.toUpperCase()),
                  onSelected: (_) =>
                      onChanged(filter.copyWith(clearSource: true)),
                ),
                for (final TradeSource source in TradeSource.values.where(
                  (TradeSource value) => value != TradeSource.live,
                ))
                  Padding(
                    padding: const EdgeInsets.only(left: 5),
                    child: FilterChip(
                      selected: filter.source == source,
                      label: Text(tradeSourceLabel(source)),
                      onSelected: (_) =>
                          onChanged(filter.copyWith(source: source)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Badge(
          isLabelVisible: _advancedCount > 0,
          label: Text('$_advancedCount'),
          child: IconButton.filledTonal(
            tooltip: strings.pick('Дополнительные фильтры', 'More Filters'),
            onPressed: () => _editAdvanced(context),
            icon: const Icon(Icons.filter_alt_outlined),
          ),
        ),
      ],
    );
  }

  int get _advancedCount =>
      (filter.symbol.trim().isNotEmpty ? 1 : 0) +
      (filter.strategy.trim().isNotEmpty ? 1 : 0) +
      (filter.status != null ? 1 : 0) +
      (filter.side != null ? 1 : 0);

  Future<void> _editAdvanced(BuildContext context) async {
    final TextEditingController symbol = TextEditingController(
      text: filter.symbol,
    );
    final TextEditingController strategy = TextEditingController(
      text: filter.strategy,
    );
    JournalTradeStatus? status = filter.status;
    JournalTradeSide? side = filter.side;
    final JournalFilter? result = await showDialog<JournalFilter>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: Text(
                context.strings.pick('Фильтры сделок', 'Trade Filters'),
              ),
              content: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: symbol,
                      decoration: const InputDecoration(labelText: 'Symbol'),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: strategy,
                      decoration: const InputDecoration(labelText: 'Strategy'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<JournalTradeSide?>(
                      initialValue: side,
                      decoration: const InputDecoration(
                        labelText: 'LONG / SHORT',
                      ),
                      items: <DropdownMenuItem<JournalTradeSide?>>[
                        const DropdownMenuItem<JournalTradeSide?>(
                          value: null,
                          child: Text('ALL'),
                        ),
                        ...JournalTradeSide.values
                            .map<DropdownMenuItem<JournalTradeSide?>>(
                              (JournalTradeSide value) =>
                                  DropdownMenuItem<JournalTradeSide?>(
                                    value: value,
                                    child: Text(value.name.toUpperCase()),
                                  ),
                            ),
                      ],
                      onChanged: (JournalTradeSide? value) =>
                          setDialogState(() => side = value),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<JournalTradeStatus?>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Result'),
                      items: <DropdownMenuItem<JournalTradeStatus?>>[
                        const DropdownMenuItem<JournalTradeStatus?>(
                          value: null,
                          child: Text('ALL'),
                        ),
                        ...JournalTradeStatus.values
                            .map<DropdownMenuItem<JournalTradeStatus?>>(
                              (JournalTradeStatus value) =>
                                  DropdownMenuItem<JournalTradeStatus?>(
                                    value: value,
                                    child: Text(tradeStatusLabel(value)),
                                  ),
                            ),
                      ],
                      onChanged: (JournalTradeStatus? value) =>
                          setDialogState(() => status = value),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(
                    filter.copyWith(
                      symbol: '',
                      strategy: '',
                      clearStatus: true,
                      clearSide: true,
                    ),
                  ),
                  child: Text(context.strings.pick('Сбросить', 'Reset')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    filter.copyWith(
                      symbol: symbol.text,
                      strategy: strategy.text,
                      status: status,
                      clearStatus: status == null,
                      side: side,
                      clearSide: side == null,
                    ),
                  ),
                  child: Text(context.strings.pick('Применить', 'Apply')),
                ),
              ],
            ),
      ),
    );
    symbol.dispose();
    strategy.dispose();
    if (result != null) onChanged(result);
  }
}

String _sectionLabel(AppStrings strings, JournalSection section) =>
    switch (section) {
      JournalSection.overview => strings.pick('Обзор', 'Overview'),
      JournalSection.trades => strings.pick('Сделки', 'Trades'),
      JournalSection.calendar => strings.pick('Календарь', 'Calendar'),
      JournalSection.performance => strings.pick(
        'Эффективность',
        'Performance',
      ),
      JournalSection.strategies => strings.pick('Стратегии', 'Strategies'),
      JournalSection.mistakes => strings.pick('Ошибки', 'Mistakes'),
      JournalSection.notes => strings.pick('Заметки', 'Notes'),
      JournalSection.reports => strings.pick('Отчёты', 'Reports'),
    };

IconData _sectionIcon(JournalSection section) => switch (section) {
  JournalSection.overview => Icons.dashboard_outlined,
  JournalSection.trades => Icons.swap_horiz_rounded,
  JournalSection.calendar => Icons.calendar_month_outlined,
  JournalSection.performance => Icons.analytics_outlined,
  JournalSection.strategies => Icons.account_tree_outlined,
  JournalSection.mistakes => Icons.psychology_alt_outlined,
  JournalSection.notes => Icons.note_alt_outlined,
  JournalSection.reports => Icons.summarize_outlined,
};
