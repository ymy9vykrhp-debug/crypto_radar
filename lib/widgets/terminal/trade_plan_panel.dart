import 'package:flutter/material.dart';

import '../../services/manual_assistant_controller.dart';
import '../../models/signal_models.dart';
import 'terminal_common.dart';

String positionLabel(String? state) => switch (state) {
  'HOLD' => 'ВСЁ ПО ПЛАНУ',
  'EXIT' => 'СРОЧНО ЗАКРЫТЬ',
  _ => 'ДЕРЖАТЬ / ЗАЩИЩАТЬ',
};
Color decisionColor(String? state, bool long) => switch (state) {
  'READY' => long ? TerminalStyle.green : TerminalStyle.red,
  'HOLD' => TerminalStyle.green,
  'EXIT' => TerminalStyle.red,
  'NO TRADE' => TerminalStyle.muted,
  _ => TerminalStyle.amber,
};

class TradePlanPanel extends StatelessWidget {
  const TradePlanPanel({
    super.key,
    required this.controller,
    required this.onPosition,
    required this.onJournal,
  });
  final ManualAssistantController controller;
  final VoidCallback onPosition, onJournal;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final r = c.result;
    final p = c.position;
    final long = p != null
        ? p.side == SignalDirection.long
        : r?.setup.startsWith('LONG') == true;
    final ready = c.liveEnabled && r?.state == 'READY' && p == null;
    final accent = !c.liveEnabled
        ? TerminalStyle.amber
        : decisionColor(r?.state, long);
    final title = p != null
        ? positionLabel(r?.state)
        : ready
        ? (long ? 'ЛОНГ' : 'ШОРТ')
        : 'WAIT';
    final entry =
        p?.entry ??
        (r == null ? null : (r.decision.entryLow + r.decision.entryHigh) / 2);
    final stop = p?.stop ?? r?.decision.stop;
    final targets = p?.plannedTargets ?? r?.targets ?? <double>[];
    double? move(double? target) =>
        entry == null || entry <= 0 || target == null
        ? null
        : (target - entry) / entry * 100 * (long ? 1 : -1);
    final rr = p != null
        ? r?.dynamicRiskReward
        : r?.economics?.netRiskReward ?? r?.decision.riskReward;
    return TerminalPanel(
      title: p != null ? 'POSITION MODE' : 'Что делать сейчас?',
      accent: accent,
      trailing: Text(
        clockText(c.markets['FARTCOINUSDT']?.updatedAt),
        style: const TextStyle(fontSize: 10, color: TerminalStyle.muted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TradeDecisionCard(
            title: title,
            action: !c.liveEnabled
                ? 'ПАУЗА. Обновите данные перед решением.'
                : r?.action ?? 'Ожидаем данные. Вход не разрешён.',
            quality: r?.quality,
            color: accent,
          ),
          const SizedBox(height: 8),
          EntryCard(
            label: p != null
                ? 'Фактический вход'
                : ready
                ? 'Вход в зону'
                : 'Ждать зону / подтверждение',
            value: p != null
                ? price(p.entry)
                : r == null
                ? '—'
                : price(r.decision.entryLow) +
                      ' – ' +
                      price(r.decision.entryHigh),
            detail: 'Цена ' + price(r?.price),
            color: TerminalStyle.cyan,
            icon: Icons.north_east,
          ),
          StopLossCard(
            value: price(stop),
            detail:
                'До SL ' +
                price(move(stop)?.abs(), 2) +
                '% • риск ' +
                price(c.riskPercent, 2) +
                '%',
          ),
          TakeProfitPanel(targets: targets, move: move),
          const SizedBox(height: 8),
          TradeMetricsRow(
            rr: rr,
            potential: targets.isEmpty ? null : move(targets.last),
            quality: r?.quality,
          ),
          const SizedBox(height: 8),
          TradeScenarioCard(
            reasons: r?.reasons ?? ['План появится после загрузки данных.'],
          ),
          ExpansionTile(
            title: const Text(
              '3 мозга · почему принято решение',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              terminalRow(
                '1 · Структура и направление',
                r?.direction ?? 'Ожидаем свечи',
              ),
              terminalRow('Сетап', r?.setup ?? '—'),
              terminalRow('Ретест', r?.retest.name ?? '—'),
              terminalRow('2 · Рыночный контекст', r?.context ?? 'Нет данных'),
              terminalRow('Относительная сила', r?.relativeStrength ?? '—'),
              terminalRow('Binance', r?.binanceConfirmation ?? 'Нет данных'),
              terminalRow(
                '3 · Риск и качество',
                r == null ? 'Нет оценки' : price(r.quality / 10, 1) + '/10',
              ),
              terminalRow(
                'Минимальный net R:R',
                price(r?.requiredNetRiskReward, 2),
              ),
              if (r != null)
                for (final factor in r.factors.entries)
                  terminalRow(factor.key, factor.value.toString()),
              const Text(
                'Босс · итог правил',
                style: TextStyle(color: TerminalStyle.cyan, fontSize: 12),
              ),
              Text(
                r?.action ?? 'Данных недостаточно для решения.',
                style: const TextStyle(fontSize: 11),
              ),
              const Text(
                'Объяснения действующего алгоритма, без отдельных ИИ-запросов.',
                style: TextStyle(color: TerminalStyle.muted, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: .15),
                    foregroundColor: accent,
                    minimumSize: const Size(0, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                      side: BorderSide(color: accent),
                    ),
                  ),
                  onPressed: onPosition,
                  icon: const Icon(Icons.edit_note, size: 22),
                  label: Text(
                    p == null ? 'Отметить свой вход' : 'Управлять позицией',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onJournal,
                child: const Icon(Icons.menu_book, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Ручные отметки • ордера на биржу не отправляются',
            style: TextStyle(fontSize: 9, color: TerminalStyle.muted),
          ),
        ],
      ),
    );
  }
}

class TradeDecisionCard extends StatelessWidget {
  const TradeDecisionCard({
    super.key,
    required this.title,
    required this.action,
    required this.quality,
    required this.color,
  });
  final String title, action;
  final int? quality;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(7),
      gradient: LinearGradient(
        colors: [color.withValues(alpha: .13), TerminalStyle.bg],
      ),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: const ValueKey('terminal-decision'),
                style: TextStyle(
                  fontSize: title.length > 10 ? 21 : 36,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(action, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          children: [
            const Text(
              'Качество',
              style: TextStyle(fontSize: 10, color: TerminalStyle.muted),
            ),
            Text(
              quality == null
                  ? '—'
                  : (quality! / 10).toStringAsFixed(1) + '/10',
              style: TextStyle(
                fontSize: 21,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              quality == null
                  ? 'НЕТ ОЦЕНКИ'
                  : quality! >= 80
                  ? 'ВЫСОКОЕ'
                  : quality! >= 60
                  ? 'СРЕДНЕЕ'
                  : 'НИЗКОЕ',
              style: const TextStyle(fontSize: 8, color: TerminalStyle.muted),
            ),
            const Text(
              'не шанс прибыли',
              style: TextStyle(fontSize: 8, color: TerminalStyle.muted),
            ),
          ],
        ),
      ],
    ),
  );
}

class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.color,
    required this.icon,
  });
  final String label, value, detail;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 5),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      color: TerminalStyle.bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: TerminalStyle.border),
    ),
    child: Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color)),
              Text(
                detail,
                style: const TextStyle(fontSize: 9, color: TerminalStyle.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

class StopLossCard extends StatelessWidget {
  const StopLossCard({super.key, required this.value, required this.detail});
  final String value, detail;
  @override
  Widget build(BuildContext context) => EntryCard(
    label: 'СТОП-ЛОСС',
    value: value,
    detail: detail,
    color: TerminalStyle.red,
    icon: Icons.shield_outlined,
  );
}

class TakeProfitPanel extends StatelessWidget {
  const TakeProfitPanel({super.key, required this.targets, required this.move});
  final List<double> targets;
  final double? Function(double?) move;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (int i = 0; i < 3; i++)
        EntryCard(
          label: 'Тейк-профит ' + (i + 1).toString(),
          value: i < targets.length ? price(targets[i]) : '—',
          detail: i < targets.length
              ? price(move(targets[i]), 2) + '% • движение цены'
              : 'Структурная цель не найдена',
          color: TerminalStyle.green,
          icon: Icons.track_changes,
        ),
    ],
  );
}

class TradeMetricsRow extends StatelessWidget {
  const TradeMetricsRow({
    super.key,
    required this.rr,
    required this.potential,
    required this.quality,
  });
  final double? rr, potential;
  final int? quality;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (final item in [
        ('R:R', rr == null ? '—' : '1 : ' + price(rr, 2)),
        ('Потенциал', price(potential, 2) + '%'),
        ('Качество', quality == null ? '—' : price(quality! / 10, 1) + '/10'),
      ])
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: TerminalStyle.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    fontSize: 9,
                    color: TerminalStyle.muted,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    item.$2,
                    style: const TextStyle(
                      fontSize: 18,
                      color: TerminalStyle.green,
                      fontWeight: FontWeight.bold,
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

class TradeScenarioCard extends StatelessWidget {
  const TradeScenarioCard({super.key, required this.reasons});
  final List<String> reasons;
  @override
  Widget build(BuildContext context) => TerminalPanel(
    title: 'Краткий сценарий',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...reasons
            .take(4)
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '• ' + r,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Все причины', style: TextStyle(fontSize: 10)),
          children: reasons
              .map((r) => Text(r, style: const TextStyle(fontSize: 10)))
              .toList(),
        ),
      ],
    ),
  );
}
