import 'package:flutter/material.dart';

import '../../services/manual_assistant_controller.dart';
import '../../services/journal_controller.dart';
import '../../models/market_models.dart';
import '../../models/signal_models.dart';
import 'terminal_common.dart';

class PositionManagementPanel extends StatelessWidget {
  const PositionManagementPanel({
    super.key,
    required this.controller,
    required this.onManage,
  });
  final ManualAssistantController controller;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final p = controller.position;
    final state = controller.result?.state;
    return TerminalPanel(
      title: 'Управление позицией',
      trailing: IconButton(
        tooltip: 'Ручная позиция',
        onPressed: onManage,
        icon: const Icon(Icons.edit_outlined, size: 16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'ПОЗИЦИЯ НЕ ОТКРЫТА',
                style: TextStyle(color: TerminalStyle.muted, fontSize: 11),
              ),
            ),
          for (final row in <(String, String, Color)>[
            ('HOLD', 'ВСЁ ПО ПЛАНУ', TerminalStyle.green),
            ('PROTECT', 'ДЕРЖАТЬ / ЗАЩИЩАТЬ', TerminalStyle.amber),
            ('EXIT', 'СРОЧНО ЗАКРЫТЬ', TerminalStyle.red),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: p != null && (state ?? 'PROTECT') == row.$1
                      ? row.$3
                      : TerminalStyle.border,
                ),
                color: p != null && (state ?? 'PROTECT') == row.$1
                    ? row.$3.withValues(alpha: .10)
                    : Colors.transparent,
              ),
              child: Row(
                children: [
                  Icon(
                    p != null && (state ?? 'PROTECT') == row.$1
                        ? Icons.circle
                        : Icons.radio_button_unchecked,
                    color: p != null && (state ?? 'PROTECT') == row.$1
                        ? row.$3
                        : TerminalStyle.muted,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: p != null && (state ?? 'PROTECT') == row.$1
                            ? row.$3
                            : TerminalStyle.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (p != null) ...[
            terminalRow('Вход / Stop', price(p.entry) + ' / ' + price(p.stop)),
            terminalRow(
              'Качество сетапа при входе',
              p.qualityAtOpen == null
                  ? 'Нет оценки'
                  : price(p.qualityAtOpen! / 10, 1) + '/10',
            ),
            Text(
              controller.result?.entryOutsidePlannedZone == true
                  ? 'СЛАБЫЙ ВХОД: вне плановой зоны. Состояние позиции оценивается отдельно.'
                  : 'Качество фактического входа отдельно не оценено.',
              style: const TextStyle(fontSize: 10, color: TerminalStyle.amber),
            ),
          ],
        ],
      ),
    );
  }
}

class SignalFiltersPanel extends StatelessWidget {
  const SignalFiltersPanel({super.key, required this.controller});
  final ManualAssistantController controller;
  Color biasColor(Bias? value) => value == Bias.bullish
      ? TerminalStyle.green
      : value == Bias.bearish
      ? TerminalStyle.red
      : TerminalStyle.muted;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final m = c.markets['FARTCOINUSDT'];
    final a = m?.fiveMinutes;
    final ema = a == null
        ? null
        : a.ema50 > a.ema200
        ? Bias.bullish
        : a.ema50 < a.ema200
        ? Bias.bearish
        : Bias.neutral;
    return TerminalPanel(
      title: 'Сигналы и фильтры',
      collapsible: true,
      child: Column(
        children: [
          terminalRow(
            'Тренд EMA 50/200',
            ema?.label ?? '—',
            color: biasColor(ema),
          ),
          terminalRow('RSI 14', price(a?.rsi, 1)),
          terminalRow(
            'MACD',
            price(a?.macd.histogram, 6),
            color: a == null
                ? TerminalStyle.muted
                : a.macd.histogram >= 0
                ? TerminalStyle.green
                : TerminalStyle.red,
          ),
          terminalRow('Объём RVOL', price(a?.relativeVolume, 2) + '×'),
          terminalRow(
            'Структура',
            a?.structure.bias.label ?? '—',
            color: biasColor(a?.structure.bias),
          ),
          terminalRow('Funding', price(m?.ticker.fundingRatePercent, 4) + '%'),
          terminalRow('Открытый интерес', compact(m?.ticker.openInterest)),
          terminalRow(
            'Контекст BTC',
            c.markets['BTCUSDT']?.fiveMinutes.trend.label ?? 'Нет данных',
            color: biasColor(c.markets['BTCUSDT']?.fiveMinutes.trend),
          ),
          terminalRow(
            'Binance · подтверждение',
            c.result?.binanceConfirmation ?? 'Нет данных',
          ),
          if (c.confirmationError != null)
            const Text(
              'Binance временно недоступен',
              style: TextStyle(color: TerminalStyle.amber, fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class RecentSignalsPanel extends StatelessWidget {
  const RecentSignalsPanel({
    super.key,
    required this.journal,
    required this.controller,
    required this.onJournal,
  });
  final JournalController journal;
  final ManualAssistantController controller;
  final VoidCallback onJournal;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: journal,
    builder: (context, _) {
      final rows = journal.signals.take(4).toList();
      return TerminalPanel(
        title: 'Недавние сигналы',
        trailing: InkWell(
          onTap: onJournal,
          child: const Text(
            'Журнал →',
            style: TextStyle(color: TerminalStyle.cyan, fontSize: 10),
          ),
        ),
        child: rows.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'В журнале пока нет сигналов',
                  style: TextStyle(color: TerminalStyle.muted, fontSize: 11),
                ),
              )
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(.8),
                  1: FlexColumnWidth(1.4),
                  2: FlexColumnWidth(),
                  3: FlexColumnWidth(),
                  4: FlexColumnWidth(),
                  5: FlexColumnWidth(),
                },
                children: [
                  TableRow(
                    children:
                        ['Время', 'Пара', 'Сигнал', 'Вход', 'Текущая', 'PnL']
                            .map(
                              (v) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(
                                  v,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: TerminalStyle.muted,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  for (final s in rows)
                    TableRow(
                      children:
                          [
                                clockText(s.time).substring(0, 5),
                                s.symbol.replaceAll('USDT', ''),
                                s.direction.label,
                                price((s.entryLow + s.entryHigh) / 2, 4),
                                price(
                                  controller.markets[s.symbol]?.ticker.price,
                                  4,
                                ),
                                s.hasCostAwareResult ? price(s.netPnl, 2) : '—',
                              ]
                              .map(
                                (v) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    v,
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                ],
              ),
      );
    },
  );
}

class AdvicePanel extends StatelessWidget {
  const AdvicePanel({super.key, required this.controller});
  final ManualAssistantController controller;
  @override
  Widget build(BuildContext context) => TerminalPanel(
    title: 'Совет · прямо сейчас',
    child: Text(
      !controller.liveEnabled
          ? 'Данные на паузе. Обновите их перед решением.'
          : controller.result?.action ?? 'Дождитесь данных Bybit. Не открывайте позицию по пустому плану.',
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 11),
    ),
  );
}
