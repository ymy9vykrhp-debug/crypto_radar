import 'package:flutter/material.dart';

import '../engines/position_calculator.dart';
import '../localization/app_strings.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import '../services/app_preferences_controller.dart';
import '../theme/app_theme.dart';
import 'product_components.dart';

class SmartPositionCalculatorDialog extends StatefulWidget {
  const SmartPositionCalculatorDialog({
    super.key,
    required this.initialInput,
    required this.preferences,
  });

  final SmartPositionInput initialInput;
  final AppPreferencesController preferences;

  @override
  State<SmartPositionCalculatorDialog> createState() =>
      _SmartPositionCalculatorDialogState();
}

class _SmartPositionCalculatorDialogState
    extends State<SmartPositionCalculatorDialog> {
  late final TextEditingController _margin;
  late final TextEditingController _customRisk;
  late final TextEditingController _entry;
  late final TextEditingController _stop;
  late final TextEditingController _tp1;
  late final TextEditingController _tp2;
  late final TextEditingController _tp3;
  late final TextEditingController _targetMove;
  late RiskPreset _riskPreset;

  @override
  void initState() {
    super.initState();
    final SmartPositionInput input = widget.initialInput;
    _riskPreset = widget.preferences.riskPreset;
    _margin = TextEditingController(text: _number(input.allocatedMargin, 2));
    _customRisk = TextEditingController(
      text: _number(widget.preferences.customRiskPercent, 2),
    );
    _entry = TextEditingController(text: _price(input.entry));
    _stop = TextEditingController(text: _price(input.stop));
    _tp1 = TextEditingController(text: _price(input.tp1));
    _tp2 = TextEditingController(text: _price(input.tp2));
    _tp3 = TextEditingController(
      text: input.tp3 == null ? '' : _price(input.tp3!),
    );
    _targetMove = TextEditingController(
      text: _number(input.targetMovePercent, 2),
    );
  }

  @override
  void dispose() {
    _margin.dispose();
    _customRisk.dispose();
    _entry.dispose();
    _stop.dispose();
    _tp1.dispose();
    _tp2.dispose();
    _tp3.dispose();
    _targetMove.dispose();
    super.dispose();
  }

  double get _riskPercent => _riskPreset == RiskPreset.custom
      ? _parse(_customRisk.text)
      : _riskPreset.defaultPercent;

  SmartPositionInput get _input {
    final double? tp3 = _parseNullable(_tp3.text);
    return widget.initialInput.copyWith(
      allocatedMargin: _parse(_margin.text),
      riskPercent: _riskPercent,
      entry: _parse(_entry.text),
      stop: _parse(_stop.text),
      tp1: _parse(_tp1.text),
      tp2: _parse(_tp2.text),
      tp3: tp3,
      clearTp3: tp3 == null,
      targetMovePercent: _parse(_targetMove.text),
    );
  }

  void _recalculate([String? _]) => setState(() {});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final SmartPositionInput input = _input;
    final SmartTradePlan plan = PositionCalculator.calculate(
      input: input,
      feeModel: widget.preferences.feeModel,
    );
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color sideColor = input.direction.name == 'long'
        ? semantic.bullish
        : semantic.bearish;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080, maxHeight: 900),
        child: Column(
          children: <Widget>[
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 13, 8, 13),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.calculate_rounded, color: sideColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            '${input.symbol} — ${input.direction.label}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: sideColor,
                                ),
                          ),
                          Text(
                            'Smart Position Calculator · MONITOR ONLY',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _SafetyChip(status: plan.safetyStatus),
                    IconButton(
                      tooltip: strings.close,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _SetupSummary(input: input),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final bool twoColumns = constraints.maxWidth >= 760;
                            final Widget controls = _inputControls(
                              context,
                              plan,
                            );
                            final Widget recommendation = _recommendation(
                              context,
                              plan,
                              input,
                            );
                            if (!twoColumns) {
                              return Column(
                                children: <Widget>[
                                  controls,
                                  const SizedBox(height: 12),
                                  recommendation,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(child: controls),
                                const SizedBox(width: 12),
                                Expanded(child: recommendation),
                              ],
                            );
                          },
                    ),
                    const SizedBox(height: 12),
                    _stopCard(context, plan),
                    const SizedBox(height: 12),
                    _targetsCard(context, plan),
                    const SizedBox(height: 12),
                    _targetMoveCard(context, plan),
                    const SizedBox(height: 12),
                    _whyCard(context, plan),
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          strings.pick(
                            'Только расчёт и анализ. Ордер не создаётся. Ликвидационная дистанция приблизительная; Funding и данные конкретного аккаунта пока не подключены.',
                            'Calculation and analysis only. No order is created. Liquidation distance is approximate; funding and account-specific data are not connected.',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputControls(BuildContext context, SmartTradePlan plan) {
    final AppStrings strings = context.strings;
    return _CalculatorSection(
      title: strings.pick('МОЯ СУММА И ПЛАН', 'MY AMOUNT AND PLAN'),
      icon: Icons.edit_note_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _NumberField(
            key: const ValueKey<String>('position-margin-field'),
            controller: _margin,
            label: strings.pick('Маржа для сделки', 'Allocated margin'),
            suffix: 'USDT',
            onChanged: _recalculate,
          ),
          const SizedBox(height: 10),
          Text(
            strings.pick('Максимально допустимый риск', 'Maximum allowed risk'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: RiskPreset.values
                .map<Widget>(
                  (RiskPreset preset) => ChoiceChip(
                    selected: _riskPreset == preset,
                    label: Text(_riskShortLabel(preset)),
                    onSelected: (_) => setState(() => _riskPreset = preset),
                  ),
                )
                .toList(growable: false),
          ),
          if (_riskPreset == RiskPreset.custom) ...<Widget>[
            const SizedBox(height: 8),
            _NumberField(
              controller: _customRisk,
              label: strings.pick('Свой риск', 'Custom risk'),
              suffix: '%',
              onChanged: _recalculate,
            ),
          ],
          const SizedBox(height: 8),
          _InfoLine(
            label: strings.pick(
              'Максимальный убыток по плану',
              'Maximum planned loss',
            ),
            value: _money(plan.maxLoss),
            emphasized: true,
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _NumberField(
                key: const ValueKey<String>('position-entry-field'),
                controller: _entry,
                label: 'Entry',
                onChanged: _recalculate,
                width: 145,
              ),
              _NumberField(
                key: const ValueKey<String>('position-stop-field'),
                controller: _stop,
                label: 'Structural Stop',
                onChanged: _recalculate,
                width: 145,
              ),
              _NumberField(
                key: const ValueKey<String>('position-tp1-field'),
                controller: _tp1,
                label: 'TP1',
                onChanged: _recalculate,
                width: 145,
              ),
              _NumberField(
                key: const ValueKey<String>('position-tp2-field'),
                controller: _tp2,
                label: 'TP2',
                onChanged: _recalculate,
                width: 145,
              ),
              _NumberField(
                key: const ValueKey<String>('position-tp3-field'),
                controller: _tp3,
                label: 'TP3 · optional',
                onChanged: _recalculate,
                width: 145,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.pick(
              'Исходная Entry Zone: ${_price(widget.initialInput.entryZoneLow)}–${_price(widget.initialInput.entryZoneHigh)}. Ручные изменения не двигают структурные уровни Decision Engine.',
              'Original Entry Zone: ${_price(widget.initialInput.entryZoneLow)}–${_price(widget.initialInput.entryZoneHigh)}. Manual edits do not change Decision Engine structural levels.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _recommendation(
    BuildContext context,
    SmartTradePlan plan,
    SmartPositionInput input,
  ) {
    final AppStrings strings = context.strings;
    return _CalculatorSection(
      title: strings.pick('РЕКОМЕНДАЦИЯ', 'RECOMMENDATION'),
      icon: Icons.health_and_safety_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            strings.pick('РЕКОМЕНДУЕМОЕ ПЛЕЧО', 'RECOMMENDED LEVERAGE'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          Text(
            plan.leverage <= 0 ? '—' : '${plan.leverage}x',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: _statusColor(context, plan.safetyStatus),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _LeverageTile(
                  label: '🟢 SAFE',
                  value: '${plan.leverageSafety.safeLeverage}x',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LeverageTile(
                  label: '🟡 AGGRESSIVE',
                  value: '${plan.leverageSafety.aggressiveLeverage}x',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _LeverageTile(
                  label: '🔴 BLOCKED',
                  value: '${plan.leverageSafety.dangerousFromLeverage}x+',
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _InfoLine(
            label: strings.pick('Расчётное плечо', 'Calculated leverage'),
            value:
                '${plan.leverageSafety.calculatedLeverage.toStringAsFixed(2)}x',
          ),
          _InfoLine(
            label: 'Safety limit',
            value: '${plan.leverageSafety.safetyLimit}x',
          ),
          _InfoLine(
            label: strings.pick('Размер позиции', 'Position notional'),
            value: _money(plan.positionNotional),
            emphasized: true,
          ),
          _InfoLine(
            label: strings.pick('Количество', 'Quantity'),
            value: '≈ ${_quantity(plan.quantity)} ${_baseCoin(input.symbol)}',
          ),
          _InfoLine(
            label: strings.pick(
              'Оценочный запас до ликвидации',
              'Estimated liquidation buffer',
            ),
            value:
                '${plan.leverageSafety.estimatedLiquidationDistancePercent.toStringAsFixed(2)}%',
          ),
        ],
      ),
    );
  }

  Widget _stopCard(BuildContext context, SmartTradePlan plan) {
    final AppStrings strings = context.strings;
    final StopOutcome stop = plan.stopOutcome;
    return _CalculatorSection(
      title: strings.pick('ЕСЛИ СРАБОТАЕТ STOP', 'IF STOP IS HIT'),
      icon: Icons.gpp_bad_outlined,
      child: Column(
        children: <Widget>[
          _InfoLine(
            label: strings.pick('Движение цены', 'Price move'),
            value: '-${stop.distancePercent.toStringAsFixed(3)}%',
          ),
          _InfoLine(
            label: strings.pick('Убыток от движения', 'Movement loss'),
            value: '-${_money(stop.movementLoss)}',
          ),
          _InfoLine(
            label: strings.pick('Комиссии вход + выход', 'Entry + exit fees'),
            value: '-${_money(stop.costs.fees)}',
          ),
          _InfoLine(
            label: 'Spread + Slippage',
            value: '-${_money(stop.costs.spread + stop.costs.slippage)}',
          ),
          _InfoLine(
            label: 'Safety buffer',
            value: '-${_money(stop.costs.safetyBuffer)}',
          ),
          const Divider(height: 18),
          _InfoLine(
            label: strings.pick(
              'Итоговый ожидаемый убыток',
              'Total expected loss',
            ),
            value: '-${_money(stop.expectedLoss)}',
            emphasized: true,
          ),
          _InfoLine(
            label: strings.pick('Лимит риска', 'Risk limit'),
            value: _money(plan.maxLoss),
          ),
        ],
      ),
    );
  }

  Widget _targetsCard(BuildContext context, SmartTradePlan plan) {
    final AppStrings strings = context.strings;
    return _CalculatorSection(
      title: strings.pick('ЦЕЛИ И NET R:R', 'TARGETS AND NET R:R'),
      icon: Icons.flag_outlined,
      child: Column(
        children: <Widget>[
          ...plan.targets.map<Widget>(
            (TargetOutcome target) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TargetTile(target: target),
            ),
          ),
          const Divider(height: 16),
          _InfoLine(
            label: 'Raw R:R · TP2',
            value: '1:${plan.rawRiskReward.toStringAsFixed(2)}',
          ),
          _InfoLine(
            label: 'Net R:R after costs · TP2',
            value: '1:${plan.netRiskReward.toStringAsFixed(2)}',
            emphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _targetMoveCard(BuildContext context, SmartTradePlan plan) {
    final AppStrings strings = context.strings;
    final TargetOutcome target = plan.targetMoveOutcome;
    return _CalculatorSection(
      title: strings.pick('СКАЛЬПИНГ МАЛОГО ДВИЖЕНИЯ', 'SMALL-MOVE SCALPING'),
      icon: Icons.speed_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 210,
            child: _NumberField(
              key: const ValueKey<String>('target-move-field'),
              controller: _targetMove,
              label: strings.pick('Хочу взять движение', 'Target move'),
              suffix: '%',
              onChanged: _recalculate,
            ),
          ),
          const SizedBox(height: 10),
          _TargetTile(target: target),
          const SizedBox(height: 6),
          _InfoLine(
            label: strings.pick(
              'Расходы / валовая прибыль',
              'Costs / gross profit',
            ),
            value: target.costToGrossPercent.isFinite
                ? '${target.costToGrossPercent.toStringAsFixed(1)}%'
                : '—',
            emphasized: true,
          ),
        ],
      ),
    );
  }

  Widget _whyCard(BuildContext context, SmartTradePlan plan) {
    final AppStrings strings = context.strings;
    return _CalculatorSection(
      title: strings.pick('ПОЧЕМУ ТАКОЙ РАСЧЁТ?', 'WHY THIS CALCULATION?'),
      icon: Icons.help_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...plan.explanation.map<Widget>(
            (String line) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('• '),
                  Expanded(child: Text(line)),
                ],
              ),
            ),
          ),
          if (plan.reasons.isNotEmpty) ...<Widget>[
            const Divider(height: 20),
            Text(
              strings.pick('Решение Safety Gate', 'Safety Gate decision'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            ...plan.reasons.map<Widget>(
              (String reason) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('⚠ $reason'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SetupSummary extends StatelessWidget {
  const _SetupSummary({required this.input});

  final SmartPositionInput input;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 22,
          runSpacing: 10,
          children: <Widget>[
            _Metric(label: 'Setup', value: input.setupType),
            _Metric(label: 'Confidence', value: '${input.confidence}/100'),
            _Metric(label: 'Current price', value: _price(input.currentPrice)),
            _Metric(
              label: 'Entry Zone',
              value:
                  '${_price(input.entryZoneLow)}–${_price(input.entryZoneHigh)}',
            ),
            _Metric(label: 'Stage', value: input.signalStage.code),
            _Metric(label: 'Regime', value: input.marketRegime.label),
            _Metric(label: 'ATR', value: _price(input.atr)),
            _Metric(
              label: 'Volatility',
              value: '${input.volatilityPercent.toStringAsFixed(2)}%',
            ),
          ],
        ),
      ),
    );
  }
}

class _CalculatorSection extends StatelessWidget {
  const _CalculatorSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeading(title: title, icon: icon),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
    this.width,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final double? width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, suffixText: suffix),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              fontSize: emphasized ? 16 : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LeverageTile extends StatelessWidget {
  const _LeverageTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: <Widget>[
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({required this.target});

  final TargetOutcome target;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${target.label} · ${_price(target.price)}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                ProductStatusChip(
                  label: _targetVerdict(target.verdict),
                  color: _targetColor(context, target.verdict),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _InfoLine(
              label: 'Move',
              value: '${target.movePercent.toStringAsFixed(3)}%',
            ),
            _InfoLine(label: 'Gross', value: _money(target.grossProfit)),
            _InfoLine(label: 'Costs', value: '-${_money(target.costs.total)}'),
            _InfoLine(
              label: 'Net',
              value: _money(target.netProfit),
              emphasized: true,
            ),
            _InfoLine(
              label: 'Net R:R',
              value: '1:${target.netRiskReward.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyChip extends StatelessWidget {
  const _SafetyChip({required this.status});

  final TradeSafetyStatus status;

  @override
  Widget build(BuildContext context) {
    return ProductStatusChip(
      label: _statusLabel(status),
      color: _statusColor(context, status),
      icon: status == TradeSafetyStatus.acceptable
          ? Icons.check_circle_outline_rounded
          : status == TradeSafetyStatus.wait
          ? Icons.schedule_rounded
          : Icons.warning_amber_rounded,
    );
  }
}

String _riskShortLabel(RiskPreset preset) {
  switch (preset) {
    case RiskPreset.cautious:
      return '1%';
    case RiskPreset.normal:
      return '2%';
    case RiskPreset.active:
      return '3%';
    case RiskPreset.custom:
      return '⚙';
  }
}

String _statusLabel(TradeSafetyStatus status) {
  switch (status) {
    case TradeSafetyStatus.acceptable:
      return 'TRADE ACCEPTABLE';
    case TradeSafetyStatus.wait:
      return 'WAIT';
    case TradeSafetyStatus.lowEdge:
      return 'LOW EDGE';
    case TradeSafetyStatus.skip:
      return 'SKIP THIS TRADE';
    case TradeSafetyStatus.blocked:
      return 'TRADE BLOCKED';
  }
}

Color _statusColor(BuildContext context, TradeSafetyStatus status) {
  final RadarSemanticColors colors = Theme.of(context)
      .extension<RadarSemanticColors>()!;
  switch (status) {
    case TradeSafetyStatus.acceptable:
      return colors.bullish;
    case TradeSafetyStatus.wait:
    case TradeSafetyStatus.lowEdge:
      return colors.warning;
    case TradeSafetyStatus.skip:
    case TradeSafetyStatus.blocked:
      return colors.bearish;
  }
}

String _targetVerdict(TargetVerdict verdict) {
  switch (verdict) {
    case TargetVerdict.worthIt:
      return 'WORTH IT';
    case TargetVerdict.lowEdge:
      return 'COSTS HIGH';
    case TargetVerdict.skip:
      return 'SKIP';
  }
}

Color _targetColor(BuildContext context, TargetVerdict verdict) {
  final RadarSemanticColors colors = Theme.of(context)
      .extension<RadarSemanticColors>()!;
  switch (verdict) {
    case TargetVerdict.worthIt:
      return colors.bullish;
    case TargetVerdict.lowEdge:
      return colors.warning;
    case TargetVerdict.skip:
      return colors.bearish;
  }
}

double _parse(String raw) =>
    double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0.0;

double? _parseNullable(String raw) {
  if (raw.trim().isEmpty) return null;
  return double.tryParse(raw.trim().replaceAll(',', '.'));
}

String _number(double value, int digits) => value.toStringAsFixed(digits);

String _price(double value) {
  if (value.abs() >= 1000) return value.toStringAsFixed(2);
  if (value.abs() >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String _money(double value) {
  final String sign = value < 0 ? '-' : '';
  return '$sign\$${value.abs().toStringAsFixed(2)}';
}

String _quantity(double value) {
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(8);
}

String _baseCoin(String symbol) =>
    symbol.toUpperCase().replaceFirst(RegExp(r'USDT$'), '');
