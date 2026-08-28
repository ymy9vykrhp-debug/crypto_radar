import 'dart:convert';

import '../models/backtest_models.dart';
import '../models/signal_models.dart';
import '../models/trading_journal_models.dart';
import 'storage/local_storage_backend.dart';

class JournalStore {
  JournalStore({LocalStorageBackend? backend})
    : _backend = backend ?? createLocalStorageBackend();

  static const String _signalsKey = 'crypto_radar_signals_v1';
  static const String _backtestsKey = 'crypto_radar_backtests_v1';
  static const String _tradesKey = 'crypto_radar_personal_trades_v1';
  static const String _notesKey = 'crypto_radar_trading_notes_v1';
  static const String _reviewNotesKey = 'crypto_radar_review_notes_v1';
  static const String _settingsKey = 'crypto_radar_journal_settings_v1';

  final LocalStorageBackend _backend;

  Future<List<RadarSignal>> loadSignals() async {
    final String? raw = await _backend.read(_signalsKey);
    if (raw == null || raw.isEmpty) {
      return <RadarSignal>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <RadarSignal>[];
      }
      final List<RadarSignal> result = decoded
          .whereType<Map<String, dynamic>>()
          .map<RadarSignal>(RadarSignal.fromJson)
          .toList();
      result.sort(
        (RadarSignal first, RadarSignal second) =>
            second.time.compareTo(first.time),
      );
      return result;
    } on Object {
      return <RadarSignal>[];
    }
  }

  Future<void> saveSignals(List<RadarSignal> signals) async {
    final String encoded = jsonEncode(
      signals
          .map<Map<String, Object?>>((RadarSignal signal) => signal.toJson())
          .toList(growable: false),
    );
    await _backend.write(_signalsKey, encoded);
  }

  Future<List<BacktestReport>> loadBacktests() async {
    final String? raw = await _backend.read(_backtestsKey);
    if (raw == null || raw.isEmpty) {
      return <BacktestReport>[];
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) {
        return <BacktestReport>[];
      }
      return decoded
          .whereType<Map<String, dynamic>>()
          .map<BacktestReport>(BacktestReport.fromJson)
          .toList(growable: false);
    } on Object {
      return <BacktestReport>[];
    }
  }

  Future<void> saveBacktests(List<BacktestReport> reports) async {
    final String encoded = jsonEncode(
      reports
          .map<Map<String, Object?>>((BacktestReport report) => report.toJson())
          .toList(growable: false),
    );
    await _backend.write(_backtestsKey, encoded);
  }

  Future<List<TradeJournalEntry>> loadTrades() async {
    final String? raw = await _backend.read(_tradesKey);
    if (raw == null || raw.isEmpty) return <TradeJournalEntry>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <TradeJournalEntry>[];
      final List<TradeJournalEntry> result = decoded
          .whereType<Map<String, dynamic>>()
          .map<TradeJournalEntry>(TradeJournalEntry.fromJson)
          .where((TradeJournalEntry trade) => trade.id.isNotEmpty)
          .toList(growable: false);
      return result..sort(
        (TradeJournalEntry first, TradeJournalEntry second) =>
            second.tradeTime.compareTo(first.tradeTime),
      );
    } on Object {
      return <TradeJournalEntry>[];
    }
  }

  Future<void> saveTrades(List<TradeJournalEntry> trades) async {
    await _backend.write(
      _tradesKey,
      jsonEncode(
        trades
            .map<Map<String, Object?>>(
              (TradeJournalEntry trade) => trade.toJson(),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<List<TradingNote>> loadNotes() async {
    final String? raw = await _backend.read(_notesKey);
    if (raw == null || raw.isEmpty) return <TradingNote>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <TradingNote>[];
      final List<TradingNote> result = decoded
          .whereType<Map<String, dynamic>>()
          .map<TradingNote>(TradingNote.fromJson)
          .where((TradingNote note) => note.id.isNotEmpty)
          .toList(growable: false);
      return result..sort(
        (TradingNote first, TradingNote second) =>
            second.date.compareTo(first.date),
      );
    } on Object {
      return <TradingNote>[];
    }
  }

  Future<void> saveNotes(List<TradingNote> notes) async {
    await _backend.write(
      _notesKey,
      jsonEncode(
        notes
            .map<Map<String, Object?>>((TradingNote note) => note.toJson())
            .toList(growable: false),
      ),
    );
  }

  Future<List<JournalReviewNote>> loadReviewNotes() async {
    final String? raw = await _backend.read(_reviewNotesKey);
    if (raw == null || raw.isEmpty) return <JournalReviewNote>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return <JournalReviewNote>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map<JournalReviewNote>(JournalReviewNote.fromJson)
          .toList(growable: false);
    } on Object {
      return <JournalReviewNote>[];
    }
  }

  Future<void> saveReviewNotes(List<JournalReviewNote> notes) async {
    await _backend.write(
      _reviewNotesKey,
      jsonEncode(
        notes
            .map<Map<String, Object?>>(
              (JournalReviewNote note) => note.toJson(),
            )
            .toList(growable: false),
      ),
    );
  }

  Future<JournalSettings> loadSettings() async {
    final String? raw = await _backend.read(_settingsKey);
    if (raw == null || raw.isEmpty) return const JournalSettings();
    try {
      final Object? decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? JournalSettings.fromJson(decoded)
          : const JournalSettings();
    } on Object {
      return const JournalSettings();
    }
  }

  Future<void> saveSettings(JournalSettings settings) async {
    await _backend.write(_settingsKey, jsonEncode(settings.toJson()));
  }
}
