import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../engines/adaptive_grid_engine.dart';
import '../engines/manual_assistant_engine.dart';
import '../models/signal_models.dart';
import '../models/live_market_models.dart';
import '../services/binance_confirmation_service.dart';
import '../services/bybit_service.dart';
import '../services/live_price_service.dart';
import '../services/manual_assistant_controller.dart';

import '../engines/backtest_engine.dart';
import '../services/journal_controller.dart';
import '../services/journal_store.dart';
import '../services/crypto_universe_controller.dart';
import '../widgets/terminal/terminal_common.dart';
import '../widgets/terminal/trading_terminal.dart';
import 'journal_screen.dart';
import 'asset_explorer_screen.dart';
import 'market_scanner_screen.dart';

class ManualAssistantScreen extends StatefulWidget {
  const ManualAssistantScreen({
    super.key,
    this.autoStart = true,
    this.controller,
  });

  final bool autoStart;
  final ManualAssistantController? controller;

  @override
  State<ManualAssistantScreen> createState() => _ManualAssistantScreenState();
}

class _ManualAssistantScreenState extends State<ManualAssistantScreen> {
  late final http.Client _client;
  late final ManualAssistantController c;
  late final BybitService _bybit;
  late final JournalController _journal;
  late final CryptoUniverseController _universe;
  int _tab = 0;
  String? _auxError;

  @override
  void initState() {
    super.initState();
    _client = http.Client();
    _bybit = BybitService(_client);
    _journal = JournalController(
      store: JournalStore(),
      backtestEngine: BacktestEngine(bybitService: _bybit),
    );
    _universe = CryptoUniverseController(service: _bybit);
    if (widget.autoStart) unawaited(_loadJournal());
    c =
        widget.controller ??
        ManualAssistantController(
          provider: _bybit,
          live: LivePriceService(),
          confirmationProvider: BinanceConfirmationService(_client),
        );
    if (widget.autoStart) unawaited(c.initialize());
  }

  @override
  void dispose() {
    if (widget.controller == null) c.dispose();
    _client.close();
    _journal.dispose();
    _universe.dispose();
    super.dispose();
  }

  String n(double? value, [int digits = 5]) =>
      value == null || !value.isFinite ? '—' : value.toStringAsFixed(digits);

  Widget panel(String title, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  Widget line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text('$label: $value', style: const TextStyle(fontSize: 13)),
  );

  Future<void> _loadJournal() async {
    try {
      await _journal.initialize();
    } catch (error) {
      if (mounted) setState(() => _auxError = 'Журнал: ' + error.toString());
    }
  }

  void _select(int index) {
    setState(() => _tab = index);
    if ((index == 4 || index == 5) &&
        widget.autoStart &&
        !_universe.initialized) {
      unawaited(_universe.initialize());
    }
  }

