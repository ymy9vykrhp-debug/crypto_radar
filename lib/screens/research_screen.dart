import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/backtest_models.dart';
import '../models/first_move_models.dart';
import '../services/journal_controller.dart';
import '../widgets/product_components.dart';

enum ResearchView {
  backtest,
  strategies,
  factors,
  firstMove,
  whatIf,
  paperTrading,
  selfAnalysis,
}

class ResearchScreen extends StatefulWidget {
  const ResearchScreen({super.key, required this.controller});

  final JournalController controller;

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  ResearchView _view = ResearchView.backtest;
  String? _selectedSymbol;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final AppStrings strings = context.strings;
        final List<BacktestReport> reports = widget.controller.backtests;
        final BacktestReport? selected = _selectedReport(reports);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Исследование', 'Research'),
              subtitle: strings.pick(
                'Backtest и статистика отделены от торгового журнала',
                'Backtest and statistics are separated from the trading journal',
              ),
              icon: Icons.science_outlined,
              trailing: FilledButton.icon(
                onPressed: widget.controller.backtestRunning
                    ? null
                    : widget.controller.runInitialBacktests,
                icon: widget.controller.backtestRunning
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(strings.pick('Запустить backtest', 'Run backtest')),
              ),
            ),
            const SizedBox(height: 14),
            _ResearchNavigation(
              selected: _view,
              onSelected: (ResearchView value) => setState(() => _view = value),
            ),
            const SizedBox(height: 14),
            if (widget.controller.error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(widget.controller.error!),
                ),
              ),
            if (widget.controller.error != null) const SizedBox(height: 12),
            _content(strings, reports, selected),
          ],
        );
      },
    );
  }

  Widget _content(
    AppStrings strings,
    List<BacktestReport> reports,
    BacktestReport? selected,
  ) {
    switch (_view) {
      case ResearchView.backtest:
        return _BacktestResultsTable(
          reports: reports,
          onSelect: (BacktestReport report) =>
              setState(() => _selectedSymbol = report.symbol),
        );
      case ResearchView.strategies:
        return _StrategyComparison(report: selected);
      case ResearchView.factors:
        return _FactorAnalysis(report: selected);
      case ResearchView.firstMove:
        return _FirstMoveAnalysis(report: selected);
      case ResearchView.whatIf:
        return _PlannedResearchPanel(
          icon: Icons.tune_rounded,
          title: 'What-if',
          message: strings.pick(
            'Интерактивное сравнение параметров будет добавлено после rolling walk-forward и учёта комиссий.',
            'Interactive parameter comparison will follow rolling walk-forward and fee modelling.',
          ),
        );
      case ResearchView.paperTrading:
        return _PlannedResearchPanel(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Paper Trading',
          message: strings.pick(
            'Виртуальный портфель ещё не активирован. Реальные ордера Bybit отключены.',
            'The virtual portfolio is not active yet. Real Bybit orders remain disabled.',
          ),
        );
      case ResearchView.selfAnalysis:
        return _PlannedResearchPanel(
          icon: Icons.psychology_outlined,
          title: strings.pick('Самоанализ', 'Self Analysis'),
          message: strings.pick(
            'Ошибки, паттерны и отчёты будут строиться из завершённых сделок журнала.',
            'Mistakes, patterns and reports will be derived from completed journal trades.',
          ),
        );
    }
  }

  BacktestReport? _selectedReport(List<BacktestReport> reports) {
    if (reports.isEmpty) return null;
    if (_selectedSymbol == null) return reports.first;
    return reports.cast<BacktestReport?>().firstWhere(
      (BacktestReport? report) => report?.symbol == _selectedSymbol,
      orElse: () => reports.first,
    );
  }
}

class _ResearchNavigation extends StatelessWidget {
  const _ResearchNavigation({required this.selected, required this.onSelected});

