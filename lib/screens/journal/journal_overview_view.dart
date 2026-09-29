import 'package:flutter/material.dart';

import '../../engines/journal_performance_engine.dart';
import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../services/journal_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/equity_curve_chart.dart';
import '../../widgets/product_components.dart';
import 'journal_ui_helpers.dart';
import 'manual_trade_dialog.dart';

class JournalOverviewView extends StatelessWidget {
  const JournalOverviewView({
    super.key,
    required this.controller,
    required this.trades,
    required this.performance,
  });

  final JournalController controller;
  final List<TradeJournalEntry> trades;
  final PerformanceSnapshot performance;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final List<DailyJournalSummary> days = JournalPerformanceEngine.calendar(
      trades,
      settings: controller.journalSettings,
    );
    final List<JournalGroupPerformance> strategies =
        JournalPerformanceEngine.byStrategy(trades);
    final List<TradeJournalEntry> recent = trades
        .take(5)
        .toList(growable: false);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Обзор журнала', 'Journal Overview'),
          subtitle: strings.pick(
            'Баланс меняют только закрытые сделки. Открытые позиции не входят в realized PnL.',
            'Only closed trades change balance. Open positions are excluded from realized PnL.',
          ),
          icon: Icons.dashboard_outlined,
          trailing: OutlinedButton.icon(
            onPressed: () => _editSettings(context),
            icon: const Icon(Icons.tune_rounded),
            label: Text(strings.pick('Баланс и цели', 'Balance & Goals')),
          ),
        ),
        const SizedBox(height: 14),
        JournalMetricGrid(
          items: <JournalMetricItem>[
            JournalMetricItem(
              label: 'CURRENT BALANCE',
              value: journalMoney(performance.currentBalance),
              caption:
                  'START ${journalMoney(performance.startingBalance)} · '
                  'PnL ${journalMoney(performance.netPnl, signed: true)}',
              icon: Icons.account_balance_wallet_outlined,
              color: tradeResultColor(context, performance.netPnl),
              emphasis: true,
            ),
            JournalMetricItem(
              label: 'TOTAL PNL',
              value: journalMoney(performance.netPnl, signed: true),
              caption: journalPercent(performance.returnPercent),
              icon: Icons.payments_outlined,
              color: tradeResultColor(context, performance.netPnl),
            ),
            JournalMetricItem(
              label: 'NET R',
              value: journalR(performance.netR),
              icon: Icons.show_chart_rounded,
              color: tradeResultColor(context, performance.netR),
            ),
            JournalMetricItem(
              label: strings.pick('Сделки', 'Trades'),
              value: '${performance.trades}',
              caption: 'OPEN ${performance.openTrades}',
              icon: Icons.swap_horiz_rounded,
            ),
            JournalMetricItem(
              label: 'WIN RATE',
              value: '${performance.winRate.toStringAsFixed(1)}%',
              caption:
                  '${performance.wins}W · ${performance.losses}L · ${performance.breakEven}BE',
              icon: Icons.percent_rounded,
            ),
            JournalMetricItem(
              label: 'PROFIT FACTOR',
              value: _factor(performance.profitFactor),
              icon: Icons.balance_rounded,
            ),
            JournalMetricItem(
              label: 'MAX DRAWDOWN',
              value: journalMoney(-performance.maxDrawdown),
              caption: '-${performance.maxDrawdownPercent.toStringAsFixed(2)}%',
              icon: Icons.trending_down_rounded,
              color: performance.maxDrawdown > 0
                  ? semantic.bearish
                  : semantic.neutral,
            ),
            JournalMetricItem(
              label: 'DISCIPLINE SCORE',
              value: '${performance.disciplineScore}/100',
              icon: Icons.verified_user_outlined,
              color: performance.disciplineScore >= 80
                  ? semantic.bullish
                  : performance.disciplineScore >= 60
                  ? semantic.warning
                  : semantic.bearish,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SectionHeading(
                  title: 'EQUITY CURVE',
                  subtitle: strings.pick(
                    'Точка добавляется после каждой закрытой сделки',
                    'A point is added after every closed trade',
                  ),
                  icon: Icons.insights_rounded,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 270,
                  child: EquityCurveChart(points: performance.equity),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _sectionGrid(
          context,
          first: _recentDays(context, days),
          second: _recentTrades(context, recent),
        ),
        const SizedBox(height: 14),
        _sectionGrid(
          context,
          first: _strategyCard(context, strategies),
          second: _mistakesCard(context),
        ),
      ],
    );
  }

  Widget _sectionGrid(
    BuildContext context, {
    required Widget first,
    required Widget second,
  }) => LayoutBuilder(
    builder: (BuildContext context, BoxConstraints constraints) {
      if (constraints.maxWidth < 850) {
        return Column(
          children: <Widget>[first, const SizedBox(height: 14), second],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: first),
          const SizedBox(width: 14),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _recentDays(BuildContext context, List<DailyJournalSummary> days) {
    final List<DailyJournalSummary> recent = days.reversed
        .take(7)
        .toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.strings.pick(
                'Последние торговые дни',
                'Recent Trading Days',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Text(context.strings.noData)
            else
              ...recent.map<Widget>(
                (DailyJournalSummary day) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(journalDate(day.date)),
                  subtitle: Text(
                    '${day.trades.length} trades · ${journalR(day.netR)}',
                  ),
                  trailing: Text(
                    journalMoney(day.netPnl, signed: true),
                    style: TextStyle(
                      color: tradeResultColor(context, day.netPnl),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recentTrades(BuildContext context, List<TradeJournalEntry> recent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.strings.pick('Последние сделки', 'Recent Trades'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (recent.isEmpty)
              Text(context.strings.noData)
            else
              ...recent.map<Widget>(
                (TradeJournalEntry trade) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: () => openTradeDetail(
                    context,
                    controller: controller,
                    trade: trade,
                  ),
                  title: Text(
                    '${trade.symbol} · ${trade.side.name.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    '${tradeSourceLabel(trade.source)} · ${journalDate(trade.tradeTime)}',
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
        ),
      ),
    );
  }

  Widget _strategyCard(
    BuildContext context,
    List<JournalGroupPerformance> strategies,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'STRATEGY PERFORMANCE',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (strategies.isEmpty)
            Text(context.strings.noData)
          else
            ...strategies
                .take(5)
                .map<Widget>(
                  (JournalGroupPerformance row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(row.label),
                    subtitle: Text(
                      '${row.trades} trades · ${row.winRate.toStringAsFixed(1)}% WR · '
                      'PF ${_factor(row.profitFactor)}',
                    ),
                    trailing: Text(
                      journalR(row.netR),
                      style: TextStyle(
                        color: tradeResultColor(context, row.netR),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    ),
  );

  Widget _mistakesCard(BuildContext context) {
    final Map<TradeTag, int> counts = <TradeTag, int>{};
    const Set<TradeTag> mistakes = <TradeTag>{
      TradeTag.badEntry,
      TradeTag.early,
      TradeTag.late,
      TradeTag.fomo,
      TradeTag.revenge,
      TradeTag.noConfirmation,
    };
    for (final TradeJournalEntry trade in trades) {
      for (final TradeTag tag in trade.tags.where(mistakes.contains)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    final List<MapEntry<TradeTag, int>> rows = counts.entries.toList()
      ..sort(
        (MapEntry<TradeTag, int> first, MapEntry<TradeTag, int> second) =>
            second.value.compareTo(first.value),
      );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              context.strings.pick(
                'ОШИБКИ / ДИСЦИПЛИНА',
                'MISTAKES / DISCIPLINE',
              ),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(
                context.strings.pick(
                  'Подтверждённых ошибок по тегам пока нет.',
                  'No tag-confirmed mistakes yet.',
                ),
              )
            else
              ...rows
                  .take(6)
                  .map<Widget>(
                    (MapEntry<TradeTag, int> row) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(tradeTagLabel(row.key)),
                      trailing: Text('${row.value}'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSettings(BuildContext context) async {
    final JournalSettings current = controller.journalSettings;
    final TextEditingController starting = TextEditingController(
      text: current.startingBalance.toString(),
    );
    final TextEditingController dailyLoss = TextEditingController(
      text: current.dailyMaxLoss?.toString() ?? '',
    );
    final TextEditingController weeklyLoss = TextEditingController(
      text: current.weeklyMaxLoss?.toString() ?? '',
    );
    final TextEditingController dailyTarget = TextEditingController(
      text: current.dailyTarget?.toString() ?? '',
    );
    final JournalSettings? result = await showDialog<JournalSettings>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.strings.pick('Баланс и цели', 'Balance & Goals')),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _numberField(starting, 'Starting Balance'),
              const SizedBox(height: 10),
              _numberField(dailyLoss, 'Daily Max Loss (optional)'),
              const SizedBox(height: 10),
              _numberField(weeklyLoss, 'Weekly Max Loss (optional)'),
              const SizedBox(height: 10),
              _numberField(dailyTarget, 'Daily Target (optional)'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.strings.pick('Отмена', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(
              JournalSettings(
                startingBalance: _parse(starting.text),
                dailyMaxLoss: _optional(dailyLoss.text),
                weeklyMaxLoss: _optional(weeklyLoss.text),
                dailyTarget: _optional(dailyTarget.text),
              ),
            ),
            child: Text(context.strings.pick('Сохранить', 'Save')),
          ),
        ],
      ),
    );
    starting.dispose();
    dailyLoss.dispose();
    weeklyLoss.dispose();
    dailyTarget.dispose();
    if (result != null) await controller.updateJournalSettings(result);
  }

  Widget _numberField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '\$ '),
      );
}

String _factor(double value) =>
    value.isInfinite ? '∞' : value.toStringAsFixed(2);

double _parse(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0.0;

double? _optional(String raw) {
  final String value = raw.trim().replaceAll(',', '.');
  return value.isEmpty ? null : double.tryParse(value);
}
