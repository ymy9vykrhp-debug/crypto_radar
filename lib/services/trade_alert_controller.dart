import 'package:flutter/foundation.dart';

import '../engines/entry_readiness_gate.dart';
import '../models/execution_models.dart';
import '../models/signal_models.dart';
import '../models/trade_alert_models.dart';
import 'notifications/trade_alert_event_ledger.dart';

typedef AlertClock = DateTime Function();

/// Converts SignalEngine/TradeTracker transitions into idempotent alert events.
/// It does not calculate a second trading opinion and never places orders.
class TradeAlertController extends ChangeNotifier {
  TradeAlertController({
    AlertClock? clock,
    this.cooldown = const Duration(minutes: 30),
    this.minimumScore = 80,
    this.significantScoreIncrease = 10,
    this.maximumDeliveryAttempts = 3,
    TradeAlertEventLedger? ledger,
  }) : _clock = clock ?? DateTime.now,
       _ledger = ledger ?? TradeAlertEventLedger();

  final AlertClock _clock;
  final Duration cooldown;
  final int minimumScore;
  final int significantScoreIncrease;
  final int maximumDeliveryAttempts;
  final TradeAlertEventLedger _ledger;

  final Map<String, SignalStage> _seenStages = <String, SignalStage>{};
  final Map<String, _AlertRecord> _lastBySymbol = <String, _AlertRecord>{};
  final Map<String, _DeliveryAttempt> _deliveryAttempts =
      <String, _DeliveryAttempt>{};
  final Set<String> _wasEntryReady = <String>{};
  final Map<String, int> _negativeReadinessChecks = <String, int>{};
  final List<TradeAlert> _history = <TradeAlert>[];
  bool _initialized = false;

  List<TradeAlert> get history => List<TradeAlert>.unmodifiable(_history);

  Future<void> initialize() async {
    if (_initialized) return;
    await _ledger.initialize();
    _initialized = true;
  }

  /// Captures the pre-refresh stages. Call before TradeTracker updates signals.
  void prime(Iterable<RadarSignal> signals) {
    for (final RadarSignal signal in signals) {
      _seenStages[signal.id] = signal.stage;
    }
  }

  /// Compatibility helper used by focused tests and one-event consumers.
  TradeAlert? evaluate(
    Iterable<RadarSignal> signals, {
    required EntryReadinessResult readiness,
    double tickSize = 0.0,
  }) {
    final List<TradeAlert> events = evaluateEvents(
      signals,
      readiness: readiness,
      tickSize: tickSize,
    );
    return events.isEmpty ? null : events.first;
  }

  List<TradeAlert> evaluateEvents(
    Iterable<RadarSignal> signals, {
    required EntryReadinessResult readiness,
    double tickSize = 0.0,
  }) {
    if (!_initialized) return const <TradeAlert>[];
    final List<RadarSignal> ordered = signals.toList(growable: false)
      ..sort((RadarSignal a, RadarSignal b) {
        final DateTime first = a.entryConfirmedTime ?? a.time;
        final DateTime second = b.entryConfirmedTime ?? b.time;
        return second.compareTo(first);
      });
    final List<TradeAlert> events = <TradeAlert>[];
    for (final RadarSignal signal in ordered) {
      final SignalStage? previousStage = _seenStages[signal.id];
      _seenStages[signal.id] = signal.stage;

      final TradeAlertKind? trackerKind = _trackerKind(
        previousStage,
        signal.stage,
      );
      if (trackerKind != null) {
        _queueIfAllowed(
          events,
          kind: trackerKind,
          signal: signal,
          readiness: readiness,
          tickSize: tickSize,
        );
      }

      if (readiness.signalId != null && readiness.signalId != signal.id) {
        continue;
      }
      if (readiness.entryReady) {
        _wasEntryReady.add(signal.id);
        _negativeReadinessChecks.remove(signal.id);
        if (signal.stage == SignalStage.entryConfirmed &&
            _isStrong(signal) &&
            _cooldownAllows(signal)) {
          _queueIfAllowed(
            events,
            kind: TradeAlertKind.entryReady,
            signal: signal,
            readiness: readiness,
            tickSize: tickSize,
          );
        }
      } else if (_wasEntryReady.contains(signal.id)) {
        if ((signal.stage == SignalStage.inPosition ||
                signal.stage == SignalStage.tp1Hit) &&
            _postEntryRiskChanged(readiness)) {
          final int failures = (_negativeReadinessChecks[signal.id] ?? 0) + 1;
          _negativeReadinessChecks[signal.id] = failures;
          if (failures >= 2) {
            _queueIfAllowed(
              events,
              kind: TradeAlertKind.conditionsWorsened,
              signal: signal,
              readiness: readiness,
              tickSize: tickSize,
            );
          }
        } else if (signal.stage.isWaiting &&
            readiness.status == EntryReadinessStatus.suspended) {
          _queueIfAllowed(
            events,
            kind: TradeAlertKind.entrySuspended,
            signal: signal,
            readiness: readiness,
            tickSize: tickSize,
          );
        } else if (signal.stage.isWaiting) {
          final int failures = (_negativeReadinessChecks[signal.id] ?? 0) + 1;
          _negativeReadinessChecks[signal.id] = failures;
          if (failures >= 2) {
            _queueIfAllowed(
              events,
              kind: TradeAlertKind.entryRevoked,
              signal: signal,
              readiness: readiness,
              tickSize: tickSize,
            );
            _wasEntryReady.remove(signal.id);
          }
        }
      }
    }
    if (_seenStages.length > 2000) {
      final Set<String> activeIds = ordered
          .map<String>((RadarSignal signal) => signal.id)
          .toSet();
      _seenStages.removeWhere(
        (String signalId, SignalStage _) => !activeIds.contains(signalId),
      );
    }
    if (events.isNotEmpty) notifyListeners();
    return List<TradeAlert>.unmodifiable(events);
  }

