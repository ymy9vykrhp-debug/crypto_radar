import 'package:flutter/material.dart';

abstract final class TerminalStyle {
  static const bg = Color(0xFF061016);
  static const panel = Color(0xFF0B1720);
  static const border = Color(0xFF233B46);
  static const text = Color(0xFFF2F5F7);
  static const muted = Color(0xFF8EA1AC);
  static const green = Color(0xFF22F59A);
  static const red = Color(0xFFFF525D);
  static const amber = Color(0xFFFFC247);
  static const cyan = Color(0xFF19D7E8);
}

String price(num? value, [int digits = 5]) =>
    value == null || !value.isFinite ? '—' : value.toStringAsFixed(digits);
String compact(num? value) {
  if (value == null || !value.isFinite) return '—';
  if (value.abs() >= 1000000000)
    return (value / 1000000000).toStringAsFixed(2) + 'B';
  if (value.abs() >= 1000000) return (value / 1000000).toStringAsFixed(2) + 'M';
  if (value.abs() >= 1000) return (value / 1000).toStringAsFixed(1) + 'K';
  return value.toStringAsFixed(2);
}

String clockText(DateTime? value) =>
    value == null ? '—' : value.toLocal().toIso8601String().substring(11, 19);

class TerminalPanel extends StatelessWidget {
  const TerminalPanel({
    super.key,
    required this.title,
    required this.child,
    this.accent,
    this.trailing,
    this.collapsible = false,
  });
  final String title;
  final Widget child;
  final Color? accent;
  final Widget? trailing;
  final bool collapsible;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: TerminalStyle.panel,
      border: Border.all(color: accent ?? TerminalStyle.border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Material(
      color: TerminalStyle.panel,
      child: collapsible
          ? ExpansionTile(
              key: PageStorageKey(title),
              initiallyExpanded: true,
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [child],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
    ),
  );
}

Widget terminalRow(
  String label,
  String value, {
  Color color = TerminalStyle.text,
}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: TerminalStyle.muted, fontSize: 11),
        ),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  ),
);

class TradingHeader extends StatelessWidget {
  const TradingHeader({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.live,
    required this.status,
    required this.onLive,
    required this.onRefresh,
  });
  final int selected;
  final ValueChanged<int> onSelect;
  final bool live;
  final String status;
  final ValueChanged<bool>? onLive;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final brand = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.radar, color: TerminalStyle.cyan, size: 34),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CRYPTO RADAR',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              if (box.maxWidth > 900)
                const Text(
                  'АНАЛИЗ • СИГНАЛЫ • ТОРГОВЫЕ ПЛАНЫ',
                  style: TextStyle(fontSize: 8, color: TerminalStyle.muted),
                ),
            ],
          ),
        ],
      );
      final nav = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final item in <(int, String, IconData)>[
              (0, 'Торговля', Icons.candlestick_chart),
              (4, 'Рынок', Icons.bar_chart),
              (5, 'Скринер', Icons.radar),
              (6, 'Журнал', Icons.menu_book),
              (3, 'Настройки', Icons.settings),
              (2, 'Grid', Icons.grid_on),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton.icon(
                  onPressed: () => onSelect(item.$1),
                  style: TextButton.styleFrom(
                    foregroundColor: selected == item.$1
                        ? TerminalStyle.cyan
                        : TerminalStyle.muted,
                    backgroundColor: selected == item.$1
                        ? TerminalStyle.cyan.withValues(alpha: .10)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(
                        color: selected == item.$1
                            ? TerminalStyle.cyan
                            : TerminalStyle.border,
                      ),
                    ),
                  ),
                  icon: Icon(item.$3, size: 15),
                  label: Text(item.$2, style: const TextStyle(fontSize: 11)),
                ),
              ),
          ],
        ),
      );
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Автообновление LIVE',
            child: Switch(
              key: const ValueKey('live-switch'),
              value: live,
              onChanged: onLive,
              activeThumbColor: TerminalStyle.green,
            ),
          ),
          Text(
            live ? status.toUpperCase() : 'ПАУЗА',
            style: TextStyle(
              fontSize: 10,
              color: live && status == 'LIVE'
                  ? TerminalStyle.green
                  : TerminalStyle.amber,
            ),
          ),
          IconButton(
            tooltip: 'Обновить данные',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
          ),
        ],
      );
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: const BoxDecoration(
          color: TerminalStyle.bg,
          border: Border(bottom: BorderSide(color: TerminalStyle.border)),
        ),
        child: box.maxWidth >= 1250
            ? Row(
                children: [
                  brand,
                  const SizedBox(width: 24),
                  Expanded(child: nav),
                  controls,
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: brand,
                        ),
                      ),
                      controls,
                    ],
                  ),
                  nav,
                ],
              ),
      );
    },
  );
}
