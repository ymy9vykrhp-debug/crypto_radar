import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../models/integration_models.dart';
import '../models/market_models.dart';
import '../services/app_preferences_controller.dart';
import '../services/multi_asset_monitor_controller.dart';
import '../services/notifications/telegram_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/product_components.dart';

class IntegrationsScreen extends StatefulWidget {
  const IntegrationsScreen({
    super.key,
    required this.preferences,
    required this.telegramController,
    required this.multiAssetMonitor,
    this.onRefreshMonitor,
    this.ticker,
  });

  final AppPreferencesController preferences;
  final TelegramController telegramController;
  final MultiAssetMonitorController multiAssetMonitor;
  final Future<void> Function()? onRefreshMonitor;
  final TickerStats? ticker;

  @override
  State<IntegrationsScreen> createState() => _IntegrationsScreenState();
}

class _IntegrationsScreenState extends State<IntegrationsScreen> {
  late final TextEditingController _relayController;

  @override
  void initState() {
    super.initState();
    _relayController = TextEditingController(
      text: widget.preferences.telegramRelayConfig.baseUrl,
    );
  }

  @override
  void dispose() {
    _relayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.preferences,
        widget.telegramController,
        widget.multiAssetMonitor,
      ]),
      builder: (BuildContext context, Widget? child) {
        final TelegramRelayConfig config =
            widget.preferences.telegramRelayConfig;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Интеграции', 'Integrations'),
              subtitle: strings.pick(
                'Публичные данные, безопасные уведомления и режимы исполнения',
                'Public data, safe notifications and execution modes',
              ),
              icon: Icons.hub_outlined,
            ),
            const SizedBox(height: 14),
            _BybitDataCard(ticker: widget.ticker),
            const SizedBox(height: 10),
            _MultiAssetMonitorCard(
              preferences: widget.preferences,
              controller: widget.multiAssetMonitor,
              onRefresh: widget.onRefreshMonitor,
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SectionHeading(
                      title: 'Official Crypto Radar Telegram',
                      subtitle: strings.pick(
                        'Только исходящие уведомления · без токена в браузере · без ордеров',
                        'Outgoing alerts only · no browser token · no orders',
                      ),
                      icon: Icons.send_outlined,
                      trailing: ProductStatusChip(
                        label: widget.telegramController.status.message,
                        color: _statusColor(
                          context,
                          widget.telegramController.status.state,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        strings.pick(
                          'Отправлять подтверждённые сигналы',
                          'Send confirmed signals',
                        ),
                      ),
                      subtitle: Text(
                        strings.pick(
                          'Только новый «ВХОД РАЗРЕШЁН» после проверки данных, зоны, ликвидности, Stop и риска.',
                          'Only a new ENTRY READY event after data, zone, liquidity, stop, and risk checks.',
                        ),
                      ),
                      value: config.enabled,
                      onChanged: (bool enabled) {
                        widget.preferences.setTelegramRelayConfig(
                          config.copyWith(enabled: enabled),
                        );
                        unawaited(widget.telegramController.refreshStatus());
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 420,
                      child: TextField(
                        controller: _relayController,
                        decoration: const InputDecoration(
                          labelText: 'Local relay URL',
                          helperText: 'Default: http://127.0.0.1:8787',
                          prefixIcon: Icon(Icons.dns_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: widget.telegramController.busy
                              ? null
                              : () {
                                  widget.preferences.setTelegramRelayConfig(
                                    config.copyWith(
                                      baseUrl: _relayController.text.trim(),
                                    ),
                                  );
                                  unawaited(
                                    widget.telegramController.refreshStatus(),
                                  );
                                },
                          icon: const Icon(Icons.link_rounded),
                          label: Text(
                            strings.pick(
                              'Сохранить и проверить',
                              'Save & check',
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              config.enabled && !widget.telegramController.busy
                              ? () => unawaited(
                                  widget.telegramController.discoverChat(),
                                )
                              : null,
                          icon: const Icon(Icons.person_search_outlined),
                          label: Text(
                            strings.pick(
                              'Найти чат после /start',
                              'Find chat after /start',
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              config.enabled && !widget.telegramController.busy
                              ? () => unawaited(
                                  widget.telegramController.sendTest(),
                                )
                              : null,
                          icon: const Icon(Icons.send_rounded),
                          label: Text(
                            strings.pick('Отправить тест', 'Send test'),
                          ),
                        ),
                      ],
                    ),
                    if (widget.telegramController.lastDelivery !=
                        null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        widget.telegramController.lastDelivery!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      strings.pick(
                        'Запусти relay с Bot Token, открой своего бота в Telegram и отправь /start. Затем нажми «Найти чат». Токен и найденный Chat ID не сохраняются в Crypto Radar.',
                        'Start the relay with the Bot Token, open your bot in Telegram and send /start. Then press Find chat. The token and discovered Chat ID are not stored by Crypto Radar.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            const _ExecutionModesCard(),
            const SizedBox(height: 10),
            _IntegrationTile(
              icon: Icons.account_balance_outlined,
              title: 'OKX / Binance / Coinbase Market Data',
              description: strings.pick(
                'Общий MarketDataProvider готов. Адаптеры подключаются по очереди без изменения SignalEngine.',
                'The shared MarketDataProvider boundary is ready. Adapters can be added without changing SignalEngine.',
              ),
              status: strings.planned,
            ),
            const SizedBox(height: 10),
            _IntegrationTile(
              icon: Icons.call_split_rounded,
              title: 'External Signal Sources',
              description: strings.pick(
                'Изолированный будущий Parser → Analysis → Filters. Никогда не отправляет ордера напрямую.',
                'Future isolated Parser → Analysis → Filters pipeline. It never places orders directly.',
              ),
              status: strings.planned,
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(BuildContext context, IntegrationConnectionState state) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    return switch (state) {
      IntegrationConnectionState.connected => semantic.bullish,
      IntegrationConnectionState.checking => semantic.warning,
      IntegrationConnectionState.unavailable => semantic.bearish,
      IntegrationConnectionState.disabled ||
      IntegrationConnectionState.notConfigured => semantic.neutral,
    };
  }
}

class _MultiAssetMonitorCard extends StatelessWidget {
  const _MultiAssetMonitorCard({
    required this.preferences,
    required this.controller,
    this.onRefresh,
  });

  final AppPreferencesController preferences;
  final MultiAssetMonitorController controller;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final List<String> availableSymbols = <String>{
      ...AppPreferencesController.defaultMonitoredSymbols,
      ...preferences.monitoredSymbols,
    }.toList(growable: false);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: strings.pick(
                'Фоновый монитор монет',
                'Multi-Asset Monitor',
              ),
              subtitle: strings.pick(
                'Один Signal Engine проверяет каждую монету отдельно и отправляет только уникальные события.',
                'One Signal Engine checks every asset independently and sends unique events only.',
              ),
              icon: Icons.radar_rounded,
              trailing: ProductStatusChip(
                label: controller.running
                    ? strings.pick('ПРОВЕРКА', 'CHECKING')
                    : '${preferences.monitoredSymbols.length} ACTIVE',
                color: controller.running ? semantic.warning : semantic.bullish,
              ),
            ),
            const SizedBox(height: 10),
            ...availableSymbols.map((String symbol) {
              final bool monitored = preferences.isSymbolMonitored(symbol);
              final AssetMonitorStatus status = controller.statusFor(symbol);
              return _MonitorSymbolRow(
                symbol: symbol,
                monitored: monitored,
                status: status,
                onChanged: (bool enabled) {
                  preferences.setSymbolMonitored(symbol, enabled);
                  final Future<void> Function()? refresh = onRefresh;
                  if (enabled && refresh != null) unawaited(refresh());
                },
              );
            }),
            const SizedBox(height: 8),
            Text(
              strings.pick(
                'По умолчанию BTCUSDT и FARTCOINUSDT проверяются последовательно каждые 15 секунд. Выключение монеты не удаляет её историю из Журнала.',
                'BTCUSDT and FARTCOINUSDT are checked sequentially every 15 seconds by default. Disabling an asset does not delete its Journal history.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MonitorSymbolRow extends StatelessWidget {
  const _MonitorSymbolRow({
    required this.symbol,
    required this.monitored,
    required this.status,
    required this.onChanged,
  });

  final String symbol;
  final bool monitored;
  final AssetMonitorStatus status;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final (String, Color, IconData) presentation = switch (status.state) {
      AssetMonitorState.idle => (
        context.strings.pick('ОЖИДАНИЕ', 'WAITING'),
        semantic.neutral,
        Icons.schedule_rounded,
      ),
      AssetMonitorState.checking => (
        context.strings.pick('ПРОВЕРКА', 'CHECKING'),
        semantic.warning,
        Icons.sync_rounded,
      ),
      AssetMonitorState.ready => (
        context.strings.pick('ДАННЫЕ OK', 'DATA OK'),
        semantic.bullish,
        Icons.check_circle_outline_rounded,
      ),
      AssetMonitorState.error => (
        context.strings.pick('ОШИБКА', 'ERROR'),
        semantic.bearish,
        Icons.error_outline_rounded,
      ),
    };
    final DateTime? checkedAt = status.lastCheckedAt;
    final String checkedText = checkedAt == null
        ? context.strings.pick('ещё не проверено', 'not checked yet')
        : '${checkedAt.hour.toString().padLeft(2, '0')}:'
              '${checkedAt.minute.toString().padLeft(2, '0')}:'
              '${checkedAt.second.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Switch(value: monitored, onChanged: onChanged),
      title: Text(symbol, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        status.error == null ? checkedText : '${status.error} · $checkedText',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ProductStatusChip(
        label: monitored ? presentation.$1 : 'OFF',
        color: monitored ? presentation.$2 : semantic.neutral,
        icon: monitored ? presentation.$3 : Icons.pause_circle_outline_rounded,
      ),
    );
  }
}

class _BybitDataCard extends StatelessWidget {
  const _BybitDataCard({this.ticker});

  final TickerStats? ticker;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    final TickerStats? data = ticker;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: 'Bybit Linear Market Data',
              subtitle: strings.pick(
                'Свечи, bid/ask, стакан L1, mark/index, funding и Open Interest',
                'Candles, bid/ask, L1 book, mark/index, funding and Open Interest',
              ),
              icon: Icons.currency_bitcoin_rounded,
              trailing: ProductStatusChip(
                label: data == null ? strings.notConnected : strings.active,
                color: data == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 18,
              runSpacing: 8,
              children: <Widget>[
                _DataValue(label: 'Bid', value: _price(data?.bidPrice)),
                _DataValue(label: 'Ask', value: _price(data?.askPrice)),
                _DataValue(
                  label: 'Spread',
                  value: data == null
                      ? '—'
                      : '${data.spreadPercent.toStringAsFixed(4)}%',
                ),
                _DataValue(label: 'Mark', value: _price(data?.markPrice)),
                _DataValue(label: 'Index', value: _price(data?.indexPrice)),
                _DataValue(
                  label: 'Funding',
                  value: data == null
                      ? '—'
                      : '${data.fundingRatePercent.toStringAsFixed(4)}%',
                ),
                _DataValue(
                  label: 'Open Interest',
                  value: data == null
                      ? '—'
                      : data.openInterest.toStringAsFixed(2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionModesCard extends StatelessWidget {
  const _ExecutionModesCard();

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = context.strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: strings.pick('Исполнение сделок', 'Trade Execution'),
              subtitle: strings.pick(
                'Режимы разделены и не включаются обычным переключателем',
                'Modes are isolated and cannot be enabled with a preference toggle',
              ),
              icon: Icons.security_rounded,
            ),
            const SizedBox(height: 8),
            const _ModeRow(
              label: 'OFF / MONITOR',
              status: 'ACTIVE',
              active: true,
            ),
            const _ModeRow(label: 'PAPER', status: 'NOT CONFIGURED'),
            const _ModeRow(label: 'BYBIT DEMO', status: 'NOT CONFIGURED'),
            const _ModeRow(
              label: 'BYBIT LIVE',
              status: 'HARD BLOCKED',
              blocked: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.label,
    required this.status,
    this.active = false,
    this.blocked = false,
  });

  final String label;
  final String status;
  final bool active;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    final RadarSemanticColors semantic = Theme.of(context)
        .extension<RadarSemanticColors>()!;
    final Color color = active
        ? semantic.bullish
        : blocked
        ? semantic.bearish
        : semantic.neutral;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        active ? Icons.visibility_outlined : Icons.lock_outline,
        color: color,
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      trailing: ProductStatusChip(label: status, color: color),
    );
  }
}

class _DataValue extends StatelessWidget {
  const _DataValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 130,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String description;
  final String status;

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(description),
        ),
        trailing: ProductStatusChip(label: status, color: color),
      ),
    );
  }
}

String _price(double? value) {
  if (value == null || !value.isFinite || value <= 0) return '—';
  return value >= 1 ? value.toStringAsFixed(4) : value.toStringAsFixed(7);
}