  /// A failed delivery becomes retryable after bounded backoff. Successful or
  /// intentionally disabled delivery is persisted and will not repeat.
  Future<void> recordDelivery(
    TradeAlert alert, {
    required bool successful,
  }) async {
    if (successful) {
      _deliveryAttempts.remove(alert.eventId);
      await _ledger.markDelivered(alert.eventId, _clock());
      if (alert.kind == TradeAlertKind.entryReady) {
        _lastBySymbol[alert.signal.symbol] = _AlertRecord(
          signalId: alert.signal.id,
          direction: alert.signal.direction,
          score: alert.signal.score,
          time: alert.createdAt,
        );
      }
    } else {
      final int attempts =
          _deliveryAttempts[alert.eventId]?.attempts ?? alert.deliveryAttempt;
      _deliveryAttempts[alert.eventId] = _DeliveryAttempt(
        attempts: attempts,
        retryAt: _clock().add(_retryDelay(attempts)),
      );
    }
    notifyListeners();
  }

  void _queueIfAllowed(
    List<TradeAlert> events, {
    required TradeAlertKind kind,
    required RadarSignal signal,
    required EntryReadinessResult readiness,
    required double tickSize,
  }) {
    final String eventId = '${kind.eventPrefix}:${signal.id}';
    if (!_deliveryAllows(eventId)) return;
    final int attempt = (_deliveryAttempts[eventId]?.attempts ?? 0) + 1;
    final TradeAlert alert = TradeAlert(
      kind: kind,
      signal: signal,
      createdAt: _clock(),
      readiness: readiness,
      tickSize: tickSize,
      deliveryAttempt: attempt,
      eventIdOverride: eventId,
    );
    _deliveryAttempts[eventId] = _DeliveryAttempt(
      attempts: attempt,
      retryAt: DateTime.utc(9999),
    );
    if (!_history.any((TradeAlert value) => value.eventId == eventId)) {
      _history.insert(0, alert);
      if (_history.length > 500) _history.removeLast();
    }
    events.add(alert);
  }

  bool _deliveryAllows(String eventId) {
    if (_ledger.contains(eventId)) return false;
    final _DeliveryAttempt? pending = _deliveryAttempts[eventId];
    if (pending == null) return true;
    if (pending.attempts >= maximumDeliveryAttempts) return false;
    return !_clock().isBefore(pending.retryAt);
  }

  TradeAlertKind? _trackerKind(SignalStage? previous, SignalStage current) {
    if (previous == null || previous == current) return null;
    return switch (current) {
      SignalStage.inPosition => TradeAlertKind.positionActive,
      SignalStage.tp1Hit => TradeAlertKind.tp1Hit,
      SignalStage.tp2Hit => TradeAlertKind.tp2Hit,
      SignalStage.stopped => TradeAlertKind.stopHit,
      SignalStage.cancelled => TradeAlertKind.setupCancelled,
      SignalStage.expired => TradeAlertKind.setupExpired,
      _ => null,
    };
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

  bool _postEntryRiskChanged(EntryReadinessResult readiness) {
    const Set<String> critical = <String>{
      'CRITICAL_MARKET_DATA',
      'BID_ASK_STALE',
      'LIQUIDITY_INVALID',
      'MARKET_CONFLICT',
      'SIGNAL_STALE',
      'HARD_BLOCK',
      'DIRECTION_QUALITY_FAILED',
    };
    return readiness.status == EntryReadinessStatus.suspended ||
        readiness.reasonCodes.any(critical.contains);
  }

  Duration _retryDelay(int attempts) => switch (attempts) {
    <= 1 => const Duration(seconds: 15),
    2 => const Duration(minutes: 1),
    _ => const Duration(minutes: 5),
  };
}

class _DeliveryAttempt {
  const _DeliveryAttempt({required this.attempts, required this.retryAt});

  final int attempts;
  final DateTime retryAt;
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
