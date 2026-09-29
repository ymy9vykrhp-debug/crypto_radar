import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../models/trading_journal_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/product_components.dart';

String journalPeriodLabel(AppStrings strings, PerformancePeriod period) {
  return switch (period) {
    PerformancePeriod.today => strings.pick('Сегодня', 'Today'),
    PerformancePeriod.sevenDays => '7D',
    PerformancePeriod.thirtyDays => '30D',
    PerformancePeriod.thisMonth => strings.pick('Этот месяц', 'This Month'),
    PerformancePeriod.threeMonths => '3M',
    PerformancePeriod.sixMonths => '6M',
    PerformancePeriod.oneYear => '1Y',
    PerformancePeriod.all => strings.pick('Всё', 'ALL'),
  };
}

String tradeSourceLabel(TradeSource source) => switch (source) {
  TradeSource.manual => 'MANUAL',
  TradeSource.paper => 'PAPER',
  TradeSource.bybitDemo => 'BYBIT DEMO',
  TradeSource.live => 'LIVE',
};

String tradeStatusLabel(JournalTradeStatus status) => switch (status) {
  JournalTradeStatus.open => 'OPEN',
  JournalTradeStatus.win => 'WIN',
  JournalTradeStatus.loss => 'LOSS',
  JournalTradeStatus.breakEven => 'BE',
};

String entryReasonLabel(AppStrings strings, EntryReason reason) =>
    switch (reason) {
      EntryReason.radarSignal => 'Radar Signal',
      EntryReason.manualAnalysis => strings.pick(
        'Ручной анализ',
        'Manual Analysis',
      ),
      EntryReason.telegramSignal => 'Telegram Signal',
      EntryReason.liquiditySweep => 'Liquidity Sweep',
      EntryReason.falseBreakout => 'False Breakout',
      EntryReason.bos => 'BOS',
      EntryReason.choch => 'CHOCH',
      EntryReason.fvg => 'FVG',
      EntryReason.orderBlock => 'Order Block',
      EntryReason.supportResistance => 'Support / Resistance',
      EntryReason.news => strings.pick('Новости', 'News'),
      EntryReason.other => strings.pick('Другое', 'Other'),
    };

String tradeTagLabel(TradeTag tag) => switch (tag) {
  TradeTag.goodEntry => 'Good Entry',
  TradeTag.badEntry => 'Bad Entry',
  TradeTag.early => 'Early',
  TradeTag.late => 'Late',
  TradeTag.fomo => 'FOMO',
  TradeTag.revenge => 'Revenge',
  TradeTag.noConfirmation => 'No Confirmation',
  TradeTag.liquiditySweep => 'Liquidity Sweep',
  TradeTag.falseBreakout => 'False Breakout',
  TradeTag.bos => 'BOS',
  TradeTag.choch => 'CHOCH',
  TradeTag.fvg => 'FVG',
  TradeTag.orderBlock => 'Order Block',
  TradeTag.news => 'News',
  TradeTag.manualIdea => 'Manual Idea',
};

String noteCategoryLabel(AppStrings strings, TradingNoteCategory category) =>
    switch (category) {
      TradingNoteCategory.idea => strings.pick('Идея', 'Idea'),
      TradingNoteCategory.observation => strings.pick(
        'Наблюдение',
        'Observation',
      ),
      TradingNoteCategory.mistake => strings.pick('Ошибка', 'Mistake'),
      TradingNoteCategory.strategy => strings.pick('Стратегия', 'Strategy'),
      TradingNoteCategory.market => strings.pick('Рынок', 'Market'),
      TradingNoteCategory.other => strings.pick('Другое', 'Other'),
    };

String journalMoney(double value, {bool signed = false}) {
  final String sign = signed && value > 0 ? '+' : '';
  return '$sign\$${value.toStringAsFixed(2)}';
}

String journalR(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)}R';

String journalPercent(double value) =>
    '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)}%';

String journalPrice(double value) {
  if (!value.isFinite || value <= 0) return '—';
  if (value >= 1000) return value.toStringAsFixed(2);
  if (value >= 1) return value.toStringAsFixed(4);
  return value.toStringAsFixed(6);
}

String journalDate(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}.'
      '${local.month.toString().padLeft(2, '0')}.${local.year}';
}

String journalTime(DateTime value) {
  final DateTime local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

Color tradeResultColor(BuildContext context, double value) {
  final RadarSemanticColors semantic = Theme.of(context)
      .extension<RadarSemanticColors>()!;
  if (value > 0) return semantic.bullish;
  if (value < 0) return semantic.bearish;
  return semantic.neutral;
}

class JournalMetricGrid extends StatelessWidget {
  const JournalMetricGrid({super.key, required this.items});

  final List<JournalMetricItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180
            ? 5
            : constraints.maxWidth >= 760
            ? 3
            : 2;
        final double width =
            (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map<Widget>(
                (JournalMetricItem item) => SizedBox(
                  width: width,
                  height: item.emphasis ? 126 : 104,
                  child: ProductMetricCard(
                    label: item.label,
                    value: item.value,
                    caption: item.caption,
                    icon: item.icon,
                    color: item.color,
                    emphasis: item.emphasis,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class JournalMetricItem {
  const JournalMetricItem({
    required this.label,
    required this.value,
    this.caption,
    this.icon,
    this.color,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final String? caption;
  final IconData? icon;
  final Color? color;
  final bool emphasis;
}
