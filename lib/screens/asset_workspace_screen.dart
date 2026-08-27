import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engines/decision_engine.dart';
import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../localization/app_strings.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/live_market_models.dart';
import '../models/market_models.dart';
import '../models/navigation_models.dart';
import '../models/signal_models.dart';
import '../services/bybit_service.dart';
import '../services/journal_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation.dart';
import '../widgets/product_components.dart';
import 'chart_screen.dart';
import 'journal_screen.dart';
import 'news_screen.dart';
import 'product_dashboard_screen.dart';
import 'why_now_screen.dart';

class AssetWorkspaceScreen extends StatelessWidget {
  const AssetWorkspaceScreen({
    super.key,
    required this.snapshot,
    required this.journalController,
    required this.bybitService,
    required this.selected,
    required this.onSelected,
    this.livePrice,
  });

  final MarketSnapshot snapshot;
  final JournalController journalController;
  final BybitService bybitService;
  final WorkspaceSection selected;
  final ValueChanged<WorkspaceSection> onSelected;
  final ValueListenable<LivePriceTick?>? livePrice;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.currency_bitcoin_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      snapshot.symbol,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _WorkspaceLivePrice(
                      symbol: snapshot.symbol,
                      fallback: snapshot.ticker.price,
                      livePrice: livePrice,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: WorkspaceSection.values
                        .map<Widget>(
                          (WorkspaceSection section) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: ChoiceChip(
                              selected: selected == section,
                              avatar: Icon(
                                workspaceSectionIcon(section),
                                size: 16,
                              ),
                              label: Text(strings.workspaceSection(section)),
                              onSelected: (_) => onSelected(section),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    switch (selected) {
      case WorkspaceSection.overview:
        return ProductDashboardScreen(
          snapshot: snapshot,
          journalController: journalController,
          livePrice: livePrice,
          onWhy: () => onSelected(WorkspaceSection.why),
          onOpenWorkspace: () => onSelected(WorkspaceSection.chart),
        );
      case WorkspaceSection.chart:
        return ChartScreen(
          snapshot: snapshot,
          journalController: journalController,
          bybitService: bybitService,
          onOpenWhy: () => onSelected(WorkspaceSection.why),
        );
      case WorkspaceSection.structure:
        return _StructureWorkspace(snapshot: snapshot);
      case WorkspaceSection.levels:
        return _LevelsWorkspace(snapshot: snapshot);
      case WorkspaceSection.volume:
        return _VolumeWorkspace(snapshot: snapshot);
      case WorkspaceSection.signal:
        return _SignalWorkspace(snapshot: snapshot);
      case WorkspaceSection.why:
        return WhyNowScreen(marketSnapshot: snapshot);
      case WorkspaceSection.journal:
        return JournalScreen(
          controller: journalController,
          symbol: snapshot.symbol,
        );
      case WorkspaceSection.news:
        return NewsScreen(symbol: snapshot.symbol);
    }
  }
}

class _StructureWorkspace extends StatelessWidget {
  const _StructureWorkspace({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<TimeframeAnalysis> frames = <TimeframeAnalysis>[
      snapshot.oneMinute,
      snapshot.fiveMinutes,
      snapshot.fifteenMinutes,
      snapshot.oneHour,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Структура рынка', 'Market Structure'),
          subtitle: strings.pick(
            'HH/HL/LH/LL, BOS и CHOCH по выбранному активу',
            'HH/HL/LH/LL, BOS and CHOCH for the selected asset',
          ),
          icon: Icons.account_tree_outlined,
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: <DataColumn>[
                const DataColumn(label: Text('TF')),
                DataColumn(label: Text(strings.pick('Тренд', 'Trend'))),
                DataColumn(label: Text(strings.pick('Структура', 'Structure'))),
                const DataColumn(label: Text('BOS')),
                const DataColumn(label: Text('CHOCH')),
                DataColumn(
                  label: Text(strings.pick('Последний High', 'Last High')),
                ),
                DataColumn(
                  label: Text(strings.pick('Последний Low', 'Last Low')),
                ),
              ],
              rows: frames
                  .map<DataRow>(
                    (TimeframeAnalysis frame) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(frame.name)),
                        DataCell(_BiasText(frame.trend)),
                        DataCell(
                          Text(
                            '${frame.structure.highLabel} / ${frame.structure.lowLabel}',
                          ),
                        ),
                        DataCell(_BiasText(frame.structure.bos)),
                        DataCell(_BiasText(frame.structure.choch)),
                        DataCell(
                          Text(_nullablePrice(frame.structure.lastSwingHigh)),
                        ),
                        DataCell(
                          Text(_nullablePrice(frame.structure.lastSwingLow)),
                        ),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ProductExpandableSection(
          title: strings.pick('Расширенная структура', 'Advanced Structure'),
          icon: Icons.schema_outlined,
          child: Text(
            strings.pick(
              'История подтверждённых pivots и событий отображается на графике. Более глубокий Structure Engine 2.0 остаётся отдельным этапом.',
              'Confirmed pivots and events are visible on the chart. A deeper Structure Engine 2.0 remains a separate phase.',
            ),
          ),
        ),
      ],
    );
  }
}

class _LevelsWorkspace extends StatelessWidget {
  const _LevelsWorkspace({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<_LevelRow> levels = <_LevelRow>[];
    for (final TimeframeAnalysis frame in <TimeframeAnalysis>[
      snapshot.fiveMinutes,
      snapshot.fifteenMinutes,
      snapshot.oneHour,
    ]) {
      if (frame.support != null) {
        levels.add(
          _LevelRow(
            type: strings.pick('Поддержка', 'Support'),
            zone: _price(frame.support!),
            timeframe: frame.name,
            bias: Bias.bullish,
          ),
        );
      }
      if (frame.resistance != null) {
        levels.add(
          _LevelRow(
            type: strings.pick('Сопротивление', 'Resistance'),
            zone: _price(frame.resistance!),
            timeframe: frame.name,
            bias: Bias.bearish,
          ),
        );
      }
      for (final PriceZone zone in frame.orderBlocks) {
        levels.add(
          _LevelRow(
            type: 'Order Block',
            zone: '${_price(zone.lower)}–${_price(zone.upper)}',
            timeframe: zone.timeframe,
            bias: zone.bias,
          ),
        );
      }
      for (final PriceZone zone in frame.fairValueGaps) {
        levels.add(
          _LevelRow(
            type: 'FVG',
            zone: '${_price(zone.lower)}–${_price(zone.upper)}',
            timeframe: zone.timeframe,
            bias: zone.bias,
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Уровни', 'Levels'),
          subtitle: strings.pick(
            'Поддержка, сопротивление, FVG и Order Blocks',
            'Support, resistance, FVG and Order Blocks',
          ),
          icon: Icons.horizontal_rule_rounded,
          trailing: ProductStatusChip(
            label:
                '${strings.pick('Магнит', 'Magnet')} ${_price(snapshot.magnetPrice)}',
            color: Theme.of(context).colorScheme.primary,
            icon: Icons.gps_fixed_rounded,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: <DataColumn>[
                DataColumn(label: Text(strings.pick('Тип', 'Type'))),
                DataColumn(
                  label: Text(strings.pick('Цена / зона', 'Price / Zone')),
                ),
                const DataColumn(label: Text('TF')),
                DataColumn(
                  label: Text(strings.pick('Направление', 'Direction')),
                ),
                DataColumn(label: Text(strings.pick('Сила', 'Strength'))),
                DataColumn(label: Text(strings.pick('Свежесть', 'Freshness'))),
                DataColumn(label: Text(strings.pick('Реакция', 'Reaction'))),
              ],
              rows: levels
                  .map<DataRow>(
                    (_LevelRow row) => DataRow(
                      onSelectChanged: (_) => _showLevel(context, row),
                      cells: <DataCell>[
                        DataCell(Text(row.type)),
                        DataCell(Text(row.zone)),
                        DataCell(Text(row.timeframe)),
                        DataCell(_BiasText(row.bias)),
                        const DataCell(Text('—')),
                        const DataCell(Text('LIVE')),
                        const DataCell(Text('—')),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ProductExpandableSection(
          title: 'Liquidity',
          icon: Icons.water_outlined,
          child: Text(
            '${strings.pick('Выше', 'Above')}: ${_nullablePrice(snapshot.fifteenMinutes.liquidity.above)} · '
            '${strings.pick('Ниже', 'Below')}: ${_nullablePrice(snapshot.fifteenMinutes.liquidity.below)} · '
            'Sweep ↑ ${snapshot.fifteenMinutes.liquidity.sweepAbove ? 'YES' : 'NO'} · '
            'Sweep ↓ ${snapshot.fifteenMinutes.liquidity.sweepBelow ? 'YES' : 'NO'}',
          ),
        ),
      ],
    );
  }

  Future<void> _showLevel(BuildContext context, _LevelRow row) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(row.type),
        content: Text(
          '${context.strings.pick('Цена / зона', 'Price / Zone')}: ${row.zone}\n'
          'TF: ${row.timeframe}\n'
          '${context.strings.pick('Направление', 'Direction')}: ${row.bias.label}',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.strings.close),
          ),
        ],
      ),
    );
  }
}

class _VolumeWorkspace extends StatelessWidget {
  const _VolumeWorkspace({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final List<TimeframeAnalysis> frames = <TimeframeAnalysis>[
      snapshot.oneMinute,
      snapshot.fiveMinutes,
      snapshot.fifteenMinutes,
      snapshot.oneHour,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Объём и индикаторы', 'Volume and Indicators'),
          subtitle: strings.pick(
            'Кластеры и Order Flow архитектурно подготовлены, но ещё не рассчитываются',
            'Clusters and Order Flow are prepared for a future data phase',
          ),
          icon: Icons.bar_chart_rounded,
        ),
        const SizedBox(height: 14),
        Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const <DataColumn>[
                DataColumn(label: Text('TF')),
                DataColumn(label: Text('RVOL'), numeric: true),
                DataColumn(label: Text('RSI'), numeric: true),
                DataColumn(label: Text('MACD'), numeric: true),
                DataColumn(label: Text('ATR'), numeric: true),
                DataColumn(label: Text('EMA20'), numeric: true),
                DataColumn(label: Text('EMA50'), numeric: true),
                DataColumn(label: Text('EMA200'), numeric: true),
              ],
              rows: frames
                  .map<DataRow>(
                    (TimeframeAnalysis frame) => DataRow(
                      cells: <DataCell>[
                        DataCell(Text(frame.name)),
                        DataCell(
                          Text('${frame.relativeVolume.toStringAsFixed(2)}x'),
                        ),
                        DataCell(Text(frame.rsi.toStringAsFixed(1))),
                        DataCell(Text(frame.macd.histogram.toStringAsFixed(6))),
                        DataCell(Text(_price(frame.atr))),
                        DataCell(Text(_price(frame.ema20))),
                        DataCell(Text(_price(frame.ema50))),
                        DataCell(Text(_price(frame.ema200))),
                      ],
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ProductExpandableSection(
          title: strings.pick('Order Flow / Кластеры', 'Order Flow / Clusters'),
          icon: Icons.view_module_outlined,
          child: Text(
            strings.pick(
              'Раздел зарезервирован для Volume Profile, Footprint, Heatmap и кластерных данных. Сейчас здесь не показываются вымышленные значения.',
              'Reserved for Volume Profile, Footprint, Heatmap and cluster data. No synthetic values are shown.',
            ),
          ),
        ),
      ],
    );
  }
}

class _SignalWorkspace extends StatelessWidget {
  const _SignalWorkspace({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSignal? raw = SignalEngine.createSignal(snapshot);
    final RadarSignal? execution = raw == null
        ? null
        : PhaseAEngine.preview(market: snapshot, signal: raw);
    final DecisionSnapshot decision = DecisionEngine.build(
      snapshot,
      executionSignal: execution,
    );
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = switch (decision.decision) {
      DecisionAction.long => semantic.bullish,
      DecisionAction.short => semantic.bearish,
      DecisionAction.wait => semantic.warning,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Текущий сигнал', 'Current Signal'),
          subtitle: strings.pick(
            'План и качество исполнения без изменения расчётов стратегии',
            'Plan and execution quality without strategy changes',
          ),
          icon: Icons.adjust_rounded,
          trailing: ProductStatusChip(
            label: decision.decision.label,
            color: color,
            icon: decision.decision == DecisionAction.wait
                ? Icons.schedule_rounded
                : Icons.bolt_rounded,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 28,
              runSpacing: 16,
              children: <Widget>[
                _SignalValue(label: 'Stage', value: decision.signalStage.code),
                _SignalValue(
                  label: 'Entry',
                  value:
                      '${_price(decision.entryLow)}–${_price(decision.entryHigh)}',
                ),
                _SignalValue(label: 'Stop', value: _price(decision.stop)),
                _SignalValue(label: 'TP1', value: _price(decision.tp1)),
                _SignalValue(label: 'TP2', value: _price(decision.tp2)),
                _SignalValue(
                  label: 'R:R',
                  value: decision.riskReward.toStringAsFixed(2),
                ),
                _SignalValue(
                  label: 'Direction',
                  value: '${decision.qualityScores.direction}/100',
                ),
                _SignalValue(
                  label: 'Entry Quality',
                  value: '${decision.qualityScores.entry}/100',
                ),
                _SignalValue(
                  label: 'Stop Quality',
                  value: '${decision.qualityScores.stop}/100',
                ),
                _SignalValue(
                  label: 'Risk Quality',
                  value: '${decision.qualityScores.risk}/100',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ProductExpandableSection(
          title: strings.pick(
            'Технические подтверждения',
            'Technical Confirmations',
          ),
          icon: Icons.fact_check_outlined,
          initiallyExpanded: true,
          child: Column(
            children: snapshot.confirmations
                .map<Widget>(
                  (ConfirmationItem item) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.name),
                    subtitle: Text(item.value),
                    trailing: _BiasText(item.bias),
                  ),
                )
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SignalValue extends StatelessWidget {
  const _SignalValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _BiasText extends StatelessWidget {
  const _BiasText(this.bias);

  final Bias bias;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = switch (bias) {
      Bias.bullish => semantic.bullish,
      Bias.bearish => semantic.bearish,
      Bias.neutral => semantic.neutral,
    };
    return Text(
      bias.label,
      style: TextStyle(color: color, fontWeight: FontWeight.w800),
    );
  }
}

class _LevelRow {
  const _LevelRow({
    required this.type,
    required this.zone,
    required this.timeframe,
    required this.bias,
  });

  final String type;
  final String zone;
  final String timeframe;
  final Bias bias;
}

class _WorkspaceLivePrice extends StatelessWidget {
  const _WorkspaceLivePrice({
    required this.symbol,
    required this.fallback,
    required this.livePrice,
  });

  final String symbol;
  final double fallback;
  final ValueListenable<LivePriceTick?>? livePrice;

  @override
  Widget build(BuildContext context) {
    final ValueListenable<LivePriceTick?>? listenable = livePrice;
    if (listenable == null) {
      return Text(
        '\$${_price(fallback)}',
        style: Theme.of(context).textTheme.titleMedium,
      );
    }
    return ValueListenableBuilder<LivePriceTick?>(
      valueListenable: listenable,
      builder: (BuildContext context, LivePriceTick? tick, Widget? child) {
        final double price = tick?.symbol == symbol ? tick!.price : fallback;
        return Text(
          '\$${_price(price)}',
          style: Theme.of(context).textTheme.titleMedium,
        );
      },
    );
  }
}

String _price(double value) {
  if (!value.isFinite || value == 0) return '—';
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _nullablePrice(double? value) => value == null ? '—' : _price(value);
