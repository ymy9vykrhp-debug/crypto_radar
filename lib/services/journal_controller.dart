import 'package:flutter/foundation.dart';

import '../engines/backtest_engine.dart';
import '../engines/signal_engine.dart';
import '../engines/trade_tracker.dart';
import '../models/backtest_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import 'journal_store.dart';

class JournalController extends ChangeNotifier {
  JournalController({
    required this.store,
    required this.backtestEngine,
    this.tradeTracker = const TradeTracker(),
  });

  final JournalStore store;
  final BacktestEngine backtestEngine;
  final TradeTracker tradeTracker;

  List<RadarSignal> _signals = <RadarSignal>[];
  List<BacktestReport> _backtests = <BacktestReport>[];
  bool _initialized = false;
  bool _backtestRunning = false;
  bool _disposed = false;
  String? _error;

  List<RadarSignal> get signals => List<RadarSignal>.unmodifiable(_signals);
  List<BacktestReport> get backtests =>
      List<BacktestReport>.unmodifiable(_backtests);
  bool get initialized => _initialized;
  bool get backtestRunning => _backtestRunning;
  String? get error => _error;
  JournalStatistics get statistics => JournalStatistics.fromSignals(_signals);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _signals = await store.loadSignals();
    _backtests = await store.loadBacktests();
    _initialized = true;
    _notify();
  }

  Future<void> processLiveSnapshot(MarketSnapshot snapshot) async {
    await initialize();
    bool changed = false;
    for (int index = 0; index < _signals.length; index++) {
      final RadarSignal signal = _signals[index];
      if (signal.symbol != snapshot.symbol || !signal.status.isActive) {
        continue;
      }
      final RadarSignal tracked = tradeTracker.consumeAll(
        signal,
        signal.style == SignalStyle.scalp
            ? snapshot.oneMinute.candles
            : snapshot.fiveMinutes.candles,
      );
      if (!identical(tracked, signal)) {
        _signals[index] = tracked;
        changed = true;
      }
    }

    final List<RadarSignal?> candidates = <RadarSignal?>[
      SignalEngine.createSignal(snapshot),
      SignalEngine.createScalpSignal(snapshot),
    ];
    for (final RadarSignal? candidate in candidates) {
      if (candidate == null) {
        continue;
      }
      final bool hasActiveStyle = _signals.any(
        (RadarSignal signal) =>
            signal.symbol == snapshot.symbol &&
            signal.style == candidate.style &&
            signal.status.isActive,
      );
      final bool alreadySaved = _signals.any(
        (RadarSignal signal) => signal.id == candidate.id,
      );
      if (!hasActiveStyle && !alreadySaved) {
        _signals.insert(0, candidate);
        changed = true;
      }
    }

    if (changed) {
      _signals.sort(
        (RadarSignal first, RadarSignal second) =>
            second.time.compareTo(first.time),
      );
      await store.saveSignals(_signals);
      _notify();
    }
  }

  Future<void> runInitialBacktests() async {
    if (_backtestRunning) {
      return;
    }
    _backtestRunning = true;
    _error = null;
    _notify();
    try {
      final List<BacktestReport> reports = <BacktestReport>[];
      for (final String symbol in <String>['BTCUSDT', 'FARTCOINUSDT']) {
        reports.add(await backtestEngine.run(symbol));
      }
      _backtests = reports;
      await store.saveBacktests(_backtests);
    } on Object catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      _backtestRunning = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
