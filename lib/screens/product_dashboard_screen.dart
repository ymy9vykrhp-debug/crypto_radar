import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../engines/entry_readiness_gate.dart';
import '../localization/app_strings.dart';
import '../models/backtest_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/integration_models.dart';
import '../models/live_market_models.dart';
import '../models/market_models.dart';
import '../models/navigation_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../services/app_preferences_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class ProductDashboardScreen extends StatelessWidget {
  const ProductDashboardScreen({
    super.key,
    required this.snapshot,
    required this.decision,
    required this.readiness,
    required this.journalController,
required this.preferences,
    required this.onWhy,
    required this.onOpenWorkspace,
    required this.onCalculateTrade,
    this.onRefresh,
    this.livePrice,
    this.notificationStatus,
    this.notificationsEnabled = false,
  });

  final MarketSnapshot snapshot;
  final DecisionSnapshot decision;
  final EntryReadinessResult readiness;
  final JournalController journalController;
final AppPreferencesController preferences;
  final VoidCallback onWhy;
  final VoidCallback onOpenWorkspace;
  final VoidCallback onCalculateTrade;
  final VoidCallback? onRefresh;
  final ValueListenable<LivePriceTick?>? livePrice;
  final IntegrationStatus? notificationStatus;
  final bool notificationsEnabled;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
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
              snapshot: snapshot,
              decision: decision,
              readiness: readiness,
              strings: strings,
              onWhy: onWhy,
              onRefresh: onRefresh,
              onCalculateTrade: onCalculateTrade,
              notificationStatus: notificationStatus,
              notificationsEnabled: notificationsEnabled,
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
                      focusHighlight: true,
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
                      focusHighlight: true,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество зоны', 'Location Quality'),
                      '${decision.qualityScores.location}/100',
                      Icons.location_on_outlined,
                      decisionColor,
                      focusHighlight: true,
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
                      focusHighlight: true,
                    ),
                    _metric(
                      width,
                      strings.pick('Качество стопа', 'Stop Quality'),
                      '${decision.qualityScores.stop}/100',
                      Icons.health_and_safety_outlined,
                      decision.stopBuffer > 0
                          ? semantic.warning
                          : semantic.neutral,
                      focusHighlight: true,
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
                      focusHighlight: true,
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
                      focusHighlight: true,
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
                    focusHighlight: true,
                  ),
                  _CompactSummary(
                    title: strings.pick('Тяжёлый уровень', 'Heavy Level'),
                    icon: Icons.horizontal_rule_rounded,
                    lines: <String>[
                      '${snapshot.magnetLabel}: ${_price(snapshot.magnetPrice)}',
                      '${strings.pick('Поддержка', 'Support')}: ${_nullablePrice(snapshot.fifteenMinutes.support)}',
                      '${strings.pick('Сопротивление', 'Resistance')}: ${_nullablePrice(snapshot.fifteenMinutes.resistance)}',
                    ],
                    focusHighlight: true,
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
                      'Net R:R ${readiness.netRiskReward.toStringAsFixed(2)}',
                    ],
                    focusHighlight: true,
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
    Color color, {
    bool focusHighlight = false,
  }) {
    return SizedBox(
      width: width,
      height: 88,
      child: ProductMetricCard(
        label: label,
        value: value,
        icon: icon,
        color: color,
        focusHighlight: focusHighlight,
      ),
    );
  }
}