  final ResearchView selected;
  final ValueChanged<ResearchView> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final Map<ResearchView, String> labels = <ResearchView, String>{
      ResearchView.backtest: 'Backtest',
      ResearchView.strategies: strings.pick('Стратегии', 'Strategies'),
      ResearchView.factors: strings.pick('Факторы', 'Factors'),
      ResearchView.firstMove: 'First Move',
      ResearchView.whatIf: 'What-if',
      ResearchView.paperTrading: 'Paper Trading',
      ResearchView.selfAnalysis: strings.pick('Самоанализ', 'Self Analysis'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ResearchView.values
            .map<Widget>(
              (ResearchView view) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: selected == view,
                  label: Text(labels[view]!),
                  onSelected: (_) => onSelected(view),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _BacktestResultsTable extends StatelessWidget {
  const _BacktestResultsTable({required this.reports, required this.onSelect});

  final List<BacktestReport> reports;
  final ValueChanged<BacktestReport> onSelect;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    if (reports.isEmpty) {
      return ProductEmptyState(
        icon: Icons.science_outlined,
        title: strings.pick('Backtest ещё не запускался', 'No backtest yet'),
        message: strings.pick(
          'Нажмите «Запустить backtest». Результаты сохранятся локально.',
          'Run the backtest. Results will be stored locally.',
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columns: <DataColumn>[
            const DataColumn(label: Text('Mode')),
            const DataColumn(label: Text('Trades'), numeric: true),
            const DataColumn(label: Text('Win Rate'), numeric: true),
            const DataColumn(label: Text('Raw Avg R'), numeric: true),
            const DataColumn(label: Text('Net Avg R'), numeric: true),
            const DataColumn(label: Text('Raw PF'), numeric: true),
            const DataColumn(label: Text('Net PF'), numeric: true),
            const DataColumn(label: Text('Net DD'), numeric: true),
            const DataColumn(label: Text('Costs/Gross'), numeric: true),
            const DataColumn(label: Text('TP1'), numeric: true),
            const DataColumn(label: Text('TP2'), numeric: true),
            const DataColumn(label: Text('Stop→TP'), numeric: true),
          ],
          rows: reports
              .map<DataRow>(
                (BacktestReport report) => DataRow(
                  onSelectChanged: (_) => onSelect(report),
                  cells: <DataCell>[
                    DataCell(Text(report.symbol)),
                    DataCell(Text(report.trades.toString())),
                    DataCell(Text('${report.winRate.toStringAsFixed(1)}%')),
                    DataCell(Text(report.rawAverageR.toStringAsFixed(2))),
                    DataCell(Text(report.netAverageR.toStringAsFixed(2))),
                    DataCell(Text(report.rawProfitFactor.toStringAsFixed(2))),
                    DataCell(Text(report.netProfitFactor.toStringAsFixed(2))),
                    DataCell(
                      Text('${report.netMaxDrawdownR.toStringAsFixed(1)}R'),
                    ),
                    DataCell(
                      Text('${report.costToGrossPercent.toStringAsFixed(1)}%'),
                    ),
                    DataCell(Text('${report.tp1Percent.toStringAsFixed(1)}%')),
                    DataCell(Text('${report.tp2Percent.toStringAsFixed(1)}%')),
                    DataCell(
                      Text('${report.stopThenTp1Percent.toStringAsFixed(1)}%'),
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _StrategyComparison extends StatelessWidget {
  const _StrategyComparison({required this.report});

  final BacktestReport? report;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    if (report == null) {
      return ProductEmptyState(
        icon: Icons.route_outlined,
        title: strings.noData,
        message: strings.pick(
          'Сначала запустите backtest.',
          'Run a backtest first.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(
          title:
              '${report!.symbol} · ${strings.pick('Сравнение стратегий', 'Strategy Comparison')}',
          icon: Icons.route_outlined,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('Mode')),
                DataColumn(label: Text('Trades'), numeric: true),
                DataColumn(label: Text('Win Rate'), numeric: true),
                DataColumn(label: Text('Avg R'), numeric: true),
                DataColumn(label: Text('PF'), numeric: true),
                DataColumn(label: Text('DD'), numeric: true),
                DataColumn(label: Text('Stop→TP'), numeric: true),
                DataColumn(label: Text('Validation/OOS')),
              ],
              rows: report!.executionComparisons
                  .map<DataRow>(
                    (ExecutionPerformance row) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(row.label)),
                        DataCell(Text(row.trades.toString())),
                        DataCell(Text('${row.winRate.toStringAsFixed(1)}%')),
                        DataCell(Text(row.averageR.toStringAsFixed(2))),
                        DataCell(Text(row.profitFactor.toStringAsFixed(2))),
                        DataCell(
                          Text('${row.maxDrawdownR.toStringAsFixed(1)}R'),
                        ),
                        DataCell(
                          Text(
                            '${row.stopThenTargetPercent.toStringAsFixed(1)}%',
                          ),
                        ),
                        DataCell(
                          Text(
                            '${row.validationTrades}/${row.outOfSampleTrades} · '
                            '${row.validationAverageR.toStringAsFixed(2)}R/'
                            '${row.outOfSampleAverageR.toStringAsFixed(2)}R',
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _FactorAnalysis extends StatelessWidget {
  const _FactorAnalysis({required this.report});

  final BacktestReport? report;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    if (report == null) {
      return ProductEmptyState(
        icon: Icons.analytics_outlined,
        title: strings.noData,
        message: strings.pick(
          'Сначала запустите backtest.',
          'Run a backtest first.',
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(
          title:
              '${report!.symbol} · ${strings.pick('Статистика факторов', 'Factor Statistics')}',
          subtitle: strings.pick(
            'Эффективность — историческая статистика с размером выборки, не вероятность будущей сделки.',
            'Effectiveness is historical evidence with sample size, not future-trade probability.',
          ),
          icon: Icons.analytics_outlined,
        ),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Factor')),
              DataColumn(label: Text('Trades'), numeric: true),
              DataColumn(label: Text('Win Rate'), numeric: true),
              DataColumn(label: Text('Avg R'), numeric: true),
            ],
            rows: report!.factors
                .map<DataRow>(
                  (FactorPerformance factor) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(factor.name)),
                      DataCell(Text(factor.trades.toString())),
                      DataCell(Text('${factor.winRate.toStringAsFixed(1)}%')),
                      DataCell(Text(factor.averageR.toStringAsFixed(2))),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _FirstMoveAnalysis extends StatelessWidget {
  const _FirstMoveAnalysis({required this.report});

  final BacktestReport? report;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    if (report == null) {
      return ProductEmptyState(
        icon: Icons.insights_rounded,
        title: strings.noData,
        message: strings.pick(
          'Сначала запустите backtest.',
          'Run a backtest first.',
        ),
      );
    }
    final List<FirstMoveHistoricalBucket> buckets = report!.firstMoveBuckets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeading(
          title: '${report!.symbol} · First Move Probability',
          subtitle: strings.pick(
            'Вероятность достижения движения раньше структурного Stop. Только завершённые наблюдения, без будущих данных.',
            'Probability of reaching a move before the structural Stop. Completed observations only, without future data.',
          ),
          icon: Icons.insights_rounded,
        ),
        const SizedBox(height: 12),
        if (buckets.isEmpty)
          ProductEmptyState(
            icon: Icons.hourglass_empty_rounded,
            title: strings.pick(
              'Пока нет завершённых наблюдений',
              'No completed observations yet',
            ),
            message: strings.pick(
              'Нужны минимум 50 похожих наблюдений в одной группе.',
              'At least 50 similar observations are required in one group.',
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const <DataColumn>[
                  DataColumn(label: Text('Side')),
                  DataColumn(label: Text('Mode')),
                  DataColumn(label: Text('Regime')),
                  DataColumn(label: Text('Volatility')),
                  DataColumn(label: Text('Stop')),
                  DataColumn(label: Text('Samples'), numeric: true),
                  DataColumn(label: Text('0.20%'), numeric: true),
                  DataColumn(label: Text('0.30%'), numeric: true),
                  DataColumn(label: Text('0.50%'), numeric: true),
                  DataColumn(label: Text('0.75%'), numeric: true),
                  DataColumn(label: Text('1.00%'), numeric: true),
                  DataColumn(label: Text('Stop first'), numeric: true),
                ],
                rows: buckets
                    .map<DataRow>(
                      (FirstMoveHistoricalBucket bucket) => DataRow(
                        cells: <DataCell>[
                          DataCell(Text(bucket.direction)),
                          DataCell(Text(bucket.tradingMode)),
                          DataCell(Text(bucket.marketRegime)),
                          DataCell(Text(bucket.volatilityRegime)),
                          DataCell(Text(bucket.stopDistanceBucket)),
                          DataCell(Text(bucket.samples.toString())),
                          DataCell(Text(_bucketPercent(bucket, 0.20))),
                          DataCell(Text(_bucketPercent(bucket, 0.30))),
                          DataCell(Text(_bucketPercent(bucket, 0.50))),
                          DataCell(Text(_bucketPercent(bucket, 0.75))),
                          DataCell(Text(_bucketPercent(bucket, 1.00))),
                          DataCell(
                            Text(
                              bucket.samples == 0
                                  ? '—'
                                  : '${(bucket.stopFirst / bucket.samples * 100).toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        const SizedBox(height: 14),
        SectionHeading(
          title: strings.pick('Калибровка', 'Calibration'),
          subtitle: strings.pick(
            'Если система пишет 70–75%, фактический успех должен быть близок к этому диапазону.',
            'When the system says 70–75%, actual success should be close to that range.',
          ),
          icon: Icons.rule_rounded,
        ),
        const SizedBox(height: 10),
        Card(
          clipBehavior: Clip.antiAlias,
          child: DataTable(
            columns: const <DataColumn>[
              DataColumn(label: Text('Predicted')),
              DataColumn(label: Text('Actual'), numeric: true),
              DataColumn(label: Text('Samples'), numeric: true),
            ],
            rows: report!.calibrationBuckets
                .map<DataRow>(
                  (ProbabilityCalibrationBucket bucket) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text('${bucket.label}%')),
                      DataCell(
                        Text(
                          bucket.samples == 0
                              ? '—'
                              : '${bucket.actualSuccessPercent.toStringAsFixed(1)}%',
                        ),
                      ),
                      DataCell(Text(bucket.samples.toString())),
                    ],
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }

  String _bucketPercent(FirstMoveHistoricalBucket bucket, double threshold) {
    if (bucket.samples < 50) return 'н/д (${bucket.samples}/50)';
    return '${bucket.probabilityFor(threshold).toStringAsFixed(1)}%';
  }
}

class _PlannedResearchPanel extends StatelessWidget {
  const _PlannedResearchPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ProductEmptyState(
      icon: icon,
      title: title,
      message: message,
      action: ProductStatusChip(
        label: context.strings.planned,
        color: Theme.of(context).colorScheme.secondary,
        icon: Icons.schedule_rounded,
      ),
    );
  }
}
