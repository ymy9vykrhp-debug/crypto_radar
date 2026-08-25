import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../engines/backtest_engine.dart';
import '../engines/signal_engine.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/bybit_service.dart';
import '../services/journal_controller.dart';
import '../services/journal_store.dart';
import '../widgets/risk_reward_table.dart';
import 'journal_screen.dart';

class CryptoRadarHome extends StatefulWidget {
  const CryptoRadarHome({super.key, this.autoStart = true});

  final bool autoStart;

  @override
  State<CryptoRadarHome> createState() => _CryptoRadarHomeState();
}

class _CryptoRadarHomeState extends State<CryptoRadarHome> {
  static const Map<String, String> _symbols = <String, String>{
    'BTCUSDT': 'BTC / USDT',
    'FARTCOINUSDT': 'FARTCOIN / USDT',
  };

  late final http.Client _client;
  late final BybitService _repository;
  late final JournalController _journalController;
  Timer? _refreshTimer;
  String _selectedSymbol = 'FARTCOINUSDT';
  bool _autoRefresh = true;
  bool _loading = false;
  String? _error;
  MarketSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _repository = BybitService(_client);
    _journalController = JournalController(
      store: JournalStore(),
      backtestEngine: BacktestEngine(bybitService: _repository),
    );
    _journalController.initialize();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();
      });
      _restartTimer();
    } else {
      _autoRefresh = false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _journalController.dispose();
    _client.close();
    super.dispose();
  }

  void _restartTimer() {
    _refreshTimer?.cancel();
    if (!_autoRefresh || !widget.autoStart) {
      return;
    }
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _refresh();
    });
  }

  Future<void> _refresh() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final MarketSnapshot result = await _repository.load(_selectedSymbol);
      if (!mounted || result.symbol != _selectedSymbol) {
        return;
      }
      await _journalController.processLiveSnapshot(result);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = result;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final String message = error.toString().replaceFirst('Exception: ', '');
    if (message.contains('TimeoutException')) {
      return 'Bybit не ответил вовремя. Проверьте интернет и обновите ещё раз.';
    }
    return 'Не удалось обновить данные: $message';
  }

  void _selectSymbol(String? symbol) {
    if (symbol == null || symbol == _selectedSymbol) {
      return;
    }
    setState(() {
      _selectedSymbol = symbol;
      _snapshot = null;
      _error = null;
    });
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 18,
          title: const Row(
            children: <Widget>[
              Icon(Icons.radar_rounded),
              SizedBox(width: 10),
              Text('Crypto Radar'),
            ],
          ),
          actions: <Widget>[
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(right: 18),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'ГЛАВНАЯ'),
              Tab(text: 'ПОДТВЕРЖДЕНИЯ'),
              Tab(text: 'ДЕТАЛИ'),
              Tab(text: 'ЖУРНАЛ'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            _buildToolbar(),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) _buildErrorBanner(_error!),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _snapshot == null
                      ? _buildEmptyState()
                      : _buildHome(_snapshot!),
                  _snapshot == null
                      ? _buildEmptyState()
                      : _buildConfirmations(_snapshot!),
                  _snapshot == null
                      ? _buildEmptyState()
                      : _buildDetails(_snapshot!),
                  JournalScreen(controller: _journalController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey<String>(_selectedSymbol),
              initialValue: _selectedSymbol,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Инструмент',
                prefixIcon: Icon(Icons.currency_bitcoin),
                isDense: true,
              ),
              items: _symbols.entries
                  .map<DropdownMenuItem<String>>(
                    (MapEntry<String, String> entry) =>
                        DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                  )
                  .toList(growable: false),
              onChanged: _loading ? null : _selectSymbol,
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Автообновление каждые 15 секунд',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('15с'),
                Switch(
                  value: _autoRefresh,
                  onChanged: (bool value) {
                    setState(() {
                      _autoRefresh = value;
                    });
                    _restartTimer();
                  },
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Обновить сейчас',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.cloud_off_rounded, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.radar_rounded, size: 54, color: Colors.white38),
            const SizedBox(height: 16),
            Text(
              _loading ? 'Анализируем рынок…' : 'Нажмите обновить для анализа',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(MarketSnapshot snapshot) {
    final TimeframeAnalysis analysis = snapshot.fifteenMinutes;
    final TradePlan plan = snapshot.tradePlan;
    final RadarSignal? scalpSignal = SignalEngine.createScalpSignal(snapshot);
    final bool waiting = snapshot.signal == 'ЖДАТЬ';
    final String action = waiting
        ? 'Ждать усиления матрицы подтверждений'
        : plan.reason;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _HeroCard(snapshot: snapshot),
        const SizedBox(height: 12),
        _Panel(
          title: 'Тренд по таймфреймам',
          child: Row(
            children: <Widget>[
              Expanded(
                child: _TrendCell(label: '1м', bias: snapshot.oneMinute.trend),
              ),
              Expanded(
                child: _TrendCell(
                  label: '5м',
                  bias: snapshot.fiveMinutes.trend,
                ),
              ),
              Expanded(
                child: _TrendCell(label: '15м', bias: analysis.trend),
              ),
              Expanded(
                child: _TrendCell(label: '1ч', bias: snapshot.oneHour.trend),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Быстрая сделка 1м',
          icon: Icons.speed_rounded,
          child: scalpSignal == null
              ? const Text('Сейчас нет подтверждённого SCALP-входа.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${scalpSignal.direction.label} • вход '
                      '${_formatPrice(scalpSignal.entryLow)} — '
                      '${_formatPrice(scalpSignal.entryHigh)} • TP1 '
                      '${_formatPrice(scalpSignal.tp1)} • TP2 '
                      '${_formatPrice(scalpSignal.tp2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    RiskRewardTable(signal: scalpSignal),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final int columns = constraints.maxWidth >= 720 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: columns == 4 ? 1.65 : 1.45,
              children: <Widget>[
                _CompactMetric(
                  label: 'Ценовой магнит',
                  value: _formatPrice(snapshot.magnetPrice),
                  note: snapshot.magnetLabel,
                  icon: Icons.my_location_rounded,
                ),
                _CompactMetric(
                  label: 'Потенциал',
                  value: '${snapshot.potentialPercent.toStringAsFixed(2)}%',
                  note: snapshot.magnetPrice >= snapshot.ticker.price
                      ? 'вверх'
                      : 'вниз',
                  icon: Icons.trending_up_rounded,
                ),
                _CompactMetric(
                  label: 'Ожидаемый ход',
                  value:
                      '${_formatPrice(snapshot.expectedLow)} — ${_formatPrice(snapshot.expectedHigh)}',
                  note: '1.5 × ATR (15м)',
                  icon: Icons.swap_vert_rounded,
                ),
                _CompactMetric(
                  label: 'ATR / волатильность',
                  value: _formatPrice(analysis.atr),
                  note:
                      '${(analysis.atr / analysis.price * 100.0).toStringAsFixed(2)}%',
                  icon: Icons.multiline_chart_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Что делать сейчас',
          icon: Icons.bolt_rounded,
          child: Text(action, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        _TradePlanCard(plan: plan, signal: snapshot.signal),
        const SizedBox(height: 10),
        Text(
          'Расчёты носят информационный характер и не являются финансовой рекомендацией.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildConfirmations(MarketSnapshot snapshot) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _Panel(
          title: 'Confirmation Matrix',
          icon: Icons.fact_check_rounded,
          trailing: Text(
            'LONG ${snapshot.longScore}  •  SHORT ${snapshot.shortScore}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < snapshot.confirmations.length;
                index++
              ) ...<Widget>[
                _ConfirmationRow(item: snapshot.confirmations[index]),
                if (index < snapshot.confirmations.length - 1)
                  const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'Итог матрицы',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    flex: snapshot.longScore + 1,
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF38D996),
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: snapshot.shortScore + 1,
                    child: Container(
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF667A),
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(99),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${snapshot.signal} • сила ${snapshot.strength}%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              const Text(
                'Сигнал появляется только при разнице не менее 5 баллов. '
                'Нейтральные пункты не добавляют баллы.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetails(MarketSnapshot snapshot) {
    final TimeframeAnalysis one = snapshot.oneMinute;
    final TimeframeAnalysis five = snapshot.fiveMinutes;
    final TimeframeAnalysis fifteen = snapshot.fifteenMinutes;
    final TimeframeAnalysis hour = snapshot.oneHour;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _DetailExpansion(
          title: 'Индикаторы 1м • быстрые сделки',
          icon: Icons.speed_rounded,
          rows: <_DetailRow>[
            _DetailRow('Тренд 1м', one.trend.label),
            _DetailRow('RSI (14)', one.rsi.toStringAsFixed(2)),
            _DetailRow(
              'MACD / Signal',
              '${one.macd.macd.toStringAsFixed(6)} / '
                  '${one.macd.signal.toStringAsFixed(6)}',
            ),
            _DetailRow('EMA 20', _formatPrice(one.ema20)),
            _DetailRow('EMA 50', _formatPrice(one.ema50)),
            _DetailRow('EMA 200', _formatPrice(one.ema200)),
            _DetailRow(
              'Relative Volume',
              '${one.relativeVolume.toStringAsFixed(2)}×',
            ),
            _DetailRow('ATR (14)', _formatPrice(one.atr)),
          ],
        ),
        _DetailExpansion(
          title: 'Индикаторы 15м',
          icon: Icons.query_stats_rounded,
          initiallyExpanded: true,
          rows: <_DetailRow>[
            _DetailRow('RSI (14)', fifteen.rsi.toStringAsFixed(2)),
            _DetailRow(
              'MACD / Signal',
              '${fifteen.macd.macd.toStringAsFixed(6)} / '
                  '${fifteen.macd.signal.toStringAsFixed(6)}',
            ),
            _DetailRow(
              'MACD Histogram',
              fifteen.macd.histogram.toStringAsFixed(6),
            ),
            _DetailRow('EMA 20', _formatPrice(fifteen.ema20)),
            _DetailRow('EMA 50', _formatPrice(fifteen.ema50)),
            _DetailRow('EMA 200', _formatPrice(fifteen.ema200)),
            _DetailRow(
              'Relative Volume',
              '${fifteen.relativeVolume.toStringAsFixed(2)}×',
            ),
            _DetailRow('ATR (14)', _formatPrice(fifteen.atr)),
          ],
        ),
        _DetailExpansion(
          title: 'Тренд и структура',
          icon: Icons.account_tree_rounded,
          rows: <_DetailRow>[
            _DetailRow('Тренд 1м', one.trend.label),
            _DetailRow('Тренд 5м', five.trend.label),
            _DetailRow('Тренд 15м', fifteen.trend.label),
            _DetailRow('Тренд 1ч', hour.trend.label),
            _DetailRow(
              'Структура 15м',
              '${fifteen.structure.highLabel} / ${fifteen.structure.lowLabel}',
            ),
            _DetailRow('Направление структуры', fifteen.structure.bias.label),
            _DetailRow('BOS', fifteen.structure.bos.label),
            _DetailRow('CHOCH', fifteen.structure.choch.label),
            _DetailRow(
              'Последний swing high',
              _formatNullablePrice(fifteen.structure.lastSwingHigh),
            ),
            _DetailRow(
              'Последний swing low',
              _formatNullablePrice(fifteen.structure.lastSwingLow),
            ),
          ],
        ),
        _DetailExpansion(
          title: 'Поддержка, сопротивление и ликвидность',
          icon: Icons.water_rounded,
          rows: <_DetailRow>[
            _DetailRow(
              'Поддержка',
              _levelWithDistance(fifteen.support, fifteen.price),
            ),
            _DetailRow(
              'Сопротивление',
              _levelWithDistance(fifteen.resistance, fifteen.price),
            ),
            _DetailRow(
              'Ликвидность сверху',
              _formatNullablePrice(fifteen.liquidity.above),
            ),
            _DetailRow(
              'Ликвидность снизу',
              _formatNullablePrice(fifteen.liquidity.below),
            ),
            _DetailRow(
              'Sweep сверху',
              fifteen.liquidity.sweepAbove ? 'ДА → SHORT' : 'НЕТ',
            ),
            _DetailRow(
              'Sweep снизу',
              fifteen.liquidity.sweepBelow ? 'ДА → LONG' : 'НЕТ',
            ),
          ],
        ),
        _DetailExpansion(
          title: 'FVG — Fair Value Gaps',
          icon: Icons.space_dashboard_rounded,
          rows: <_DetailRow>[
            ..._zoneRows('1м', one.fairValueGaps),
            ..._zoneRows('5м', five.fairValueGaps),
            ..._zoneRows('15м', fifteen.fairValueGaps),
          ],
        ),
        _DetailExpansion(
          title: 'Order Blocks',
          icon: Icons.view_in_ar_rounded,
          rows: <_DetailRow>[
            ..._zoneRows('1м', one.orderBlocks),
            ..._zoneRows('5м', five.orderBlocks),
            ..._zoneRows('15м', fifteen.orderBlocks),
          ],
        ),
        _DetailExpansion(
          title: 'Fibonacci и Ichimoku',
          icon: Icons.auto_graph_rounded,
          rows: <_DetailRow>[
            _DetailRow(
              'Fib swing low',
              _formatPrice(fifteen.fibonacci.swingLow),
            ),
            _DetailRow(
              'Fib swing high',
              _formatPrice(fifteen.fibonacci.swingHigh),
            ),
            _DetailRow(
              'Ближайший Fib',
              '${(fifteen.fibonacci.ratio * 100.0).toStringAsFixed(1)}% • '
                  '${_formatPrice(fifteen.fibonacci.nearestLevel)}',
            ),
            _DetailRow(
              'Ichimoku Tenkan',
              _formatPrice(fifteen.ichimoku.conversion),
            ),
            _DetailRow('Ichimoku Kijun', _formatPrice(fifteen.ichimoku.base)),
            _DetailRow(
              'Облако A / B',
              '${_formatPrice(fifteen.ichimoku.spanA)} / '
                  '${_formatPrice(fifteen.ichimoku.spanB)}',
            ),
            _DetailRow('Ichimoku bias', fifteen.ichimoku.bias.label),
          ],
        ),
        _DetailExpansion(
          title: 'Полный торговый план',
          icon: Icons.assignment_turned_in_rounded,
          rows: <_DetailRow>[
            _DetailRow('Сценарий', snapshot.tradePlan.bias.label),
            _DetailRow(
              'Зона входа',
              '${_formatPrice(snapshot.tradePlan.entryLow)} — '
                  '${_formatPrice(snapshot.tradePlan.entryHigh)}',
            ),
            _DetailRow('Стоп', _formatPrice(snapshot.tradePlan.stop)),
            _DetailRow('TP1', _formatPrice(snapshot.tradePlan.tp1)),
            _DetailRow('TP2', _formatPrice(snapshot.tradePlan.tp2)),
            _DetailRow('Плечо', 'до ${snapshot.tradePlan.leverage}×'),
            _DetailRow('Условие', snapshot.tradePlan.reason),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Обновлено: ${_formatTime(snapshot.updatedAt)} • источник: Bybit linear',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }

  List<_DetailRow> _zoneRows(String timeframe, List<PriceZone> zones) {
    PriceZone? bullishZone;
    PriceZone? bearishZone;
    for (final PriceZone priceZone in zones.reversed) {
      if (priceZone.bias == Bias.bullish && bullishZone == null) {
        bullishZone = priceZone;
      }
      if (priceZone.bias == Bias.bearish && bearishZone == null) {
        bearishZone = priceZone;
      }
      if (bullishZone != null && bearishZone != null) {
        break;
      }
    }
    return <_DetailRow>[
      _DetailRow('$timeframe бычья зона', _formatZone(bullishZone)),
      _DetailRow('$timeframe медвежья зона', _formatZone(bearishZone)),
    ];
  }

  String _formatZone(PriceZone? priceZone) {
    if (priceZone == null) {
      return 'не найдена';
    }
    return '${_formatPrice(priceZone.lower)} — ${_formatPrice(priceZone.upper)}';
  }

  String _formatNullablePrice(double? price) {
    return price == null ? '—' : _formatPrice(price);
  }

  String _levelWithDistance(double? level, double price) {
    if (level == null || price == 0.0) {
      return '—';
    }
    final double distance = (level - price).abs() / price * 100.0;
    return '${_formatPrice(level)} • ${distance.toStringAsFixed(2)}%';
  }
}

String _formatPrice(double value) {
  if (!value.isFinite) {
    return '—';
  }
  if (value.abs() >= 1000.0) {
    return value.toStringAsFixed(2);
  }
  if (value.abs() >= 1.0) {
    return value.toStringAsFixed(4);
  }
  return value.toStringAsFixed(6);
}

String _formatCompactNumber(double value) {
  if (value >= 1000000000.0) {
    return '\$${(value / 1000000000.0).toStringAsFixed(2)}B';
  }
  if (value >= 1000000.0) {
    return '\$${(value / 1000000.0).toStringAsFixed(2)}M';
  }
  if (value >= 1000.0) {
    return '\$${(value / 1000.0).toStringAsFixed(2)}K';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _formatTime(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  final String second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

Color _biasColor(Bias bias) {
  switch (bias) {
    case Bias.bullish:
      return const Color(0xFF38D996);
    case Bias.bearish:
      return const Color(0xFFFF667A);
    case Bias.neutral:
      return const Color(0xFFFFC857);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.snapshot});

  final MarketSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final Bias signalBias = snapshot.signal == 'ПОКУПКА'
        ? Bias.bullish
        : snapshot.signal == 'ПРОДАЖА'
        ? Bias.bearish
        : Bias.neutral;
    final Color accent = _biasColor(signalBias);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: accent.withValues(alpha: 0.08), blurRadius: 24),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool wide = constraints.maxWidth >= 560;
          final Widget priceBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                snapshot.symbol.replaceAll('USDT', ' / USDT'),
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${_formatPrice(snapshot.ticker.price)}',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  Text(
                    '24ч ${snapshot.ticker.change24hPercent >= 0.0 ? '+' : ''}'
                    '${snapshot.ticker.change24hPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: snapshot.ticker.change24hPercent >= 0.0
                          ? const Color(0xFF38D996)
                          : const Color(0xFFFF667A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Оборот ${_formatCompactNumber(snapshot.ticker.turnover24h)}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            ],
          );
          final Widget signalBlock = Column(
            crossAxisAlignment: wide
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: accent.withValues(alpha: 0.55)),
                ),
                child: Text(
                  snapshot.signal,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Сила ${snapshot.strength}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'LONG ${snapshot.longScore} • SHORT ${snapshot.shortScore}',
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 4),
              Text(
                'Обновлено ${_formatTime(snapshot.updatedAt)}',
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Colors.white38),
              ),
            ],
          );
          if (wide) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child: priceBlock),
                const SizedBox(width: 20),
                signalBlock,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              priceBlock,
              const SizedBox(height: 16),
              signalBlock,
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 19, color: const Color(0xFF62E6A7)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TrendCell extends StatelessWidget {
  const _TrendCell({required this.label, required this.bias});

  final String label;
  final Bias bias;

  @override
  Widget build(BuildContext context) {
    final Color color = _biasColor(bias);
    return Column(
      children: <Widget>[
        Text(label, style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 6),
        Icon(
          bias == Bias.bullish
              ? Icons.north_east_rounded
              : bias == Bias.bearish
              ? Icons.south_east_rounded
              : Icons.east_rounded,
          color: color,
        ),
        const SizedBox(height: 3),
        Text(
          bias.label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
  });

  final String label;
  final String value;
  final String note;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: const Color(0xFF62E6A7)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _TradePlanCard extends StatelessWidget {
  const _TradePlanCard({required this.plan, required this.signal});

  final TradePlan plan;
  final String signal;

  @override
  Widget build(BuildContext context) {
    final Color color = _biasColor(plan.bias);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.route_rounded, color: color),
              const SizedBox(width: 8),
              Text(
                'Торговый план • ${plan.bias.label}',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text('до ${plan.leverage}×'),
            ],
          ),
          if (signal == 'ЖДАТЬ') ...<Widget>[
            const SizedBox(height: 6),
            const Text(
              'Предварительный сценарий: вход только после усиления сигнала.',
              style: TextStyle(color: Colors.amberAccent),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            children: <Widget>[
              _PlanValue(
                label: 'Вход',
                value:
                    '${_formatPrice(plan.entryLow)} — ${_formatPrice(plan.entryHigh)}',
              ),
              _PlanValue(label: 'Стоп', value: _formatPrice(plan.stop)),
              _PlanValue(label: 'TP1', value: _formatPrice(plan.tp1)),
              _PlanValue(label: 'TP2', value: _formatPrice(plan.tp2)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanValue extends StatelessWidget {
  const _PlanValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.item});

  final ConfirmationItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              item.value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          _BiasBadge(bias: item.bias),
          const SizedBox(width: 8),
          SizedBox(
            width: 22,
            child: Text(
              '+${item.weight}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiasBadge extends StatelessWidget {
  const _BiasBadge({required this.bias});

  final Bias bias;

  @override
  Widget build(BuildContext context) {
    final Color color = _biasColor(bias);
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        bias.label,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);

  final String label;
  final String value;
}

class _DetailExpansion extends StatelessWidget {
  const _DetailExpansion({
    required this.title,
    required this.icon,
    required this.rows,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<_DetailRow> rows;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        leading: Icon(icon, color: const Color(0xFF62E6A7)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: <Widget>[
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      rows[index].label,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      rows[index].value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            if (index < rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}
