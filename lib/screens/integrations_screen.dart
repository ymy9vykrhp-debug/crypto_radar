import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../widgets/product_components.dart';

class IntegrationsScreen extends StatelessWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        SectionHeading(
          title: strings.pick('Интеграции', 'Integrations'),
          subtitle: strings.pick(
            'Источники данных и будущие внешние подключения',
            'Data sources and future external connections',
          ),
          icon: Icons.hub_outlined,
        ),
        const SizedBox(height: 14),
        _IntegrationTile(
          icon: Icons.currency_bitcoin_rounded,
          title: 'Bybit Linear Market Data',
          description: strings.pick(
            'Публичные свечи и тикер. Баланс, позиции и отправка ордеров не используются.',
            'Public candles and ticker. Balance, positions and order placement are not used.',
          ),
          status: strings.active,
          active: true,
        ),
        const SizedBox(height: 10),
        _IntegrationTile(
          icon: Icons.candlestick_chart_outlined,
          title: 'TradingView / Pine Script',
          description: strings.pick(
            'Внешний индикатор рассматривается после стабилизации стратегии.',
            'An external indicator is considered after strategy stabilization.',
          ),
          status: strings.planned,
        ),
        const SizedBox(height: 10),
        _IntegrationTile(
          icon: Icons.notifications_none_rounded,
          title: strings.pick('Центр уведомлений', 'Alert Center'),
          description: strings.pick(
            'Critical, Important и Info будут отделены от журнала.',
            'Critical, Important and Info will remain separate from the journal.',
          ),
          status: strings.planned,
        ),
        const SizedBox(height: 10),
        _IntegrationTile(
          icon: Icons.lock_outline_rounded,
          title: strings.pick('Реальная торговля Bybit', 'Bybit live trading'),
          description: strings.pick(
            'Отключена на текущем этапе проекта.',
            'Disabled at the current project stage.',
          ),
          status: strings.disabled,
        ),
      ],
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.active = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(description),
        ),
        trailing: ProductStatusChip(
          label: status,
          color: color,
          icon: active ? Icons.check_circle_outline : Icons.schedule_outlined,
        ),
      ),
    );
  }
}
