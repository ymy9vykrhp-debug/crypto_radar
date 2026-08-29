import 'package:flutter/foundation.dart';

import '../engines/entry_readiness_gate.dart';
import '../models/execution_models.dart';
import '../models/signal_models.dart';
import '../models/trade_alert_models.dart';

typedef AlertClock = DateTime Function();

/// Detects strong, newly confirmed entries without changing signal logic.
class TradeAlertController extends ChangeNotifier {
  TradeAlertController({
    AlertClock? clock,
    this.cooldown = const Duration(minutes: 30),
    this.minimumScore = 80,
    this.significantScoreIncrease = 10,
  }) : _clock = clock ?? DateTime.now;

  final AlertClock _clock;
  final Duration cooldown;
  final int minimumScore;
  final int significantScoreIncrease;

  final Map<String, SignalStage> _seenStages = <String, SignalStage>{};
  final Map<String, _AlertRecord> _lastBySymbol = <String, _AlertRecord>{};
  final List<TradeAlert> _history = <TradeAlert>[];

  List<TradeAlert> get history => List<TradeAlert>.unmodifiable(_history);

  void prime(Iterable<RadarSignal> signals) {
    for (final RadarSignal signal in signals) {
      _seenStages[signal.id] = signal.stage;
    }
  }

  TradeAlert? evaluate(
    Iterable<RadarSignal> signals, {
    EntryReadinessResult? readiness,
  }) {
    final List<RadarSignal> ordered = signals.toList(growable: false)
      ..sort((RadarSignal a, RadarSignal b) {
        final DateTime first = a.entryConfirmedTime ?? a.time;
        final DateTime second = b.entryConfirmedTime ?? b.time;
        return second.compareTo(first);
      });
    TradeAlert? alert;
    for (final RadarSignal signal in ordered) {
      final SignalStage? previous = _seenStages[signal.id];
      _seenStages[signal.id] = signal.stage;
      if (alert != null ||
          signal.stage != SignalStage.entryConfirmed ||
          previous == SignalStage.entryConfirmed ||
          (readiness != null && !readiness.entryReady) ||
          !_isStrong(signal) ||
          !_cooldownAllows(signal)) {
        continue;
      }
      alert = TradeAlert(signal: signal, createdAt: _clock());
      _history.insert(0, alert);
      _lastBySymbol[signal.symbol] = _AlertRecord(
        signalId: signal.id,
        direction: signal.direction,
        score: signal.score,
        time: alert.createdAt,
      );
    }
    if (_seenStages.length > 2000) {
      final Set<String> activeIds = ordered
          .map<String>((RadarSignal signal) => signal.id)
          .toSet();
      _seenStages.removeWhere(
        (String signalId, SignalStage _) => !activeIds.contains(signalId),
      );
    }
    if (alert != null) notifyListeners();
    return alert;
  }

  bool _isStrong(RadarSignal signal) {
    final SignalQualityScores quality = signal.qualities;
    return signal.score >= minimumScore &&
        signal.stopIsSafe &&
        quality.direction >= 65 &&
        quality.entry >= 55 &&
        quality.stop >= 55 &&
        quality.risk >= 55;
  }

  bool _cooldownAllows(RadarSignal signal) {
    final _AlertRecord? previous = _lastBySymbol[signal.symbol];
    if (previous == null) return true;
    if (previous.signalId == signal.id) return false;
    if (previous.direction != signal.direction) return true;
    if (signal.score >= previous.score + significantScoreIncrease) return true;
    return _clock().difference(previous.time) >= cooldown;
  }
}

class _AlertRecord {
  const _AlertRecord({
    required this.signalId,
    required this.direction,
    required this.score,
    required this.time,
  });

  final String signalId;
  final SignalDirection direction;
  final int score;
  final DateTime time;
}
