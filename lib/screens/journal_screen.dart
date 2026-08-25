import 'package:flutter/material.dart';

import '../models/backtest_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/journal_controller.dart';
import '../widgets/risk_reward_table.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key, required this.controller});

  final JournalController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        if (!controller.initialized) {
          return const Center(child: CircularProgressIndicator());
        }
        final JournalStatistics statistics = controller.statistics;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            _JournalHeader(
              running: controller.backtestRunning,
              onRun: controller.runInitialBacktests,
            ),
            if (controller.error != null) ...<Widget>[
              const SizedBox(height: 10),
              _ErrorCard(message: controller.error!),
            ],
            const SizedBox(height: 12),
            _StatisticsGrid(statistics: statistics),
            const SizedBox(height: 12),
            _Section(
              title: 'Backtest BTCUSDT + FARTCOINUSDT',
              icon: Icons.science_rounded,
              child: controller.backtests.isEmpty
                  ? const Text(
                      'Исторический тест ещё не запускался. Нажмите «Запустить backtest».',
                    )
                  : Column(
                      children: controller.backtests
                          .map<Widget>(
                            (BacktestReport report) =>
                                _BacktestCard(report: report),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 12),
            _Section(
              title: 'Журнал сигналов',
              icon: Icons.menu_book_rounded,
              child: controller.signals.isEmpty
                  ? const Text(
                      'Сигналы появятся здесь автоматически, когда матрица даст '
                      'новый уникальный LONG или SHORT.',
                    )
                  : Column(
                      children: controller.signals
                          .map<Widget>(
                            (RadarSignal signal) => _SignalCard(signal: signal),
                          )
                          .toList(growable: false),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.running, required this.onRun});

  final bool running;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.auto_graph_rounded, color: Color(0xFF62E6A7)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Journal + Trade Tracker',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 3),
                Text(
                  'Сигналы и результаты сохраняются только на этом устройстве.',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: running ? null : onRun,
            icon: running
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(running ? 'Считаем…' : 'Запустить backtest'),
          ),
        ],
      ),
    );
  }
}

class _StatisticsGrid extends StatelessWidget {
  const _StatisticsGrid({required this.statistics});

