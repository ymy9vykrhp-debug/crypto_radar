import 'package:flutter/material.dart';

import '../engines/decision_engine.dart';
import '../engines/explanation_engine.dart';
import '../localization/app_strings.dart';
import '../models/decision_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../models/trade_alert_models.dart';
import '../theme/app_theme.dart';
import 'product_components.dart';

class TradeSignalAlertDialog extends StatelessWidget {
  const TradeSignalAlertDialog({
    super.key,
    required this.alert,
    required this.snapshot,
    required this.onOpenMarket,
    required this.onWhy,
  });

  final TradeAlert alert;
  final MarketSnapshot snapshot;
  final VoidCallback onOpenMarket;
  final VoidCallback onWhy;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSignal signal = alert.signal;
    final DecisionSnapshot decision = DecisionEngine.build(
      snapshot,
      executionSignal: signal,
    );
    final DecisionExplanation explanation = ExplanationEngine.explain(decision);
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = signal.direction == SignalDirection.long
        ? semantic.bullish
        : semantic.bearish;
    final List<DecisionReason> reasons = explanation.supporting
        .take(6)
        .toList(growable: false);

    return AlertDialog(
      icon: Icon(Icons.local_fire_department_rounded, color: color, size: 34),
      title: Text(
        '${signal.symbol} — ${signal.direction.label} SETUP',
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ProductStatusChip(
                label:
                    '${strings.pick('Качество сигнала', 'Signal Confidence')}: ${signal.score}/100',
                color: color,
                icon: Icons.verified_rounded,
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 18,
                runSpacing: 12,
                children: <Widget>[
                  _Value(
                    label: 'Entry',
                    value:
                        '${_price(signal.entryLow)}–${_price(signal.entryHigh)}',
                  ),
                  _Value(label: 'Stop Loss', value: _price(signal.stop)),
                  _Value(label: 'TP1', value: _price(signal.tp1)),
                  _Value(label: 'TP2', value: _price(signal.tp2)),
                  _Value(
                    label: 'R:R',
                    value: '1:${alert.riskReward.toStringAsFixed(1)}',
                  ),
                  _Value(
                    label: strings.pick('Допустимое плечо', 'Max leverage'),
                    value: '${signal.leverage.clamp(1, 10)}x',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                strings.pick('Почему сейчас:', 'Why now:'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              if (reasons.isEmpty)
                Text(explanation.whyDecision)
              else
                ...reasons.map<Widget>(
                  (DecisionReason reason) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('✓ ${reason.title}'),
                  ),
                ),
              const SizedBox(height: 10),
              Text(
                strings.pick(
                  'Confidence — это совпадение факторов, не вероятность прибыли. Риск в USDT не рассчитывается без размера позиции. MONITOR / ANALYSIS ONLY.',
                  'Confidence is factor confluence, not profit probability. USDT risk is not calculated without a position size. MONITOR / ANALYSIS ONLY.',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.pick('Пропустить', 'Skip')),
        ),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onWhy();
          },
          icon: const Icon(Icons.help_outline_rounded),
          label: Text(strings.pick('Почему сейчас?', 'Why now?')),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onOpenMarket();
          },
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(strings.pick('Открыть рынок', 'Open market')),
        ),
      ],
    );
  }
}

class _Value extends StatelessWidget {
  const _Value({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String _price(double value) {
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}
