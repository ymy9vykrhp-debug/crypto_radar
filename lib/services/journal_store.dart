import 'dart:convert';

import '../models/backtest_models.dart';
import '../models/signal_models.dart';
import 'storage/local_storage_backend.dart';

class JournalStore {
  JournalStore({LocalStorageBackend? backend})
    : _backend = backend ?? createLocalStorageBackend();

  static const String _signalsKey = 'crypto_radar_signals_v1';
  static const String _backtestsKey = 'crypto_radar_backtests_v1';

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
}