  final JournalStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final List<_MetricData> metrics = <_MetricData>[
      _MetricData('Сигналы', statistics.signals.toString()),
      _MetricData('Сделки', statistics.trades.toString()),
      _MetricData('Активные', statistics.active.toString()),
      _MetricData('Win rate', '${statistics.winRate.toStringAsFixed(1)}%'),
      _MetricData('Average R', statistics.averageR.toStringAsFixed(2)),
      _MetricData('TP1', '${statistics.tp1Percent.toStringAsFixed(1)}%'),
      _MetricData('TP2', '${statistics.tp2Percent.toStringAsFixed(1)}%'),
      _MetricData('Stop', '${statistics.stopPercent.toStringAsFixed(1)}%'),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 800 ? 8 : 4;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 8 ? 1.25 : 1.45,
          children: metrics
              .map<Widget>((_MetricData metric) => _MetricTile(data: metric))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value);

  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54),
          ),
          Text(
            data.value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

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
              Icon(icon, size: 20, color: const Color(0xFF62E6A7)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _BacktestCard extends StatelessWidget {
  const _BacktestCard({required this.report});

  final BacktestReport report;

  @override
  Widget build(BuildContext context) {
    final List<_MetricData> metrics = <_MetricData>[
      _MetricData('Сигналы', report.signals.toString()),
      _MetricData('Сделки', report.trades.toString()),
      _MetricData('Win rate', '${report.winRate.toStringAsFixed(1)}%'),
      _MetricData('TP1', '${report.tp1Percent.toStringAsFixed(1)}%'),
      _MetricData('TP2', '${report.tp2Percent.toStringAsFixed(1)}%'),
      _MetricData('Stop', '${report.stopPercent.toStringAsFixed(1)}%'),
      _MetricData('Average R', report.averageR.toStringAsFixed(2)),
      _MetricData('Profit factor', report.profitFactor.toStringAsFixed(2)),
      _MetricData('Max DD', '${report.maxDrawdownR.toStringAsFixed(2)}R'),
      _MetricData(
        'Средний ход',
        '${report.averageMovePercent.toStringAsFixed(2)}%',
      ),
      _MetricData(
        'Время сделки',
        _duration(Duration(minutes: report.averageTradeMinutes.round())),
      ),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF0D1523),
      child: ExpansionTile(
        title: Text(
          report.symbol,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${_dateTime(report.startedAt)} — ${_dateTime(report.finishedAt)}',
        ),
        trailing: Text(
          '${report.winRate.toStringAsFixed(1)}% WR',
          style: const TextStyle(
            color: Color(0xFF62E6A7),
            fontWeight: FontWeight.w800,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: metrics
                .map<Widget>(
                  (_MetricData metric) => SizedBox(
                    width: 130,
                    height: 76,
                    child: _MetricTile(data: metric),
                  ),
                )
                .toList(growable: false),
          ),
          if (report.strategies.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Результат отдельно по режимам',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 8),
            for (final StrategyPerformance strategy in report.strategies)
              _StrategyRow(strategy: strategy),
          ],
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Эффективность подтверждающих факторов',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          for (final FactorPerformance factor in report.factors)
            _FactorRow(factor: factor),
        ],
      ),
    );
  }
}

class _StrategyRow extends StatelessWidget {
  const _StrategyRow({required this.strategy});

  final StrategyPerformance strategy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              strategy.style.label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text('${strategy.trades}/${strategy.signals} сделок'),
          const SizedBox(width: 18),
          Text('${strategy.winRate.toStringAsFixed(1)}% WR'),
          const SizedBox(width: 18),
          Text('${strategy.averageR.toStringAsFixed(2)}R'),
          const SizedBox(width: 18),
          Text('PF ${strategy.profitFactor.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}

class _FactorRow extends StatelessWidget {
  const _FactorRow({required this.factor});

  final FactorPerformance factor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(factor.name)),
          SizedBox(width: 70, child: Text('${factor.trades} сдел.')),
          SizedBox(
            width: 75,
            child: Text('${factor.winRate.toStringAsFixed(1)}% WR'),
          ),
          SizedBox(
            width: 58,
            child: Text(
              '${factor.averageR >= 0.0 ? '+' : ''}'
              '${factor.averageR.toStringAsFixed(2)}R',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  const _SignalCard({required this.signal});

  final RadarSignal signal;

  @override
  Widget build(BuildContext context) {
    final Color directionColor = signal.direction == SignalDirection.long
        ? const Color(0xFF38D996)
        : const Color(0xFFFF667A);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: const Color(0xFF0D1523),
      child: ExpansionTile(
        leading: Icon(
          signal.direction == SignalDirection.long
              ? Icons.north_east_rounded
              : Icons.south_east_rounded,
          color: directionColor,
        ),
        title: Text(
          '${signal.symbol} • ${signal.style.label} • '
          '${signal.direction.label}',
          style: TextStyle(color: directionColor, fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${_dateTime(signal.time)} • score ${signal.score}'),
        trailing: _StatusBadge(status: signal.status),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: <Widget>[
          _SignalRow(
            'Вход',
            '${_price(signal.entryLow)} — ${_price(signal.entryHigh)}',
          ),
          _SignalRow(
            'Стоп / TP1 / TP2',
            '${_price(signal.stop)} / ${_price(signal.tp1)} / ${_price(signal.tp2)}',
          ),
          _SignalRow(
            'Тренды 1м / 5м / 15м / 1ч',
            '${signal.trend1m.label} / ${signal.trend5m.label} / '
                '${signal.trend15m.label} / ${signal.trend1h.label}',
          ),
          _SignalRow(
            'RSI / MACD / RVOL',
            '${signal.rsi.toStringAsFixed(1)} / '
                '${signal.macd.toStringAsFixed(6)} / '
                '${signal.relativeVolume.toStringAsFixed(2)}×',
          ),
          _SignalRow(
            'FVG / OB / Liquidity',
            '${signal.fvgBias.label} / ${signal.orderBlockBias.label} / '
                '${signal.liquidityBias.label}',
          ),
          _SignalRow(
            'BOS / CHOCH',
            '${signal.bos.label} / ${signal.choch.label}',
          ),
          _SignalRow(
            'MFE / MAE',
            '${signal.mfeR.toStringAsFixed(2)}R / '
                '${signal.maeR.toStringAsFixed(2)}R',
          ),
          _SignalRow(
            'Время до входа / TP1 / TP2',
            '${_nullableDuration(signal.timeToEntry)} / '
                '${_nullableDuration(signal.timeToTp1)} / '
                '${_nullableDuration(signal.timeToTp2)}',
          ),
          _SignalRow(
            'Результат',
            '${signal.resultR >= 0.0 ? '+' : ''}'
                '${signal.resultR.toStringAsFixed(2)}R',
          ),
          const Divider(height: 18),
          RiskRewardTable(signal: signal),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SignalStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status) {
      case SignalStatus.waitingEntry:
        color = Colors.amberAccent;
      case SignalStatus.inPosition:
        color = Colors.lightBlueAccent;
      case SignalStatus.tp1Hit:
        color = const Color(0xFF62E6A7);
      case SignalStatus.tp2Hit:
        color = const Color(0xFF38D996);
      case SignalStatus.stopped:
        color = const Color(0xFFFF667A);
      case SignalStatus.cancelled:
        color = Colors.white54;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.code,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B1518),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(message),
    );
  }
}

String _price(double value) {
  if (value.abs() >= 1000.0) {
    return value.toStringAsFixed(2);
  }
  if (value.abs() >= 1.0) {
    return value.toStringAsFixed(4);
  }
  return value.toStringAsFixed(6);
}

String _dateTime(DateTime time) {
  final String day = time.day.toString().padLeft(2, '0');
  final String month = time.month.toString().padLeft(2, '0');
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$day.$month $hour:$minute';
}

String _nullableDuration(Duration? duration) {
  return duration == null ? '—' : _duration(duration);
}

String _duration(Duration duration) {
  if (duration.inHours >= 1) {
    return '${duration.inHours}ч ${duration.inMinutes.remainder(60)}м';
  }
  return '${duration.inMinutes}м';
}
