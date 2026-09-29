import 'package:flutter/material.dart';

import '../../engines/chart_overlay_engine.dart';
import '../../models/chart_models.dart';
import '../../models/market_models.dart';
import '../../services/manual_assistant_controller.dart';
import '../../services/chart_view_controller.dart';
import '../market_candlestick_chart.dart';
import 'terminal_common.dart';

class MarketChartPanel extends StatefulWidget {
  const MarketChartPanel({
    super.key,
    required this.controller,
    this.height = 320,
  });
  final ManualAssistantController controller;
  final double height;
  @override
  State<MarketChartPanel> createState() => _MarketChartPanelState();
}

class _MarketChartPanelState extends State<MarketChartPanel> {
  ChartTimeframe frame = ChartTimeframe.fiveMinutes;
  final viewport = ChartViewportController();
  final settings = ChartSettingsController();
  List<Candle>? extra;
  bool loading = false;
  String? error;
  int request = 0;
  @override
  void dispose() {
    request++;
    viewport.dispose();
    settings.dispose();
    super.dispose();
  }

  Future<void> select(ChartTimeframe value) async {
    final token = ++request;
    setState(() {
      frame = value;
      extra = null;
      error = null;
      loading =
          value == ChartTimeframe.fourHours || value == ChartTimeframe.oneDay;
    });
    if (!loading) return;
    try {
      final rows = await widget.controller.provider.loadCandles(
        'FARTCOINUSDT',
        value.bybitInterval,
      );
      if (!mounted || token != request) return;
      final now = DateTime.now().toUtc();
      setState(() {
        extra = rows
            .where((c) => !c.time.toUtc().add(value.duration).isAfter(now))
            .toList();
      });
    } catch (_) {
      if (mounted && token == request)
        setState(
          () => error = 'Свечи недоступны. Нажмите таймфрейм для повтора.',
        );
    } finally {
      if (mounted && token == request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final m = c.markets['FARTCOINUSDT'];
    final a = switch (frame) {
      ChartTimeframe.oneMinute => m?.oneMinute,
      ChartTimeframe.fiveMinutes => m?.fiveMinutes,
      ChartTimeframe.fifteenMinutes => m?.fifteenMinutes,
      ChartTimeframe.oneHour => m?.oneHour,
      _ => null,
    };
    final candles = a?.candles ?? extra ?? <Candle>[];
    final t = m?.ticker;
    final change = t?.change24hPercent;
    final last = c.result?.price ?? t?.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TerminalPanel(
          title: 'FARTCOINUSDT',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Perpetual • BYBIT',
                style: TextStyle(color: TerminalStyle.muted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    price(last),
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    (change != null && change >= 0 ? '+' : '') +
                        price(change, 2) +
                        '%',
                    style: TextStyle(
                      color: (change ?? 0) >= 0
                          ? TerminalStyle.green
                          : TerminalStyle.red,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 12,
                children: [
                  Text(
                    'Макс 24ч ' + price(t?.high24h),
                    style: const TextStyle(
                      fontSize: 10,
                      color: TerminalStyle.muted,
                    ),
                  ),
                  Text(
                    'Мин 24ч ' + price(t?.low24h),
                    style: const TextStyle(
                      fontSize: 10,
                      color: TerminalStyle.muted,
                    ),
                  ),
                  Text(
                    'Объём ' + compact(t?.volume24h),
                    style: const TextStyle(
                      fontSize: 10,
                      color: TerminalStyle.muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 3,
                runSpacing: 3,
                children: [
                  for (final tf in ChartTimeframe.values)
                    InkWell(
                      onTap: () => select(tf),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: frame == tf
                              ? TerminalStyle.cyan.withValues(alpha: .12)
                              : Colors.transparent,
                          border: Border.all(
                            color: frame == tf
                                ? TerminalStyle.cyan
                                : TerminalStyle.border,
                          ),
                        ),
                        child: Text(
                          tf.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: frame == tf
                                ? TerminalStyle.cyan
                                : TerminalStyle.muted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              SizedBox(
                height: widget.height,
                child: error != null
                    ? Center(child: Text(error!))
                    : m == null || c.result == null || candles.isEmpty
                    ? const Center(
                        child: Text(
                          'Ожидаем рыночные данные',
                          style: TextStyle(color: TerminalStyle.muted),
                        ),
                      )
                    : MarketCandlestickChart(
                        candles: candles,
                        overlay: ChartOverlayEngine.build(
                          market: m,
                          timeframe: frame,
                          candles: candles,
                          analysis: a,
                          signal: c.result!.signal,
                          decision: c.result!.decision,
                        ),
                        viewportController: viewport,
                        settingsController: settings,
                      ),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => viewport.zoomIn(candles.length),
                    child: const Text('+'),
                  ),
                  TextButton(
                    onPressed: () => viewport.zoomOut(candles.length),
                    child: const Text('−'),
                  ),
                  TextButton(
                    onPressed: () => viewport.goToLatest(),
                    child: const Text('К цене'),
                  ),
                  const Spacer(),
                  const Text(
                    'Закрытые свечи',
                    style: TextStyle(color: TerminalStyle.muted, fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: KeyLevelsPanel(market: m, last: last),
            ),
            const SizedBox(width: 8),
            Expanded(child: MarketSummaryPanel(controller: c)),
          ],
        ),
      ],
    );
  }
}

class KeyLevelsPanel extends StatelessWidget {
  const KeyLevelsPanel({super.key, required this.market, required this.last});
  final MarketSnapshot? market;
  final double? last;
  @override
  Widget build(BuildContext context) => TerminalPanel(
    title: 'Ключевые уровни',
    collapsible: true,
    child: Column(
      children: [
        terminalRow('Сопр. 1H', price(market?.oneHour.resistance)),
        terminalRow('Сопр. 15M', price(market?.fifteenMinutes.resistance)),
        terminalRow('Сопр. 5M', price(market?.fiveMinutes.resistance)),
        terminalRow('Цена', price(last), color: TerminalStyle.cyan),
        terminalRow('Подд. 5M', price(market?.fiveMinutes.support)),
        terminalRow('Подд. 15M', price(market?.fifteenMinutes.support)),
        terminalRow('Подд. 1H', price(market?.oneHour.support)),
      ],
    ),
  );
}

class MarketSummaryPanel extends StatelessWidget {
  const MarketSummaryPanel({super.key, required this.controller});
  final ManualAssistantController controller;
  @override
  Widget build(BuildContext context) {
    final m = controller.markets['FARTCOINUSDT'];
    return TerminalPanel(
      title: 'Кратко о рынке',
      collapsible: true,
      child: Column(
        children: [
          terminalRow('Оборот USDT', compact(m?.ticker.turnover24h)),
          terminalRow('Funding', price(m?.ticker.fundingRatePercent, 4) + '%'),
          terminalRow('OI, FART', compact(m?.ticker.openInterest)),
          terminalRow('ATR 5M', price(m?.fiveMinutes.atr)),
          terminalRow(
            'BTC',
            controller.markets['BTCUSDT']?.fiveMinutes.trend.label ??
                'Нет данных',
          ),
          terminalRow(
            'Binance',
            controller.result?.binanceConfirmation ?? 'Нет данных',
          ),
        ],
      ),
    );
  }
}