class _FocusLegend extends StatelessWidget {
  const _FocusLegend({required this.strings});

  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.center_focus_strong_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              strings.pick(
                'Яркая зелёная рамка — главный показатель для решения. Цвет числа показывает его реальное качество.',
                'A bright green border marks a key decision metric. The number color still shows its real quality.',
              ),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
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
    required this.snapshot,
    required this.decision,
    required this.readiness,
    required this.strings,
    required this.onWhy,
    required this.onRefresh,
    required this.onCalculateTrade,
    required this.notificationStatus,
    required this.notificationsEnabled,
  });

  final MarketSnapshot snapshot;
  final DecisionSnapshot decision;
  final EntryReadinessResult readiness;
  final AppStrings strings;
  final VoidCallback onWhy;
  final VoidCallback? onRefresh;
  final VoidCallback onCalculateTrade;
  final IntegrationStatus? notificationStatus;
  final bool notificationsEnabled;

  @override
  Widget build(BuildContext context) {
    final Color focusColor = Theme.of(context).colorScheme.primary;
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final bool hardBlocked = readiness.hardBlocked;
    final bool entryConfirmed = readiness.entryConfirmed;
    final bool entryReady = readiness.entryReady;
    final bool priceInZone = readiness.priceInZone;
    final bool liquidityReady = readiness.liquidityReady;
    final bool riskReady = readiness.riskReady;
    final Color actionColor = hardBlocked
        ? semantic.bearish
        : entryReady
        ? semantic.bullish
        : semantic.warning;
    final String actionTitle = hardBlocked
        ? strings.pick('НЕ ВХОДИТЬ', 'DO NOT ENTER')
        : entryReady
        ? strings.pick('ВХОД РАЗРЕШЁН', 'ENTRY READY')
        : strings.pick('ЖДАТЬ', 'WAIT');
    final String statusLabel = readiness.status.code;
    final DateTime sourceUpdatedAt =
        snapshot.ticker.sourceUpdatedAt ?? snapshot.updatedAt;
    final String dataAge = _dataAgeLabel(sourceUpdatedAt, strings);
    final String entryDistance = _entryDistanceLabel(decision, strings);
    final List<_DecisionCheck> checks = <_DecisionCheck>[
      _DecisionCheck(
        label: strings.pick('Рыночные данные', 'Market data'),
        detail: '${decision.dataQuality.label} · $dataAge',
        passed: readiness.marketDataReady,
        critical: true,
      ),
      _DecisionCheck(
        label: 'Bid/Ask + ${strings.pick('правила биржи', 'exchange rules')}',
        detail:
            '${snapshot.dataIntegrity.hasFreshBidAsk ? 'Bid/Ask OK' : 'Bid/Ask STALE'} · '
            '${snapshot.dataIntegrity.hasInstrumentRules ? 'RULES OK' : 'RULES MISSING'}',
        passed: readiness.microstructureReady,
        critical: true,
      ),
      _DecisionCheck(
        label: strings.pick('Цена в Entry Zone', 'Price in Entry Zone'),
        detail: entryDistance,
        passed: priceInZone,
      ),
      _DecisionCheck(
        label: strings.pick('Подтверждение входа', 'Entry confirmation'),
        detail: decision.signalStage.code,
        passed: entryConfirmed,
      ),
      _DecisionCheck(
        label: strings.pick(
          'Подтверждение ликвидности',
          'Liquidity confirmation',
        ),
        detail:
            '${decision.qualityScores.liquidity}/100${decision.liquiditySweepConfirmed ? ' · SWEEP' : ''}',
        passed: liquidityReady,
      ),
      _DecisionCheck(
        label: strings.pick('Stop и риск', 'Stop and risk'),
        detail:
            'Stop ${decision.qualityScores.stop}/100 · Risk ${decision.qualityScores.risk}/100 · Net R:R ${readiness.netRiskReward.toStringAsFixed(2)}',
        passed: riskReady,
        critical: true,
      ),
      _DecisionCheck(
        label: strings.pick('Структурная цель ≥ 1%', 'Structural target ≥ 1%'),
        detail:
            '${readiness.targetMovePercent.toStringAsFixed(2)}% · ${readiness.structuralTargetReady ? 'STRUCTURE OK' : 'NO STRUCTURAL TARGET'}',
        passed:
            readiness.structuralTargetReady &&
            readiness.targetMovePercent >= 1.0,
        critical: true,
      ),
      _DecisionCheck(
        label: strings.pick('Контекст BTC / рынка', 'BTC / market context'),
        detail: readiness.marketContextReady
            ? 'NO CRITICAL CONFLICT'
            : 'MARKET CONFLICT / CONTEXT MISSING',
        passed: readiness.marketContextReady,
        critical: true,
      ),
    ];
    return Card(
      color: Color.alphaBlend(
        focusColor.withValues(alpha: 0.07),
        Theme.of(context).colorScheme.surface,
      ),
      elevation: 4,
      shadowColor: focusColor.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: focusColor, width: 2.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Что делать сейчас', 'Action Now'),
              icon: Icons.bolt_rounded,
              trailing: ProductStatusChip(
                label: statusLabel,
                color: actionColor,
                icon: Icons.adjust_rounded,
              ),
            ),
            if (notificationStatus != null) ...<Widget>[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ProductStatusChip(
                  label: notificationsEnabled
                      ? 'Telegram: ${notificationStatus!.message}'
                      : 'Telegram: OFF',
                  color: _notificationColor(semantic),
                  icon: Icons.notifications_active_outlined,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              actionTitle,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: actionColor, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              decision.executionAction.isEmpty
                  ? strings.pick(
                      'Ждём формирования подтверждённого сетапа.',
                      'Waiting for a confirmed setup to form.',
                    )
                  : decision.executionAction,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget checklist = _DecisionChecklist(
                  strings: strings,
                  checks: checks,
                );
                final Widget plan = _PlanPreview(
                  decision: decision,
                  readiness: readiness,
                  strings: strings,
                  hardBlocked: hardBlocked,
                  provisional: !entryReady,
                  entryDistance: entryDistance,
                  dataAge: dataAge,
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      checklist,
                      const SizedBox(height: 14),
                      plan,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 4, child: checklist),
                    const SizedBox(width: 18),
                    Expanded(flex: 6, child: plan),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  key: const ValueKey<String>(
                    'smart-position-calculator-button',
                  ),
                  onPressed: hardBlocked ? null : onCalculateTrade,
                  icon: Icon(
                    hardBlocked
                        ? Icons.lock_outline_rounded
                        : Icons.calculate_rounded,
                  ),
                  label: Text(
                    hardBlocked
                        ? strings.pick(
                            'Расчёт заблокирован',
                            'Calculation blocked',
                          )
                        : strings.pick(
                            '💰 Рассчитать сделку',
                            '💰 Calculate position',
                          ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.pick('Обновить данные', 'Refresh data')),
                ),
                OutlinedButton.icon(
                  onPressed: onWhy,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: Text(strings.pick('Почему?', 'Why?')),
                ),
              ],
            ),
            if (hardBlocked) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                strings.pick(
                  'Предварительные уровни показаны только для наблюдения. Это не разрешение на вход, пока критические проверки не пройдены.',
                  'Preview levels are for observation only. They are not an entry permission until the critical checks pass.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: semantic.bearish,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _notificationColor(RadarSemanticColors semantic) {
    if (!notificationsEnabled) return semantic.neutral;
    return switch (notificationStatus?.state) {
      IntegrationConnectionState.connected => semantic.bullish,
      IntegrationConnectionState.checking => semantic.warning,
      IntegrationConnectionState.disabled => semantic.neutral,
      IntegrationConnectionState.notConfigured ||
      IntegrationConnectionState.unavailable ||
      null => semantic.bearish,
    };
  }
}

