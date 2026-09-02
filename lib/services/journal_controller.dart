import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../engines/backtest_engine.dart';
import '../engines/decision_engine.dart';
import '../engines/first_move_probability_engine.dart';
import '../engines/phase_a_engine.dart';
import '../engines/signal_engine.dart';
import '../engines/strategy_learning_engine.dart';
import '../engines/trade_tracker.dart';
import '../engines/trade_outcome_classifier.dart';
import '../models/backtest_models.dart';
import '../models/execution_models.dart';
import '../models/first_move_models.dart';
import '../models/market_models.dart';
import '../models/learning_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import '../models/trading_journal_models.dart';
import 'journal_store.dart';

class JournalController extends ChangeNotifier {
  JournalController({
    required this.store,
    required this.backtestEngine,
    this.tradeTracker = const TradeTracker(),
    FeeModel Function()? feeModelProvider,
  }) : feeModelProvider = feeModelProvider ?? _defaultFeeModel;

  final JournalStore store;
  final BacktestEngine backtestEngine;
  final TradeTracker tradeTracker;
  final FeeModel Function() feeModelProvider;

  static FeeModel _defaultFeeModel() => const FeeModel();

  List<RadarSignal> _signals = <RadarSignal>[];
  List<BacktestReport> _backtests = <BacktestReport>[];
  List<TradeJournalEntry> _trades = <TradeJournalEntry>[];
  List<TradingNote> _notes = <TradingNote>[];
  List<JournalReviewNote> _reviewNotes = <JournalReviewNote>[];
  JournalSettings _journalSettings = const JournalSettings();
  bool _initialized = false;
  bool _backtestRunning = false;
  bool _disposed = false;
  String? _error;

