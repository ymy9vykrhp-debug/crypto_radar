import '../models/backtest_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../services/bybit_service.dart';
import 'decision_engine.dart';
import 'signal_engine.dart';
import 'trade_tracker.dart';

class BacktestEngine {
  const BacktestEngine({
    required this.bybitService,
    this.tradeTracker = const TradeTracker(),
  });

  final BybitService bybitService;
  final TradeTracker tradeTracker;

  Future<BacktestReport> run(String symbol) async {
    final Future<List<Candle>> oneFuture = bybitService.loadHistoricalCandles(
      symbol,
      '1',
      count: 5000,
    );
    final Future<List<Candle>> fiveFuture = bybitService.loadCandles(
      symbol,
      '5',
      limit: 1000,
    );
    final Future<List<Candle>> fifteenFuture = bybitService.loadCandles(
      symbol,
      '15',
      limit: 1000,
    );
    final Future<List<Candle>> hourFuture = bybitService.loadCandles(
      symbol,
      '60',
      limit: 1000,
    );
    final List<Candle> one = await oneFuture;
    final List<Candle> five = await fiveFuture;
    final List<Candle> fifteen = await fifteenFuture;
    final List<Candle> hour = await hourFuture;
    if (one.length < 1000 ||
        five.length < 240 ||
        fifteen.length < 240 ||
        hour.length < 240) {
      throw Exception('Недостаточно истории $symbol для backtest');
    }

    final List<RadarSignal> signals = <RadarSignal>[];
    final Map<String, DateTime> previousSetups = <String, DateTime>{};
    final int firstIndex = one.length > 4000 ? one.length - 4000 : 200;

    for (int index = firstIndex; index < one.length; index++) {
      final Candle currentCandle = one[index];

      // Signals are tracked using only the candle that has just closed.
      for (int signalIndex = 0; signalIndex < signals.length; signalIndex++) {
        if (signals[signalIndex].status.isActive) {
          signals[signalIndex] = tradeTracker.consume(
            signals[signalIndex],
            currentCandle,
          );
        }
      }

      final DateTime baseClose = currentCandle.time.add(
        const Duration(minutes: 1),
      );
      final List<Candle> oneWindow = _takeLast(one.sublist(0, index + 1), 240);
      final List<Candle> fiveWindow = _closedWindow(
        five,
        baseClose,
        const Duration(minutes: 5),
      );
      final List<Candle> fifteenWindow = _closedWindow(
        fifteen,
        baseClose,
        const Duration(minutes: 15),
      );
      final List<Candle> hourWindow = _closedWindow(
        hour,
        baseClose,
        const Duration(hours: 1),
      );
      if (oneWindow.length < 200 ||
          fiveWindow.length < 200 ||
          fifteenWindow.length < 200 ||
          hourWindow.length < 200) {
        continue;
      }

      final double price = currentCandle.close;
      final double firstPrice = fiveWindow.first.close;
      final double change = firstPrice == 0.0
          ? 0.0
          : (price - firstPrice) / firstPrice * 100.0;
      final double turnover = fiveWindow.fold<double>(
        0.0,
        (double sum, Candle candle) => sum + candle.volume * candle.close,
      );
      final MarketSnapshot snapshot = SignalEngine.buildSnapshot(
        symbol: symbol,
        ticker: TickerStats(
          price: price,
          change24hPercent: change,
          turnover24h: turnover,
        ),
        oneCandles: oneWindow,
        fiveCandles: fiveWindow,
        fifteenCandles: fifteenWindow,
        hourCandles: hourWindow,
      );
      final bool standardBoundary = baseClose.minute % 15 == 0;
      final bool standardActive = signals.any(
        (RadarSignal signal) =>
            signal.style == SignalStyle.standard && signal.status.isActive,
      );
      final bool scalpActive = signals.any(
        (RadarSignal signal) =>
            signal.style == SignalStyle.scalp && signal.status.isActive,
      );
      final List<RadarSignal?> candidates = <RadarSignal?>[
        if (standardBoundary && !standardActive)
          SignalEngine.createSignal(snapshot, signalTime: baseClose),
        if (!scalpActive)
          SignalEngine.createScalpSignal(snapshot, signalTime: baseClose),
      ];
      for (final RadarSignal? candidate in candidates) {
        if (candidate == null) {
          continue;
        }
        final String setupKey =
            '${candidate.style.name}:'
            '${candidate.direction.name}';
        final DateTime? previousSetupTime = previousSetups[setupKey];
        final Duration cooldown = candidate.style == SignalStyle.scalp
            ? const Duration(minutes: 10)
            : const Duration(hours: 1);
        final bool repeatedSetup =
            previousSetupTime != null &&
            baseClose.difference(previousSetupTime) < cooldown;
        if (!repeatedSetup) {
          signals.add(
            candidate.copyWith(
              reasonCodes: DecisionEngine.persistedReasonCodesForSignal(
                candidate,
              ),
            ),
          );
          previousSetups[setupKey] = baseClose;
        }
      }
    }

    final Candle finalCandle = one.last;
    for (int index = 0; index < signals.length; index++) {
      if (signals[index].status.isActive) {
        signals[index] = tradeTracker.closeAtEnd(signals[index], finalCandle);
      }
    }

    final DateTime startedAt = one[firstIndex].time;
    final DateTime finishedAt = finalCandle.time.add(
      const Duration(minutes: 1),
    );
    return BacktestReport.fromSignals(
      symbol: symbol,
      startedAt: startedAt,
      finishedAt: finishedAt,
      source: signals,
    );
  }

  List<Candle> _closedWindow(
    List<Candle> candles,
    DateTime evaluationTime,
    Duration timeframe,
  ) {
    final List<Candle> closed = <Candle>[];
    for (final Candle candle in candles) {
      if (!candle.time.add(timeframe).isAfter(evaluationTime)) {
        closed.add(candle);
      }
    }
    return _takeLast(closed, 240);
  }

  List<Candle> _takeLast(List<Candle> candles, int count) {
    if (candles.length <= count) {
      return List<Candle>.of(candles, growable: false);
    }
    return candles.sublist(candles.length - count, candles.length);
  }
}
