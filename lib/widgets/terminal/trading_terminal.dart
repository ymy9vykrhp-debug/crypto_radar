import 'package:flutter/material.dart';

import '../../services/manual_assistant_controller.dart';
import '../../services/journal_controller.dart';
import '../../engines/adaptive_grid_engine.dart';
import '../../engines/manual_assistant_engine.dart';
import 'terminal_common.dart';
import 'market_panels.dart';
import 'trade_plan_panel.dart';
import 'position_panels.dart';

class TradingTerminal extends StatelessWidget {
  const TradingTerminal({
    super.key,
    required this.controller,
    required this.journal,
    required this.onPosition,
    required this.onJournal,
    required this.onGrid,
  });
  final ManualAssistantController controller;
  final JournalController journal;
  final VoidCallback onPosition, onJournal, onGrid;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final c = controller;
      final left = MarketChartPanel(
        controller: c,
        height: (box.maxHeight * .40).clamp(210.0, 350.0),
      );
      final center = TradePlanPanel(
        controller: c,
        onPosition: onPosition,
        onJournal: onJournal,
      );
      final right = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PositionManagementPanel(controller: c, onManage: onPosition),
          const SizedBox(height: 8),
          SignalFiltersPanel(controller: c),
          const SizedBox(height: 8),
          RecentSignalsPanel(
            journal: journal,
            controller: c,
            onJournal: onJournal,
          ),
          const SizedBox(height: 8),
          AdvicePanel(controller: c),
        ],
      );
      Widget column(Widget child, String key) => SingleChildScrollView(
        key: PageStorageKey(key),
        padding: const EdgeInsets.all(6),
        child: child,
      );
      final content = box.maxWidth >= 1100
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 34, child: column(left, 'market-column')),
                Expanded(flex: 34, child: column(center, 'plan-column')),
                Expanded(flex: 32, child: column(right, 'position-column')),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  center,
                  const SizedBox(height: 8),
                  left,
                  const SizedBox(height: 8),
                  right,
                ],
              ),
            );
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Wrap(
              spacing: 12,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'BYBIT / FARTCOINUSDT',
                  style: TextStyle(fontSize: 10, color: TerminalStyle.muted),
                ),
                for (final mode in AssistantMode.values)
                  ChoiceChip(
                    label: Text(
                      mode.name,
                      style: const TextStyle(fontSize: 10),
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: c.mode == mode,
                    onSelected: c.position == null
                        ? (_) => c.setMode(mode)
                        : null,
                  ),
                InkWell(
                  onTap: onGrid,
                  child: Text(
                    (c.grid?.state.label ?? 'GRID WAIT') +
                        ' · ' +
                        (c.grid?.mode.label ?? '—'),
                    style: const TextStyle(
                      fontSize: 10,
                      color: TerminalStyle.cyan,
                    ),
                  ),
                ),
                const Text(
                  'Ручной режим • без отправки ордеров',
                  style: TextStyle(fontSize: 10, color: TerminalStyle.muted),
                ),
              ],
            ),
          ),
          if (c.loading.isNotEmpty) const LinearProgressIndicator(minHeight: 1),
          if (c.storageError != null || c.errors.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                c.storageError ?? c.errors.values.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: TerminalStyle.amber,
                  fontSize: 10,
                ),
              ),
            ),
          Expanded(child: content),
        ],
      );
    },
  );
}