  List<RadarSignal> get signals => List<RadarSignal>.unmodifiable(_signals);
  List<BacktestReport> get backtests =>
      List<BacktestReport>.unmodifiable(_backtests);
  List<TradeJournalEntry> get trades =>
      List<TradeJournalEntry>.unmodifiable(_trades);
  List<TradingNote> get notes => List<TradingNote>.unmodifiable(_notes);
  List<JournalReviewNote> get reviewNotes =>
      List<JournalReviewNote>.unmodifiable(_reviewNotes);
  JournalSettings get journalSettings => _journalSettings;
  bool get initialized => _initialized;
  bool get backtestRunning => _backtestRunning;
  String? get error => _error;
  JournalStatistics get statistics => JournalStatistics.fromSignals(_signals);
  List<LearningAssessment> get learningAssessments => _backtests
      .map<LearningAssessment>(StrategyLearningEngine.evaluate)
      .toList(growable: false);

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _signals = await store.loadSignals();
    bool migratedReasonCodes = false;
    for (int index = 0; index < _signals.length; index++) {
      if (_signals[index].reasonCodes.isEmpty) {
        _signals[index] = _signals[index].copyWith(
          reasonCodes: DecisionEngine.persistedReasonCodesForSignal(
            _signals[index],
          ),
        );
        migratedReasonCodes = true;
      }
    }
    _backtests = await store.loadBacktests();
    bool migratedProbabilityGate = false;
    for (int index = 0; index < _signals.length; index++) {
      if (_signals[index].status != SignalStatus.waitingEntry) continue;
      final RadarSignal gated = _attachAndGateProbability(_signals[index]);
      if (jsonEncode(gated.toJson()) != jsonEncode(_signals[index].toJson())) {
        _signals[index] = gated;
        migratedProbabilityGate = true;
      }
    }
    if (migratedReasonCodes || migratedProbabilityGate) {
      await store.saveSignals(_signals);
    }
    _trades = await store.loadTrades();
    _notes = await store.loadNotes();
    _reviewNotes = await store.loadReviewNotes();
    _journalSettings = await store.loadSettings();
    _initialized = true;
    _notify();
  }

  Future<void> addManualTrade(TradeJournalEntry trade) async {
    await initialize();
    if (trade.source != TradeSource.manual) {
      throw ArgumentError('Manual trade must use MANUAL source');
    }
    if (_trades.any((TradeJournalEntry item) => item.id == trade.id)) {
      throw StateError('Trade ID already exists');
    }
    _trades.insert(0, trade.withCalculatedStatus());
    _sortTrades();
    await store.saveTrades(_trades);
    _notify();
  }

  Future<void> updateManualTrade(TradeJournalEntry trade) async {
    await initialize();
    final int index = _trades.indexWhere(
      (TradeJournalEntry item) => item.id == trade.id,
    );
    if (index < 0) throw StateError('Trade not found');
    if (_trades[index].source != TradeSource.manual ||
        trade.source != TradeSource.manual) {
      throw StateError('System execution facts cannot be edited');
    }
    _trades[index] = trade
        .copyWith(
          id: _trades[index].id,
          source: TradeSource.manual,
          createdAt: _trades[index].createdAt,
        )
        .withCalculatedStatus();
    _sortTrades();
    await store.saveTrades(_trades);
    _notify();
  }

  Future<void> deleteManualTrade(String id) async {
    await initialize();
    final int index = _trades.indexWhere(
      (TradeJournalEntry item) => item.id == id,
    );
    if (index < 0) return;
    if (_trades[index].source != TradeSource.manual) {
      throw StateError('System execution facts cannot be deleted');
    }
    _trades.removeAt(index);
    await store.saveTrades(_trades);
    _notify();
  }

  /// Future Paper and Bybit Demo brokers use this single import boundary.
  /// Execution facts are replaced by the broker update, while personal review
  /// fields stay under user control.
  Future<void> upsertExecutionTrade(TradeJournalEntry trade) async {
    await initialize();
    if (trade.source == TradeSource.manual ||
        trade.source == TradeSource.live) {
      throw ArgumentError('Only PAPER or BYBIT_DEMO auto-import is allowed');
    }
    final int index = _trades.indexWhere(
      (TradeJournalEntry item) => item.id == trade.id,
    );
    if (index < 0) {
      _trades.add(trade.withCalculatedStatus());
    } else {
      final TradeJournalEntry existing = _trades[index];
      _trades[index] = trade
          .copyWith(
            myNotes: existing.myNotes,
            tags: existing.tags,
            whatWasGood: existing.whatWasGood,
            whatWasWrong: existing.whatWasWrong,
            whatShouldChange: existing.whatShouldChange,
            useForStrategyResearch: existing.useForStrategyResearch,
          )
          .withCalculatedStatus();
    }
    _sortTrades();
    await store.saveTrades(_trades);
    _notify();
  }

  Future<void> updateTradeReview({
    required String id,
    required String myNotes,
    required Set<TradeTag> tags,
    required String whatWasGood,
    required String whatWasWrong,
    required String whatShouldChange,
    required bool useForStrategyResearch,
  }) async {
    await initialize();
    final int index = _trades.indexWhere(
      (TradeJournalEntry item) => item.id == id,
    );
    if (index < 0) throw StateError('Trade not found');
    _trades[index] = _trades[index].copyWith(
      myNotes: myNotes.trim(),
      tags: tags,
      whatWasGood: whatWasGood.trim(),
      whatWasWrong: whatWasWrong.trim(),
      whatShouldChange: whatShouldChange.trim(),
      useForStrategyResearch: useForStrategyResearch,
    );
    await store.saveTrades(_trades);
    _notify();
  }

  Future<void> saveTradingNote(TradingNote note) async {
    await initialize();
    final int index = _notes.indexWhere(
      (TradingNote item) => item.id == note.id,
    );
    if (index < 0) {
      _notes.add(note);
    } else {
      _notes[index] = note;
    }
    _notes.sort(
      (TradingNote first, TradingNote second) =>
          second.date.compareTo(first.date),
    );
    await store.saveNotes(_notes);
    _notify();
  }

  Future<void> deleteTradingNote(String id) async {
    await initialize();
    _notes.removeWhere((TradingNote note) => note.id == id);
    await store.saveNotes(_notes);
    _notify();
  }

  Future<void> saveReviewNote(JournalReviewNote note) async {
    await initialize();
    final int index = _reviewNotes.indexWhere(
      (JournalReviewNote item) => item.id == note.id,
    );
    if (index < 0) {
      _reviewNotes.add(note);
    } else if (note.text.trim().isEmpty) {
      _reviewNotes.removeAt(index);
    } else {
      _reviewNotes[index] = note;
    }
    await store.saveReviewNotes(_reviewNotes);
    _notify();
  }

  String reviewText(JournalReviewPeriod period, DateTime start) {
    final String id = '${period.name}:${dateKey(start)}';
    for (final JournalReviewNote note in _reviewNotes) {
      if (note.id == id) return note.text;
    }
    return '';
  }

  Future<void> updateJournalSettings(JournalSettings settings) async {
    await initialize();
    _journalSettings = JournalSettings(
      startingBalance:
          settings.startingBalance.isFinite && settings.startingBalance >= 0
          ? settings.startingBalance
          : 0.0,
      dailyMaxLoss: settings.dailyMaxLoss,
      weeklyMaxLoss: settings.weeklyMaxLoss,
      dailyTarget: settings.dailyTarget,
    );
    await store.saveSettings(_journalSettings);
    _notify();
  }

  Future<void> processLiveSnapshot(
    MarketSnapshot snapshot, {
    MarketSnapshot? benchmarkMarket,
  }) async {
    await initialize();
    bool changed = false;
    for (int index = 0; index < _signals.length; index++) {
      final RadarSignal signal = _signals[index];
      if (signal.symbol != snapshot.symbol ||
          (!signal.status.isActive && !signal.needsPostStopTracking)) {
        continue;
      }
      RadarSignal tracked = tradeTracker.consumeAll(
        signal,
        signal.style == SignalStyle.scalp
            ? snapshot.oneMinute.candles
            : snapshot.fiveMinutes.candles,
      );
      tracked = tracked.copyWith(
        firstMove: tracked.firstMove.copyWith(
          btcState: _benchmarkState(snapshot, benchmarkMarket),
        ),
      );
      if (tracked.status == SignalStatus.waitingEntry) {
        tracked = PhaseAEngine.update(
          market: snapshot,
          signal: tracked,
          feeModel: feeModelProvider(),
        );
        tracked = _attachAndGateProbability(tracked, asOf: snapshot.updatedAt);
      }
      if (!tracked.status.isActive) {
        tracked = TradeOutcomeClassifier.classify(tracked);
      }
      if (jsonEncode(tracked.toJson()) != jsonEncode(signal.toJson())) {
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
      final RadarSignal enrichedCandidate = candidate.copyWith(
        reasonCodes: DecisionEngine.persistedReasonCodesForSignal(candidate),
        firstMove: candidate.firstMove.copyWith(
          btcState: _benchmarkState(snapshot, benchmarkMarket),
        ),
      );
      final ExecutionProfile? learnedProfile = _approvedProfile(
        snapshot.symbol,
      );
      RadarSignal preparedCandidate = PhaseAEngine.prepare(
        market: snapshot,
        signal: enrichedCandidate,
        entryVariant:
            learnedProfile?.entryVariant ?? EntryVariant.bosConfirmation,
        stopVariant: learnedProfile?.stopVariant ?? StopVariant.structuralAtr,
        profileId: learnedProfile == null
            ? 'live_confirmed'
            : 'learned_${learnedProfile.id}',
        feeModel: feeModelProvider(),
      );
      preparedCandidate = _attachAndGateProbability(
        preparedCandidate,
        asOf: snapshot.updatedAt,
      );
      final bool hasActiveStyle = _signals.any(
        (RadarSignal signal) =>
            signal.symbol == snapshot.symbol &&
            signal.style == preparedCandidate.style &&
            signal.status.isActive,
      );
      final bool alreadySaved = _signals.any(
        (RadarSignal signal) => signal.id == preparedCandidate.id,
      );
      if (!hasActiveStyle && !alreadySaved) {
        _signals.insert(0, preparedCandidate);
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

  ExecutionProfile? _approvedProfile(String symbol) {
    for (final BacktestReport report in _backtests.reversed) {
      if (report.symbol == symbol) {
        return StrategyLearningEngine.approvedProfile(report);
      }
    }
    return null;
  }

  RadarSignal _attachAndGateProbability(RadarSignal signal, {DateTime? asOf}) {
    final Iterable<FirstMoveHistoricalBucket> buckets = _backtests.expand(
      (BacktestReport report) => report.firstMoveBuckets,
    );
    final RadarSignal profiled =
        FirstMoveProbabilityEngine.attachHistoricalProfile(
          signal: signal,
          historicalSignals: _signals,
          historicalBuckets: buckets,
          asOf: asOf ?? signal.time,
          feeModel: feeModelProvider(),
        );
    return FirstMoveProbabilityEngine.enforceEntryPermission(profiled);
  }

  String _benchmarkState(MarketSnapshot market, MarketSnapshot? benchmark) {
    if (market.symbol == 'BTCUSDT') return 'BENCHMARK';
    if (benchmark == null) return 'UNAVAILABLE';
    if (benchmark.dataIntegrity.hasCriticalIssue) return 'STALE';
    final Bias fifteen = benchmark.fifteenMinutes.trend;
    final Bias hour = benchmark.oneHour.trend;
    if (fifteen == Bias.bullish && hour == Bias.bullish) return 'TREND_UP';
    if (fifteen == Bias.bearish && hour == Bias.bearish) return 'TREND_DOWN';
    return 'MIXED';
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  void _sortTrades() {
    _trades.sort(
      (TradeJournalEntry first, TradeJournalEntry second) =>
          second.tradeTime.compareTo(first.tradeTime),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
