import 'package:flutter/material.dart';

import '../engines/chart_overlay_engine.dart';
import '../engines/decision_engine.dart';
import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../models/chart_models.dart';
import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/bybit_service.dart';
import '../services/chart_view_controller.dart';
import '../services/journal_controller.dart';
import '../widgets/chart_indicator_panel.dart';
import '../widgets/market_candlestick_chart.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({
    super.key,
    required this.snapshot,
    required this.journalController,
    required this.bybitService,
    this.onOpenWhy,
  });

  final MarketSnapshot snapshot;
  final JournalController journalController;
  final BybitService bybitService;
  final VoidCallback? onOpenWhy;

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final ChartViewportController _viewport = ChartViewportController();
  final ChartSettingsController _settings = ChartSettingsController();
  final Map<ChartTimeframe, List<Candle>> _history =
      <ChartTimeframe, List<Candle>>{};
  ChartTimeframe _timeframe = ChartTimeframe.fiveMinutes;
  bool _historyLoading = false;
  String? _historyError;
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _seedSnapshotHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  @override
  void didUpdateWidget(covariant ChartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.symbol != widget.snapshot.symbol) {
      _loadToken++;
      _history.clear();
      _historyError = null;
      _viewport.reset(0);
      _seedSnapshotHistory();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
    } else {
      _mergeSnapshotHistory();
    }
  }

  @override
  void dispose() {
    _viewport.dispose();
    _settings.dispose();
    super.dispose();
  }

  TimeframeAnalysis? get _analysis {
    switch (_timeframe) {
      case ChartTimeframe.oneMinute:
        return widget.snapshot.oneMinute;
      case ChartTimeframe.fiveMinutes:
        return widget.snapshot.fiveMinutes;
      case ChartTimeframe.fifteenMinutes:
        return widget.snapshot.fifteenMinutes;
      case ChartTimeframe.oneHour:
        return widget.snapshot.oneHour;
      case ChartTimeframe.fourHours:
        return null;
    }
  }

  List<Candle> get _candles {
    final List<Candle>? loaded = _history[_timeframe];
    if (loaded != null && loaded.isNotEmpty) return loaded;
    if (_timeframe == ChartTimeframe.fourHours) {
      return _aggregateFourHours(widget.snapshot.oneHour.candles);
    }
    return _analysis!.candles;
  }

  RadarSignal? _signal() {
    final List<RadarSignal> matching = widget.journalController.signals
        .where((RadarSignal signal) => signal.symbol == widget.snapshot.symbol)
        .toList(growable: false);
    if (matching.isNotEmpty) {
      for (final RadarSignal signal in matching) {
        if (signal.status.isActive) return signal;
      }
      return matching.first;
    }
    final RadarSignal? candidate = _timeframe == ChartTimeframe.oneMinute
        ? SignalEngine.createScalpSignal(widget.snapshot)
        : SignalEngine.createSignal(widget.snapshot);
    if (candidate == null) return null;
    return PhaseAEngine.preview(market: widget.snapshot, signal: candidate);
  }

  DecisionSnapshot _decision(RadarSignal? signal) {
    return DecisionEngine.build(widget.snapshot, executionSignal: signal);
  }

  ChartOverlayData _overlay(
    List<Candle> candles,
    RadarSignal? signal,
    DecisionSnapshot decision,
  ) {
    return ChartOverlayEngine.build(
      market: widget.snapshot,
      timeframe: _timeframe,
      candles: candles,
      analysis: _analysis,
      signal: signal,
      decision: decision,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.journalController,
      builder: (BuildContext context, Widget? child) {
        final List<Candle> candles = _candles;
        final RadarSignal? signal = _signal();
        final DecisionSnapshot decision = _decision(signal);
        final ChartOverlayData overlay = _overlay(candles, signal, decision);
        return AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_viewport, _settings]),
          builder: (BuildContext context, Widget? child) {
            return _workspace(
              context: context,
              candles: candles,
              signal: signal,
              decision: decision,
              overlay: overlay,
              fullscreen: false,
            );
          },
        );
      },
    );
  }

  Widget _workspace({
    required BuildContext context,
    required List<Candle> candles,
    required RadarSignal? signal,
    required DecisionSnapshot decision,
    required ChartOverlayData overlay,
    required bool fullscreen,
  }) {
    final List<ChartIndicator> subpanels = _settings.indicators
        .where((ChartIndicator indicator) => indicator.usesSubpanel)
        .toList(growable: false);
    return Padding(
      padding: EdgeInsets.fromLTRB(12, fullscreen ? 4 : 8, 12, 10),
      child: Column(
        children: <Widget>[
          _controls(
            context: context,
            candles: candles,
            fullscreen: fullscreen,
            signal: signal,
            decision: decision,
            overlay: overlay,
          ),
          if (_historyLoading) ...<Widget>[
            const SizedBox(height: 4),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (_historyError != null) ...<Widget>[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _historyError!,
                style: const TextStyle(color: Color(0xFFFFC857), fontSize: 11),
              ),
            ),
          ],
          if (_settings.whyMode) ...<Widget>[
            const SizedBox(height: 6),
            _whyStrip(decision),
          ],
          const SizedBox(height: 7),
          Expanded(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double panelsHeight = subpanels.isEmpty
                    ? 0
                    : (constraints.maxHeight * 0.36).clamp(110, 250);
                return Column(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1220),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: MarketCandlestickChart(
                          candles: candles,
                          overlay: overlay,
                          viewportController: _viewport,
                          settingsController: _settings,
                          onHit: (ChartHit hit) =>
                              _handleHit(context, hit, fullscreen: fullscreen),
                        ),
                      ),
                    ),
                    if (subpanels.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 5),
                      SizedBox(
                        height: panelsHeight,
                        child: ListView(
                          children: subpanels
                              .map<Widget>(
                                (ChartIndicator indicator) =>
                                    ChartIndicatorPanel(
                                      indicator: indicator,
                                      candles: candles,
                                      viewportController: _viewport,
                                      settingsController: _settings,
                                    ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          _statusBar(signal, candles),
        ],
      ),
    );
  }

  Widget _controls({
    required BuildContext context,
    required List<Candle> candles,
    required bool fullscreen,
    required RadarSignal? signal,
    required DecisionSnapshot decision,
    required ChartOverlayData overlay,
  }) {
    return Row(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.candlestick_chart_rounded,
                  color: Color(0xFF62E6A7),
                ),
                const SizedBox(width: 7),
                Text(
                  '${widget.snapshot.symbol} • CHART',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                SegmentedButton<ChartTimeframe>(
                  showSelectedIcon: false,
                  segments: ChartTimeframe.values
                      .map<ButtonSegment<ChartTimeframe>>(
                        (ChartTimeframe timeframe) =>
                            ButtonSegment<ChartTimeframe>(
                              value: timeframe,
                              label: Text(timeframe.label),
                            ),
                      )
                      .toList(growable: false),
                  selected: <ChartTimeframe>{_timeframe},
                  onSelectionChanged: (Set<ChartTimeframe> selected) {
                    _selectTimeframe(selected.first);
                  },
                ),
                const SizedBox(width: 8),
                _toolButton(
                  icon: Icons.zoom_in_rounded,
                  tooltip: 'Zoom in',
                  onPressed: () => _viewport.zoomIn(candles.length),
                ),
                _toolButton(
                  icon: Icons.zoom_out_rounded,
                  tooltip: 'Zoom out',
                  onPressed: () => _viewport.zoomOut(candles.length),
                ),
                _toolButton(
                  icon: Icons.fit_screen_rounded,
                  tooltip: 'Fit to screen',
                  onPressed: () => _viewport.fitToScreen(candles.length),
                ),
                _toolButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: 'К текущей свече',
                  onPressed: _viewport.goToLatest,
                ),
                _toolButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset',
                  onPressed: () => _viewport.reset(candles.length),
                ),
                _toolButton(
                  icon: fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: fullscreen ? 'Выйти из fullscreen' : 'Fullscreen',
                  onPressed: () {
                    if (fullscreen) {
                      Navigator.of(context).pop();
                    } else {
                      _openFullscreen(
                        context,
                        candles: candles,
                        signal: signal,
                        decision: decision,
                        overlay: overlay,
                      );
                    }
                  },
                ),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: _viewport.historyBars,
                  underline: const SizedBox.shrink(),
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(
                      value: 100,
                      child: Text('100 свечей'),
                    ),
                    DropdownMenuItem<int>(
                      value: 200,
                      child: Text('200 свечей'),
                    ),
                    DropdownMenuItem<int>(
                      value: 300,
                      child: Text('300 свечей'),
                    ),
                    DropdownMenuItem<int>(
                      value: 500,
                      child: Text('500 свечей'),
                    ),
                  ],
                  onChanged: (int? value) {
                    if (value != null) {
                      _viewport.setHistoryBars(value, candles.length);
                    }
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showLayerDialog(context),
                  icon: const Icon(Icons.layers_rounded, size: 17),
                  label: Text('Слои ${_settings.layers.length}'),
                ),
                const SizedBox(width: 5),
                OutlinedButton.icon(
                  onPressed: () => _showIndicatorDialog(context),
                  icon: const Icon(Icons.monitor_heart_outlined, size: 17),
                  label: Text('Индикаторы ${_settings.indicators.length}'),
                ),
                const SizedBox(width: 5),
                FilterChip(
                  avatar: const Icon(Icons.help_outline_rounded, size: 16),
                  label: const Text('ПОЧЕМУ?'),
                  selected: _settings.whyMode,
                  onSelected: (_) => _settings.toggleWhyMode(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
    );
  }

  Widget _whyStrip(DecisionSnapshot decision) {
    final List<String> reasons = <String>[
      ...decision.reasonCodes.map<String>((ReasonCode reason) => reason.code),
      ...decision.warningCodes.map<String>((ReasonCode reason) => reason.code),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFC857).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFFFC857).withValues(alpha: 0.25),
        ),
      ),
      child: Wrap(
        spacing: 7,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            '${decision.decision.label} • ${decision.entryDecision.label}',
            style: const TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w900,
            ),
          ),
          for (final String code in reasons.take(7))
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(code, style: const TextStyle(fontSize: 9)),
            ),
        ],
      ),
    );
  }

  Widget _statusBar(RadarSignal? signal, List<Candle> candles) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 15,
        runSpacing: 5,
        children: <Widget>[
          _status(Icons.mouse_rounded, 'Wheel: zoom'),
          _status(Icons.pan_tool_alt_rounded, 'Drag: история'),
          _status(Icons.control_camera_rounded, 'Crosshair: OHLCV'),
          Text(
            '${candles.length} загружено • показано '
            '${_viewport.visibleCount(candles.length)}',
            style: const TextStyle(color: Colors.white54),
          ),
          Text(
            signal == null
                ? 'Активного плана нет'
                : '${signal.direction.label} • ${signal.stage.code}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (_timeframe == ChartTimeframe.fourHours)
            const Text(
              '4h — визуальный таймфрейм; торговые правила не изменены.',
              style: TextStyle(color: Color(0xFFFFC857)),
            ),
          const Text(
            'Только анализ — без отправки ордеров.',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _status(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }

  Future<void> _selectTimeframe(ChartTimeframe timeframe) async {
    if (_timeframe == timeframe) return;
    setState(() {
      _timeframe = timeframe;
      _historyError = null;
    });
    _viewport.fitToScreen(_candles.length);
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final ChartTimeframe requestedTimeframe = _timeframe;
    final String requestedSymbol = widget.snapshot.symbol;
    final int token = ++_loadToken;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final List<Candle> loaded = await widget.bybitService.loadCandles(
        requestedSymbol,
        requestedTimeframe.bybitInterval,
        limit: 500,
      );
      if (!mounted ||
          token != _loadToken ||
          requestedSymbol != widget.snapshot.symbol) {
        return;
      }
      setState(() {
        _history[requestedTimeframe] = loaded;
      });
      if (requestedTimeframe == _timeframe) {
        _viewport.syncTotal(loaded.length);
      }
    } on Object {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _historyError =
            'История 500 свечей недоступна; показаны уже загруженные данные.';
      });
    } finally {
      if (mounted && token == _loadToken) {
        setState(() => _historyLoading = false);
      }
    }
  }

  void _seedSnapshotHistory() {
    _history[ChartTimeframe.oneMinute] = widget.snapshot.oneMinute.candles;
    _history[ChartTimeframe.fiveMinutes] = widget.snapshot.fiveMinutes.candles;
    _history[ChartTimeframe.fifteenMinutes] =
        widget.snapshot.fifteenMinutes.candles;
    _history[ChartTimeframe.oneHour] = widget.snapshot.oneHour.candles;
    _history[ChartTimeframe.fourHours] = _aggregateFourHours(
      widget.snapshot.oneHour.candles,
    );
  }

  void _mergeSnapshotHistory() {
    _history[ChartTimeframe.oneMinute] = _merge(
      _history[ChartTimeframe.oneMinute],
      widget.snapshot.oneMinute.candles,
    );
    _history[ChartTimeframe.fiveMinutes] = _merge(
      _history[ChartTimeframe.fiveMinutes],
      widget.snapshot.fiveMinutes.candles,
    );
    _history[ChartTimeframe.fifteenMinutes] = _merge(
      _history[ChartTimeframe.fifteenMinutes],
      widget.snapshot.fifteenMinutes.candles,
    );
    _history[ChartTimeframe.oneHour] = _merge(
      _history[ChartTimeframe.oneHour],
      widget.snapshot.oneHour.candles,
    );
  }

  List<Candle> _merge(List<Candle>? history, List<Candle> latest) {
    final Map<int, Candle> byTime = <int, Candle>{};
    for (final Candle candle in <Candle>[...?history, ...latest]) {
      byTime[candle.time.millisecondsSinceEpoch] = candle;
    }
    final List<Candle> result = byTime.values.toList()
      ..sort(
        (Candle first, Candle second) => first.time.compareTo(second.time),
      );
    if (result.length > 500) {
      return result.sublist(result.length - 500);
    }
    return result;
  }

  List<Candle> _aggregateFourHours(List<Candle> hourly) {
    if (hourly.isEmpty) return const <Candle>[];
    final Map<int, List<Candle>> groups = <int, List<Candle>>{};
    for (final Candle candle in hourly) {
      final int key =
          candle.time.toUtc().millisecondsSinceEpoch ~/
          const Duration(hours: 4).inMilliseconds;
      groups.putIfAbsent(key, () => <Candle>[]).add(candle);
    }
    final List<int> keys = groups.keys.toList()..sort();
    return keys
        .map<Candle>((int key) {
          final List<Candle> group = groups[key]!;
          double high = group.first.high;
          double low = group.first.low;
          double volume = 0;
          for (final Candle candle in group) {
            if (candle.high > high) high = candle.high;
            if (candle.low < low) low = candle.low;
            volume += candle.volume;
          }
          return Candle(
            time: DateTime.fromMillisecondsSinceEpoch(
              key * const Duration(hours: 4).inMilliseconds,
              isUtc: true,
            ),
            open: group.first.open,
            high: high,
            low: low,
            close: group.last.close,
            volume: volume,
          );
        })
        .toList(growable: false);
  }

  Future<void> _showLayerDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: _settings,
          builder: (BuildContext context, Widget? child) {
            return AlertDialog(
              title: const Row(
                children: <Widget>[
                  Icon(Icons.layers_rounded),
                  SizedBox(width: 8),
                  Text('Слои графика'),
                ],
              ),
              content: SizedBox(
                width: 430,
                height: 480,
                child: ListView(
                  children: <Widget>[
                    const Text(
                      'По умолчанию включены только основные торговые уровни.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 8),
                    for (final ChartLayer layer in ChartLayer.values)
                      CheckboxListTile(
                        dense: true,
                        value: _settings.layerEnabled(layer),
                        title: Text(layer.label),
                        onChanged: (_) => _settings.toggleLayer(layer),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ГОТОВО'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showIndicatorDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AnimatedBuilder(
          animation: _settings,
          builder: (BuildContext context, Widget? child) {
            return AlertDialog(
              title: const Row(
                children: <Widget>[
                  Icon(Icons.monitor_heart_outlined),
                  SizedBox(width: 8),
                  Text('Индикаторы'),
                ],
              ),
              content: SizedBox(
                width: 430,
                child: ListView(
                  shrinkWrap: true,
                  children: <Widget>[
                    for (final ChartIndicator indicator
                        in ChartIndicator.values)
                      CheckboxListTile(
                        dense: true,
                        value: _settings.indicatorEnabled(indicator),
                        title: Text(indicator.label),
                        subtitle: indicator.usesSubpanel
                            ? const Text('Отдельная сворачиваемая панель')
                            : const Text('Поверх свечного графика'),
                        onChanged: (_) => _settings.toggleIndicator(indicator),
                      ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ГОТОВО'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openFullscreen(
    BuildContext context, {
    required List<Candle> candles,
    required RadarSignal? signal,
    required DecisionSnapshot decision,
    required ChartOverlayData overlay,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext fullscreenContext) {
          return Scaffold(
            appBar: AppBar(
              title: Text('${widget.snapshot.symbol} • FULLSCREEN CHART'),
              leading: IconButton(
                tooltip: 'Закрыть fullscreen',
                onPressed: () => Navigator.of(fullscreenContext).pop(),
                icon: const Icon(Icons.close_fullscreen_rounded),
              ),
            ),
            body: AnimatedBuilder(
              animation: Listenable.merge(<Listenable>[_viewport, _settings]),
              builder: (BuildContext context, Widget? child) {
                return _workspace(
                  context: context,
                  candles: candles,
                  signal: signal,
                  decision: decision,
                  overlay: overlay,
                  fullscreen: true,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleHit(
    BuildContext context,
    ChartHit hit, {
    required bool fullscreen,
  }) async {
    if (hit.kind == ChartHitKind.signal) {
      if (fullscreen) {
        Navigator.of(context).pop();
      }
      if (widget.onOpenWhy != null) {
        widget.onOpenWhy!();
        return;
      }
      final TabController? tabs = DefaultTabController.maybeOf(this.context);
      if (tabs != null) {
        tabs.animateTo(3);
        return;
      }
    }
    final BuildContext dialogContext = fullscreen ? this.context : context;
    await showDialog<void>(
      context: dialogContext,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(hit.title),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: hit.details.entries
                  .map<Widget>(
                    (MapEntry<String, String> entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          SizedBox(
                            width: 110,
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ЗАКРЫТЬ'),
            ),
          ],
        );
      },
    );
  }
}
