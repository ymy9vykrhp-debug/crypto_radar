import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engines/decision_engine.dart';
import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../localization/app_strings.dart';
import '../models/backtest_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/live_market_models.dart';
import '../models/market_models.dart';
import '../models/navigation_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class ProductDashboardScreen extends StatelessWidget {
  const ProductDashboardScreen({
    super.key,
    required this.snapshot,
    required this.journalController,
    required this.onWhy,
    required this.onOpenWorkspace,
    required this.onCalculateTrade,
    this.livePrice,
  });

  final MarketSnapshot snapshot;
  final JournalController journalController;
  final VoidCallback onWhy;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onCalculateTrade;
  final ValueListenable<LivePriceTick?>? livePrice;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSignal? rawSignal = SignalEngine.createSignal(snapshot);
    final RadarSignal? executionSignal = rawSignal == null
        ? null
        : PhaseAEngine.preview(market: snapshot, signal: rawSignal);
    final DecisionSnapshot decision = DecisionEngine.build(
      snapshot,
      executionSignal: executionSignal,
    );
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color decisionColor = switch (decision.decision) {
      DecisionAction.long => semantic.bullish,
      DecisionAction.short => semantic.bearish,
      DecisionAction.wait => semantic.warning,
    };

    return AnimatedBuilder(
      animation: journalController,
      builder: (BuildContext context, Widget? child) {
        final List<RadarSignal> symbolSignals = journalController.signals
            .where((RadarSignal signal) => signal.symbol == snapshot.symbol)
            .toList(growable: false);
        final JournalStatistics statistics = JournalStatistics.fromSignals(
          symbolSignals,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            _DecisionHero(
              snapshot: snapshot,
              decision: decision,
              color: decisionColor,
              onWhy: onWhy,
              onOpenWorkspace: onOpenWorkspace,
              livePrice: livePrice,
            ),
            const SizedBox(height: 14),
            _ActionAndPlan(
              decision: decision,
              color: decisionColor,
              strings: strings,
              onCalculateTrade: onCalculateTrade,
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final int columns = constraints.maxWidth >= 1180
                    ? 4
                    : constraints.maxWidth >= 700
                    ? 3
                    : 2;
                final double width =
                    (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _metric(
                      width,
                      strings.pick('Этап', 'Stage'),
                      decision.signalStage.code,
                      Icons.flag_outlined,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick('Сила сигнала', 'Signal Strength'),
                      '${decision.signalScore}/100',
                      Icons.speed_rounded,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество направления', 'Direction Quality'),
                      '${decision.qualityScores.direction}/100',
                      Icons.trending_up_rounded,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество входа', 'Entry Quality'),
                      '${decision.qualityScores.entry}/100',
                      Icons.login_rounded,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество зоны', 'Location Quality'),
                      '${decision.qualityScores.location}/100',
                      Icons.location_on_outlined,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick(
                        'Подтверждение ликвидности',
                        'Liquidity Confirmation',
                      ),
                      '${decision.qualityScores.liquidity}/100',
                      Icons.water_drop_outlined,
                      decisionColor,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество стопа', 'Stop Quality'),
                      '${decision.qualityScores.stop}/100',
                      Icons.health_and_safety_outlined,
                      decision.stopBuffer > 0
                          ? semantic.warning
                          : semantic.neutral,
                    ),
                    _metric(
                      width,
                      strings.pick('Режим рынка', 'Market Regime'),
                      decision.marketRegime.label,
                      Icons.public_rounded,
                      semantic.neutral,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество риска', 'Risk Quality'),
                      '${decision.qualityScores.risk}/100',
                      Icons.shield_outlined,
                      decision.qualityScores.risk >= 70
                          ? semantic.bullish
                          : semantic.warning,
                    ),
                    _metric(
                      width,
                      strings.pick('Стратегия', 'Strategy'),
                      decision.selectedStrategy,
                      Icons.route_outlined,
                      semantic.neutral,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество данных', 'Data Quality'),
                      decision.dataQuality.label,
                      Icons.fact_check_outlined,
                      decision.dataQuality == DataQuality.high
                          ? semantic.bullish
                          : semantic.warning,
                    ),
                    _metric(
                      width,
                      'Bid / Ask Spread',
                      snapshot.ticker.hasMicrostructure
                          ? '${snapshot.ticker.spreadPercent.toStringAsFixed(4)}%'
                          : '—',
                      Icons.swap_vert_circle_outlined,
                      snapshot.ticker.spreadPercent <= 0.08
                          ? semantic.bullish
                          : semantic.warning,
                    ),
                    _metric(
                      width,
                      'Funding',
                      '${snapshot.ticker.fundingRatePercent >= 0 ? '+' : ''}${snapshot.ticker.fundingRatePercent.toStringAsFixed(4)}%',
                      Icons.payments_outlined,
                      semantic.neutral,
                    ),
                    _metric(
                      width,
                      'Open Interest',
                      _compactNumber(
                        snapshot.ticker.openInterestValue > 0
                            ? snapshot.ticker.openInterestValue
                            : snapshot.ticker.openInterest,
                      ),
                      Icons.stacked_line_chart_rounded,
                      semantic.neutral,
                    ),
                    _metric(
                      width,
                      'Mark / Index',
                      snapshot.ticker.markPrice > 0
                          ? '${_price(snapshot.ticker.markPrice)} / ${_price(snapshot.ticker.indexPrice)}'
                          : '—',
                      Icons.balance_outlined,
                      semantic.neutral,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 960;
                final List<Widget> panels = <Widget>[
                  _CompactSummary(
                    title: strings.pick('Структура', 'Structure'),
                    icon: Icons.account_tree_outlined,
                    lines: <String>[
                      '5m ${snapshot.fiveMinutes.structure.highLabel}/${snapshot.fiveMinutes.structure.lowLabel}',
                      '15m BOS ${snapshot.fifteenMinutes.structure.bos.label}',
                      '15m CHOCH ${snapshot.fifteenMinutes.structure.choch.label}',
                    ],
                  ),
                  _CompactSummary(
                    title: strings.pick('Тяжёлый уровень', 'Heavy Level'),
                    icon: Icons.horizontal_rule_rounded,
                    lines: <String>[
                      '${snapshot.magnetLabel}: ${_price(snapshot.magnetPrice)}',
                      '${strings.pick('Поддержка', 'Support')}: ${_nullablePrice(snapshot.fifteenMinutes.support)}',
                      '${strings.pick('Сопротивление', 'Resistance')}: ${_nullablePrice(snapshot.fifteenMinutes.resistance)}',
                    ],
                  ),
                  _CompactSummary(
                    title: strings.pick('Текущий сетап', 'Current Setup'),
                    icon: Icons.adjust_rounded,
                    lines: <String>[
                      decision.entryDecision.label,
                      decision.executionAction.isEmpty
                          ? strings.pick(
                              'Сетап не сформирован',
                              'No setup formed',
                            )
                          : decision.executionAction,
                      'R:R ${decision.riskReward.toStringAsFixed(2)}',
                    ],
                  ),
                  _CompactSummary(
                    title: strings.pick('Новости', 'News'),
                    icon: Icons.article_outlined,
                    lines: <String>[
                      'Risk: ${decision.newsRisk}',
                      strings.pick(
                        'Фильтр новостей пока не подключён',
                        'News filter is not connected yet',
                      ),
                    ],
                  ),
                  _CompactSummary(
                    title: strings.pick('Журнал', 'Journal'),
                    icon: Icons.menu_book_outlined,
                    lines: <String>[
                      '${strings.pick('Сигналы', 'Signals')}: ${statistics.signals}',
                      '${strings.pick('Сделки', 'Trades')}: ${statistics.trades}',
                      'Win rate ${statistics.winRate.toStringAsFixed(1)}%',
                    ],
                  ),
                ];
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: panels
                        .map<Widget>(
                          (Widget panel) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: panel,
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                }
                return Column(
                  children: panels
                      .map<Widget>(
                        (Widget panel) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: panel,
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _metric(
    double width,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return SizedBox(
      width: width,
      height: 105,
      child: ProductMetricCard(
        label: label,
        value: value,
        icon: icon,
        color: color,
      ),
    );
  }
}

class _DecisionHero extends StatelessWidget {
  const _DecisionHero({
    required this.snapshot,
    required this.decision,
    required this.color,
    required this.onWhy,
    required this.onOpenWorkspace,
    required this.livePrice,
  });

  final MarketSnapshot snapshot;
  final DecisionSnapshot decision;
  final Color color;
  final VoidCallback onWhy;
  final VoidCallback onOpenWorkspace;
  final ValueListenable<LivePriceTick?>? livePrice;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 230),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  snapshot.symbol,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                _LivePriceText(
                  symbol: snapshot.symbol,
                  fallback: snapshot.ticker.price,
                  livePrice: livePrice,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  '24h ${snapshot.ticker.change24hPercent >= 0 ? '+' : ''}${snapshot.ticker.change24hPercent.toStringAsFixed(2)}%',
                  style: TextStyle(
                    color: snapshot.ticker.change24hPercent >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                decision.decision.label,
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.w900),
              ),
              Text(
                decision.entryDecision.label,
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton.icon(
                onPressed: onWhy,
                icon: const Icon(Icons.help_outline_rounded),
                label: Text(strings.workspaceSection(WorkspaceSection.why)),
              ),
              OutlinedButton.icon(
                onPressed: onOpenWorkspace,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(strings.pick('Открыть рынок', 'Open market')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionAndPlan extends StatelessWidget {
  const _ActionAndPlan({
    required this.decision,
    required this.color,
    required this.strings,
    required this.onCalculateTrade,
  });

  final DecisionSnapshot decision;
  final Color color;
  final AppStrings strings;
  final VoidCallback onCalculateTrade;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Что делать сейчас', 'Action Now'),
              icon: Icons.bolt_rounded,
              trailing: ProductStatusChip(
                label: decision.entryDecision.label,
                color: color,
                icon: Icons.adjust_rounded,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              decision.executionAction.isEmpty
                  ? strings.pick(
                      'Ждать формирования подтверждённого сетапа.',
                      'Wait for a confirmed setup to form.',
                    )
                  : decision.executionAction,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 20,
              runSpacing: 10,
              children: <Widget>[
                _PlanValue(
                  label: 'Entry',
                  value:
                      '${_price(decision.entryLow)}–${_price(decision.entryHigh)}',
                ),
                _PlanValue(label: 'Stop', value: _price(decision.stop)),
                _PlanValue(label: 'TP1', value: _price(decision.tp1)),
                _PlanValue(label: 'TP2', value: _price(decision.tp2)),
                _PlanValue(
                  label: 'R:R',
                  value: decision.riskReward.toStringAsFixed(2),
                ),
                _PlanValue(
                  label: strings.pick('Магнит', 'Magnet'),
                  value: _price(decision.priceMagnet),
                ),
                _PlanValue(
                  label: strings.pick('Ожидаемый ход', 'Expected Move'),
                  value: '${decision.expectedMovePercent.toStringAsFixed(2)}%',
                ),
                _PlanValue(
                  label: strings.pick('Плечо', 'Leverage'),
                  value: '${decision.leverage}x',
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              key: const ValueKey<String>('smart-position-calculator-button'),
              onPressed: onCalculateTrade,
              icon: const Icon(Icons.calculate_rounded),
              label: Text(
                strings.pick('💰 Рассчитать сделку', '💰 Calculate position'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanValue extends StatelessWidget {
  const _PlanValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _CompactSummary extends StatelessWidget {
  const _CompactSummary({
    required this.title,
    required this.icon,
    required this.lines,
  });

  final String title;
  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...lines.map<Widget>(
              (String line) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivePriceText extends StatelessWidget {
  const _LivePriceText({
    required this.symbol,
    required this.fallback,
    required this.livePrice,
    required this.style,
  });

  final String symbol;
  final double fallback;
  final ValueListenable<LivePriceTick?>? livePrice;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ValueListenable<LivePriceTick?>? listenable = livePrice;
    if (listenable == null) {
      return Text('\$${_price(fallback)}', style: style);
    }
    return ValueListenableBuilder<LivePriceTick?>(
      valueListenable: listenable,
      builder: (BuildContext context, LivePriceTick? tick, Widget? child) {
        final double price = tick?.symbol == symbol ? tick!.price : fallback;
        return Text('\$${_price(price)}', style: style);
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

String _compactNumber(double value) {
  if (!value.isFinite || value <= 0) return '—';
  if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(2)}B';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(2)}K';
  return value.toStringAsFixed(2);
}