class _DecisionCheck {
  const _DecisionCheck({
    required this.label,
    required this.detail,
    required this.passed,
    this.critical = false,
  });

  final String label;
  final String detail;
  final bool passed;
  final bool critical;
}

class _DecisionChecklist extends StatelessWidget {
  const _DecisionChecklist({required this.strings, required this.checks});

  final AppStrings strings;
  final List<_DecisionCheck> checks;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
  children: <Widget>[
    Expanded(
      child: Text(
        strings.pick('ПРОВЕРКА ПЕРЕД ВХОДОМ', 'PRE-ENTRY CHECK'),
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontWeight: FontWeight.w900),
      ),
    ),
    IconButton(
      tooltip: strings.pick('Настроить проверки', 'Configure checks'),
      icon: const Icon(Icons.settings_rounded),
      onPressed: () {},
    ),
  ],
),
          const SizedBox(height: 9),
          ...checks.map<Widget>((_DecisionCheck check) {
            final Color checkColor = check.passed
                ? semantic.bullish
                : check.critical
                ? semantic.bearish
                : semantic.warning;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    check.passed
                        ? Icons.check_circle_rounded
                        : check.critical
                        ? Icons.cancel_rounded
                        : Icons.schedule_rounded,
                    size: 18,
                    color: checkColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          check.label,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          check.detail,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlanPreview extends StatelessWidget {
  const _PlanPreview({
    required this.decision,
    required this.readiness,
    required this.strings,
    required this.hardBlocked,
    required this.provisional,
    required this.entryDistance,
    required this.dataAge,
  });

  final DecisionSnapshot decision;
  final EntryReadinessResult readiness;
  final AppStrings strings;
  final bool hardBlocked;
  final bool provisional;
  final String entryDistance;
  final String dataAge;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = hardBlocked
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withValues(alpha: hardBlocked ? 0.55 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  strings.pick('ТОРГОВЫЙ ПЛАН', 'TRADE PLAN'),
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              ProductStatusChip(
                label: provisional ? 'PREVIEW' : 'READY',
                color: statusColor,
                icon: provisional
                    ? Icons.visibility_outlined
                    : Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Opacity(
            opacity: hardBlocked ? 0.58 : 1.0,
            child: Wrap(
              spacing: 20,
              runSpacing: 12,
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
                  label: 'Net R:R',
                  value: readiness.netRiskReward.isFinite
                      ? readiness.netRiskReward.toStringAsFixed(2)
                      : '—',
                ),
                _PlanValue(
                  label: strings.pick('Магнит', 'Magnet'),
                  value: _price(decision.priceMagnet),
                ),
                _PlanValue(
                  label: strings.pick('Ожидаемый ход', 'Expected Move'),
                  value: '${readiness.targetMovePercent.toStringAsFixed(2)}%',
                ),
                _PlanValue(
                  label: strings.pick('Плечо', 'Leverage'),
                  value: '${decision.leverage}x',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
 
          Wrap(
            spacing: 18,
            runSpacing: 7,
            children: <Widget>[
              _InlineFact(
                icon: Icons.social_distance_rounded,
                label: strings.pick('До Entry', 'To Entry'),
                value: entryDistance,
              ),
              _InlineFact(
                icon: Icons.schedule_rounded,
                label: strings.pick('Свежесть', 'Freshness'),
                value: dataAge,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineFact extends StatelessWidget {
  const _InlineFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Text('$label: ', style: Theme.of(context).textTheme.labelMedium),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
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
    this.focusHighlight = false,
  });

  final String title;
  final IconData icon;
  final List<String> lines;
  final bool focusHighlight;

  @override
  Widget build(BuildContext context) {
    final Color focusColor = Theme.of(context).colorScheme.primary;
    return Card(
      color: focusHighlight
          ? Color.alphaBlend(
              focusColor.withValues(alpha: 0.07),
              Theme.of(context).colorScheme.surface,
            )
          : null,
      elevation: focusHighlight ? 4 : 0,
      shadowColor: focusHighlight ? focusColor.withValues(alpha: 0.55) : null,
      shape: focusHighlight
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: focusColor, width: 2.2),
            )
          : null,
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

String _dataAgeLabel(DateTime? timestamp, AppStrings strings) {
  if (timestamp == null) {
    return strings.pick('время неизвестно', 'time unknown');
  }
  Duration age = DateTime.now().toUtc().difference(timestamp.toUtc());
  if (age.isNegative) age = Duration.zero;
  final String ageText;
  if (age.inSeconds < 60) {
    ageText = '${age.inSeconds}${strings.pick('с', 's')}';
  } else if (age.inMinutes < 60) {
    ageText = '${age.inMinutes}${strings.pick('м', 'm')}';
  } else if (age.inHours < 24) {
    ageText = '${age.inHours}${strings.pick('ч', 'h')}';
  } else {
    ageText = '${age.inDays}${strings.pick('д', 'd')}';
  }
  final DateTime local = timestamp.toLocal();
  final String clock =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}:'
      '${local.second.toString().padLeft(2, '0')}';
  return '$clock · $ageText ${strings.pick('назад', 'ago')}';
}

String _entryDistanceLabel(DecisionSnapshot decision, AppStrings strings) {
  if (decision.price <= 0 ||
      decision.entryLow <= 0 ||
      decision.entryHigh < decision.entryLow) {
    return strings.pick('зона не рассчитана', 'zone unavailable');
  }
  if (decision.price >= decision.entryLow &&
      decision.price <= decision.entryHigh) {
    return strings.pick('цена внутри зоны', 'price is inside the zone');
  }
  final bool below = decision.price < decision.entryLow;
  final double boundary = below ? decision.entryLow : decision.entryHigh;
  final double percent =
      (boundary - decision.price).abs() / decision.price * 100;
  return '${percent.toStringAsFixed(3)}% ${below ? strings.pick('ниже зоны', 'below zone') : strings.pick('выше зоны', 'above zone')}';
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
