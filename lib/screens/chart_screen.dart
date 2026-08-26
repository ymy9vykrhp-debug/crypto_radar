import 'package:flutter/material.dart';

import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../models/execution_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../widgets/market_candlestick_chart.dart';

class ChartScreen extends StatefulWidget {
  const ChartScreen({
    super.key,
    required this.snapshot,
    required this.journalController,
  });

  final MarketSnapshot snapshot;
  final JournalController journalController;

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  String _timeframe = '5м';
  int _visibleBars = 120;

  TimeframeAnalysis get _analysis {
    switch (_timeframe) {
      case '1м':
        return widget.snapshot.oneMinute;
      case '15м':
        return widget.snapshot.fifteenMinutes;
      case '1ч':
        return widget.snapshot.oneHour;
      case '5м':
      default:
        return widget.snapshot.fiveMinutes;
    }
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
    final RadarSignal? candidate = _timeframe == '1м'
        ? SignalEngine.createScalpSignal(widget.snapshot)
        : SignalEngine.createSignal(widget.snapshot);
    if (candidate == null) return null;
    return PhaseAEngine.preview(market: widget.snapshot, signal: candidate);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.journalController,
      builder: (BuildContext context, Widget? child) {
        final RadarSignal? signal = _signal();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: <Widget>[
              _buildControls(),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B1220),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: MarketCandlestickChart(
                    analysis: _analysis,
                    signal: signal,
                    visibleBars: _visibleBars,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildLegend(signal),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    return Row(
      children: <Widget>[
        const Icon(Icons.candlestick_chart_rounded, color: Color(0xFF62E6A7)),
        const SizedBox(width: 8),
        Text(
          '${widget.snapshot.symbol} • собственный анализ',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 16),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(value: '1м', label: Text('1м')),
            ButtonSegment<String>(value: '5м', label: Text('5м')),
            ButtonSegment<String>(value: '15м', label: Text('15м')),
            ButtonSegment<String>(value: '1ч', label: Text('1ч')),
          ],
          selected: <String>{_timeframe},
          onSelectionChanged: (Set<String> selected) {
            setState(() => _timeframe = selected.first);
          },
        ),
        const Spacer(),
        DropdownButton<int>(
          value: _visibleBars,
          underline: const SizedBox.shrink(),
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 60, child: Text('60 свечей')),
            DropdownMenuItem<int>(value: 120, child: Text('120 свечей')),
            DropdownMenuItem<int>(value: 200, child: Text('200 свечей')),
          ],
          onChanged: (int? value) {
            if (value != null) setState(() => _visibleBars = value);
          },
        ),
      ],
    );
  }

  Widget _buildLegend(RadarSignal? signal) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 8,
        children: <Widget>[
          const _Legend(color: Color(0xFF5B8CFF), label: 'EMA20 / ENTRY'),
          const _Legend(color: Color(0xFFFFC857), label: 'EMA50 / Liquidity'),
          const _Legend(color: Color(0xFF45D69A), label: 'LONG / TP'),
          const _Legend(color: Color(0xFFFF5C7C), label: 'SHORT / STOP'),
          Text(
            signal == null
                ? 'Активного торгового плана нет'
                : '${signal.direction.label} • ${signal.stage.code} • '
                      '${signal.executionAction}',
            style: const TextStyle(color: Colors.white70),
          ),
          const Text(
            'Только анализ: ордера в Bybit не отправляются.',
            style: TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 14, height: 3, color: color),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white54)),
      ],
    );
  }
}