  void _inspectAsset(String symbol) {
    if (symbol == 'FARTCOINUSDT') {
      _select(0);
      return;
    }
    final assets = _universe.assets.where((asset) => asset.symbol == symbol);
    if (assets.isEmpty) return;
    final asset = assets.first;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(symbol),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            line('Цена', n(asset.lastPrice)),
            line('Изменение 24ч', n(asset.change24hPercent, 2) + '%'),
            line('Объём 24ч USDT', compact(asset.turnover24h)),
            const Text('Торговый помощник сейчас настроен на FARTCOINUSDT.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, child) {
      final wide = MediaQuery.sizeOf(context).width >= 1250;
      Widget body;
      if (_tab == 0) {
        body = TradingTerminal(
          controller: c,
          journal: _journal,
          onPosition: () => _select(1),
          onJournal: () => _select(6),
          onGrid: () => _select(2),
        );
      } else if (_tab == 6) {
        body = JournalScreen(controller: _journal);
      } else if (_tab == 4) {
        body = AssetExplorerScreen(
          controller: _universe,
          selectedSymbol: 'FARTCOINUSDT',
          selectedSnapshot: c.markets['FARTCOINUSDT'],
          onSelect: _inspectAsset,
        );
      } else if (_tab == 5) {
        body = MarketScannerScreen(
          controller: _universe,
          onSelect: _inspectAsset,
        );
      } else {
        body = ListView(
          padding: const EdgeInsets.all(12),
          children: _tab == 1
              ? _position(c.result)
              : _tab == 2
              ? _grid(c.grid)
              : _settings(),
        );
      }
      return Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: TerminalStyle.bg,
          colorScheme: const ColorScheme.dark(
            primary: TerminalStyle.cyan,
            surface: TerminalStyle.panel,
          ),
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: TerminalStyle.text,
            displayColor: TerminalStyle.text,
          ),
        ),
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(wide ? 66 : 110),
            child: SafeArea(
              child: TradingHeader(
                selected: _tab,
                onSelect: _select,
                live: c.liveEnabled,
                status: c.loading.isNotEmpty
                    ? 'Обновление'
                    : c.live.status.label,
                onLive: c.liveChanging
                    ? null
                    : (value) => c.setLiveEnabled(value),
                onRefresh: () => c.refresh(),
              ),
            ),
          ),
          body: Column(
            children: [
              if (_auxError != null)
                Text(
                  _auxError!,
                  style: const TextStyle(color: TerminalStyle.amber),
                ),
              Expanded(child: body),
            ],
          ),
        ),
      );
    },
  );

  List<Widget> _position(AssistantResult? result) {
    final ManualPosition? position = c.position;
    return <Widget>[
      panel('Моя фактическая позиция', <Widget>[
        const Text(
          'Здесь только ручные отметки. Кнопки не меняют ордера на бирже.',
        ),
        if (position == null) ...<Widget>[
          const SizedBox(height: 12),
          const Text(
            'Открытая позиция не отмечена. Сигнал не создаёт запись автоматически.',
          ),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final SignalDirection side in SignalDirection.values)
                FilledButton(
                  onPressed: () => _openPosition(side),
                  child: Text('Я открыл ${side.name.toUpperCase()}'),
                ),
            ],
          ),
        ] else ...<Widget>[
          if (result != null)
            Text(
              _displayState(result.state),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: _stateColor(result.state),
                fontWeight: FontWeight.bold,
              ),
            ),
          line(
            'Позиция',
            '${position.side.name.toUpperCase()} · ${n(position.quantity, 3)} FART',
          ),
          line(
            'Entry / текущий SL',
            '${n(position.entry)} / ${n(position.stop)}',
          ),
          if (result?.positionMovePercent != null)
            line(
              'Движение от Entry',
              '${result!.positionMovePercent!.toStringAsFixed(2)}%',
            ),
          if (result?.dynamicRiskReward != null)
            line(
              'R:R от текущей цены до следующей цели',
              result!.dynamicRiskReward!.toStringAsFixed(2),
            ),
          if (result?.entryOutsidePlannedZone == true)
            const Text(
              '⚠️ Фактический Entry был вне плановой зоны. Это не требует автоматического выхода, но добавляться к позиции не стоит.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          if (position.qualityAtOpen != null)
            line('Качество при открытии', '${position.qualityAtOpen}/100'),
          if (position.entryLowAtOpen != null &&
              position.entryHighAtOpen != null)
            line(
              'Плановая Entry Zone при открытии',
              '${n(position.entryLowAtOpen)} — ${n(position.entryHighAtOpen)}',
            ),
          if (position.plannedTargets.isNotEmpty)
            line(
              'Цели при открытии',
              position.plannedTargets.indexed
                  .map<String>((e) => 'TP${e.$1 + 1} ${n(e.$2)}')
                  .join(' · '),
            ),
          if (result != null) ...<Widget>[
            Text(result.action),
            if (result.threat)
              const Text(
                'EXTERNAL THREAT · не добавлять к позиции',
                style: TextStyle(color: Colors.orangeAccent),
              ),
            line(
              'Нереализованный результат без расходов',
              '${n((result.price - position.entry) * position.sign * position.quantity, 2)} USDT',
            ),
            if (result.suggestedStop != null)
              line(
                'Структурная защита — рекомендация',
                n(result.suggestedStop),
              ),
            const SizedBox(height: 8),
            const Text(
              'Три правила: держать, защищать или выходить — без расширения первоначального Stop.',
            ),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: () =>
                    _numbers('Я изменил SL на бирже', <String, String>{
                      'Новый SL': n(result?.suggestedStop ?? position.stop),
                    }, (List<double> values) => c.recordStop(values[0])),
                child: const Text('Отметить новый SL'),
              ),
              OutlinedButton(
                onPressed: () =>
                    _numbers('Я частично закрыл позицию', <String, String>{
                      'Оставшееся количество FART': n(position.quantity / 2, 3),
                    }, (List<double> values) => c.recordPartial(values[0])),
                child: const Text('Частичная фиксация'),
              ),
              OutlinedButton(
                onPressed: _closePosition,
                child: const Text('Я закрыл позицию'),
              ),
            ],
          ),
        ],
      ]),
      panel('История ручных отметок', <Widget>[
        const Text(
          'Это журнал действий, а не расчёт реализованной доходности.',
        ),
        ...c.history.reversed
            .take(30)
            .map<Widget>((e) => line('${e['event']}', '${e['time']}')),
        if (c.history.isEmpty) const Text('Пока пусто'),
        TextButton(
          onPressed: () => _export(c.export()),
          child: const Text('Экспорт отметок и настроек'),
        ),
        TextButton(
          onPressed: () async {
            final String text = await c.exportLegacy();
            if (mounted) _export(text);
          },
          child: const Text('Экспорт прежнего журнала без удаления'),
        ),
      ]),
    ];
  }

  List<Widget> _grid(AdaptiveGridAssessment? grid) => <Widget>[
    panel('Adaptive Futures Grid · анализ без ордеров', <Widget>[
      const Text(
        'Grid не запускается автоматически. Этот блок только оценивает, подходит ли текущий рынок FARTCOIN для сетки.',
      ),
      if (grid == null)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('GRID WAIT · ожидаем корректные данные.'),
        )
      else ...<Widget>[
        const SizedBox(height: 12),
        Text(
          grid.state.label,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            color: switch (grid.state) {
              AdaptiveGridState.ready => Colors.greenAccent,
              AdaptiveGridState.wait => Colors.amberAccent,
              AdaptiveGridState.danger => Colors.orangeAccent,
              AdaptiveGridState.off => Colors.redAccent,
            },
          ),
        ),
        line('Режим', grid.mode.label),
        line(
          'Диапазон',
          grid.hasRange ? '${n(grid.rangeLow)} — ${n(grid.rangeHigh)}' : '—',
        ),
        line(
          'Позиция цены',
          '${grid.pricePositionPercent.toStringAsFixed(1)}%',
        ),
        line(
          'Grid Quality',
          '${grid.rangeQuality}/100 · не вероятность прибыли',
        ),
        line('Breakout Risk', '${grid.breakoutRisk}/100 · эвристический риск'),
        line('Шаг', '${grid.stepPercent.toStringAsFixed(2)}%'),
        line('Уровни', '${grid.levels}'),
        line('Рекомендованное плечо', '${grid.recommendedLeverage}×'),
        const SizedBox(height: 8),
        ...grid.reasons.map<Widget>((String reason) => Text('• $reason')),
        if (grid.state == AdaptiveGridState.danger)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'GRID DANGER: не наращивать сетку до возврата структуры.',
              style: TextStyle(color: Colors.orangeAccent),
            ),
          ),
      ],
    ]),
  ];

  List<Widget> _settings() => <Widget>[
    panel('Расчёт риска', <Widget>[
      line('Баланс', '${n(c.balance, 2)} USDT'),
      line('Риск', '${n(c.riskPercent, 2)}% · максимум 2%'),
      line('Максимальное плечо', '${c.maxLeverage}×'),
      line(
        'Минимальный потенциал continuation',
        '${n(c.minPotentialPercent, 2)}%',
      ),
      line('Комиссия taker', '${n(c.fees.takerFeePercent, 3)}% на сторону'),
      line(
        'Проскальзывание',
        '${n(c.fees.entrySlippagePercent, 3)}% на сторону',
      ),
      FilledButton(
        onPressed: () => _numbers(
          'Параметры расчёта',
          <String, String>{
            'Баланс USDT': '${c.balance}',
            'Риск %': '${c.riskPercent}',
            'Плечо 1–10': '${c.maxLeverage}',
            'Потенциал continuation %': '${c.minPotentialPercent}',
            'Комиссия %': '${c.fees.takerFeePercent}',
            'Проскальзывание %': '${c.fees.entrySlippagePercent}',
          },
          (List<double> values) => c.configure(
            equity: values[0],
            risk: values[1],
            leverage: values[2].toInt(),
            potential: values[3],
            fee: values[4],
            slippage: values[5],
          ),
        ),
        child: const Text('Изменить параметры'),
      ),
    ]),
    panel('Как использовать', const <Widget>[
      Text(
        '1. Выберите continuation или scalp.\n'
        '2. READY требует зоны, подтверждения, структуры и нормального R:R.\n'
        '3. Binance и BTC/ETH/SOL подтверждают или ослабляют, но нейтральность не блокирует вход.\n'
        '4. После фактического входа отметьте позицию.\n'
        '5. ВСЁ ПО ПЛАНУ / ДЕРЖАТЬ-ЗАЩИЩАТЬ / СРОЧНО ЗАКРЫТЬ — рекомендации; действия выполняются вручную.',
      ),
      SizedBox(height: 12),
      Text(
        'Данные: Bybit — основной источник. Binance — подтверждение. REST обновляется раз в 15 секунд и сразу после закрытия новой 1m свечи; цена идёт через WebSocket. При устаревании критических данных вход не разрешается. Программа работает, пока открыта вкладка; 24/7 Core будет отдельным серверным этапом.',
      ),
    ]),
  ];

  String _displayState(String state) => switch (state) {
    'READY' => '🟢 READY',
    'WAIT' => '🟡 WAIT',
    'NO TRADE' => '🔴 NO TRADE',
    'HOLD' => '🟢 ВСЁ ПО ПЛАНУ',
    'PROTECT' => '🟡 ДЕРЖАТЬ / ЗАЩИЩАТЬ',
    'EXIT' => '🔴 СРОЧНО ЗАКРЫТЬ',
    _ => state,
  };

  Color _stateColor(String state) => switch (state) {
    'READY' => Colors.greenAccent,
    'HOLD' => Colors.greenAccent,
    'EXIT' => Colors.redAccent,
    'NO TRADE' => Colors.redAccent,
    _ => Colors.orangeAccent,
  };

  Future<void> _openPosition(SignalDirection side) => _numbers(
    'Фактический ${side.name.toUpperCase()} на Bybit',
    <String, String>{
      'Фактическая цена входа': n(c.result?.price),
      'Фактически установленный SL': n(c.result?.decision.stop),
      'Количество FART': n(c.result?.economics?.quantity, 3),
    },
    (List<double> values) => c.recordOpen(
      side: side,
      entry: values[0],
      stop: values[1],
      quantity: values[2],
    ),
  );

  Future<void> _closePosition() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Позиция уже закрыта на бирже?'),
        content: const Text('Будет закрыта только локальная запись.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Назад'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Да, закрыта'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) c.recordClose();
  }

  Future<void> _numbers(
    String title,
    Map<String, String> fields,
    void Function(List<double>) apply,
  ) async {
    final List<TextEditingController> controls = fields.values
        .map<TextEditingController>(
          (String value) =>
              TextEditingController(text: value == '—' ? '' : value),
        )
        .toList();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter update) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ...fields.keys.indexed.map<Widget>(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: controls[e.$1],
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(labelText: e.$2),
                    ),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Назад'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final List<double> values = controls
                      .map<double>(
                        (TextEditingController value) => double.parse(
                          value.text.replaceAll(',', '.').trim(),
                        ),
                      )
                      .toList();
                  if (values.any((double value) => !value.isFinite)) {
                    throw const FormatException('Нужны конечные числа');
                  }
                  apply(values);
                  Navigator.pop(ctx);
                } catch (exception) {
                  update(() => error = '$exception');
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
    for (final TextEditingController control in controls) {
      control.dispose();
    }
  }

  Future<void> _export(String text) => showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => AlertDialog(
      title: const Text('Локальный экспорт'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(child: SelectableText(text)),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Clipboard.setData(ClipboardData(text: text)),
          child: const Text('Копировать'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
