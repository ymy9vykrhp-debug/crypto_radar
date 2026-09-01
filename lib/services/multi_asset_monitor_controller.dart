import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/market_models.dart';

typedef MarketSnapshotLoader = Future<MarketSnapshot> Function(String symbol);
typedef MarketSnapshotProcessor = Future<void> Function(
  MarketSnapshot snapshot,
);
typedef MonitorClock = DateTime Function();

enum AssetMonitorState { idle, checking, ready, error }

class AssetMonitorStatus {
  const AssetMonitorStatus({
    required this.symbol,
    this.state = AssetMonitorState.idle,
    this.lastCheckedAt,
    this.lastSuccessAt,
    this.error,
  });

  final String symbol;
  final AssetMonitorState state;
  final DateTime? lastCheckedAt;
  final DateTime? lastSuccessAt;
  final String? error;

  AssetMonitorStatus copyWith({
    AssetMonitorState? state,
    DateTime? lastCheckedAt,
    DateTime? lastSuccessAt,
    String? error,
    bool clearError = false,
  }) {
    return AssetMonitorStatus(
      symbol: symbol,
      state: state ?? this.state,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      error: clearError ? null : error ?? this.error,
    );
  }
}

/// Runs one shared market/decision pipeline for several symbols in sequence.
///
/// Sequential loading avoids request bursts and guarantees that journal writes
/// and alert-ledger updates cannot race each other. A failure is isolated to the
/// affected symbol and never stops the rest of the watchlist.
class MultiAssetMonitorController extends ChangeNotifier {
  MultiAssetMonitorController({
    required this.snapshotLoader,
    required this.snapshotProcessor,
    MonitorClock? clock,
    this.maxSymbols = 5,
  }) : _clock = clock ?? DateTime.now;

  final MarketSnapshotLoader snapshotLoader;
  final MarketSnapshotProcessor snapshotProcessor;
  final MonitorClock _clock;
  final int maxSymbols;
  final Map<String, AssetMonitorStatus> _statuses =
      <String, AssetMonitorStatus>{};

  bool _running = false;
  int _completedCycles = 0;

  bool get running => _running;
  int get completedCycles => _completedCycles;
  Map<String, AssetMonitorStatus> get statuses =>
      UnmodifiableMapView<String, AssetMonitorStatus>(_statuses);

  AssetMonitorStatus statusFor(String symbol) {
    final String normalized = _normalize(symbol);
    return _statuses[normalized] ?? AssetMonitorStatus(symbol: normalized);
  }

  Future<Map<String, MarketSnapshot>> refresh(Iterable<String> symbols) async {
    if (_running) return const <String, MarketSnapshot>{};
    final List<String> queue = symbols
        .map(_normalize)
        .where((String value) => value.isNotEmpty)
        .toSet()
        .take(maxSymbols)
        .toList(growable: false);
    if (queue.isEmpty) return const <String, MarketSnapshot>{};

    _running = true;
    notifyListeners();
    final Map<String, MarketSnapshot> results = <String, MarketSnapshot>{};
    try {
      for (final String symbol in queue) {
        final AssetMonitorStatus previous = statusFor(symbol);
        _statuses[symbol] = previous.copyWith(
          state: AssetMonitorState.checking,
          clearError: true,
        );
        notifyListeners();
        try {
          final MarketSnapshot snapshot = await snapshotLoader(symbol);
          if (_normalize(snapshot.symbol) != symbol) {
            throw StateError(
              'Expected $symbol but received ${snapshot.symbol}.',
            );
          }
          await snapshotProcessor(snapshot);
          final DateTime completedAt = _clock();
          results[symbol] = snapshot;
          _statuses[symbol] = statusFor(symbol).copyWith(
            state: AssetMonitorState.ready,
            lastCheckedAt: completedAt,
            lastSuccessAt: completedAt,
            clearError: true,
          );
        } on Object catch (error) {
          _statuses[symbol] = statusFor(symbol).copyWith(
            state: AssetMonitorState.error,
            lastCheckedAt: _clock(),
            error: error.toString().replaceFirst('Exception: ', ''),
          );
        }
        notifyListeners();
      }
      _completedCycles += 1;
      return Map<String, MarketSnapshot>.unmodifiable(results);
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  static String _normalize(String value) =>
      value.trim().toUpperCase().replaceAll('/', '').replaceAll(' ', '');
}
