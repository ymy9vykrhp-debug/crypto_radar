import '../engines/entry_readiness_gate.dart';
import 'signal_models.dart';

enum TradeAlertKind {
  entryReady,
  entryRevoked,
  entrySuspended,
  conditionsWorsened,
  positionActive,
  tp1Hit,
  tp2Hit,
  stopHit,
  setupCancelled,
  setupExpired,
}

extension TradeAlertKindText on TradeAlertKind {
  String get wireName => switch (this) {
    TradeAlertKind.entryReady => 'ENTRY_READY',
    TradeAlertKind.entryRevoked => 'SIGNAL_INVALIDATED',
    TradeAlertKind.entrySuspended => 'ENTRY_SUSPENDED',
    TradeAlertKind.conditionsWorsened => 'CONDITIONS_WORSENED',
    TradeAlertKind.positionActive => 'POSITION_ACTIVE',
    TradeAlertKind.tp1Hit => 'TP1_HIT',
    TradeAlertKind.tp2Hit => 'TP2_HIT',
    TradeAlertKind.stopHit => 'STOP_HIT',
    TradeAlertKind.setupCancelled => 'SETUP_CANCELLED',
    TradeAlertKind.setupExpired => 'SETUP_EXPIRED',
  };

  String get eventPrefix => wireName.toLowerCase().replaceAll('_', '-');
}

class TradeAlert {
  const TradeAlert({
    required this.kind,
    required this.signal,
    required this.createdAt,
    required this.readiness,
    this.tickSize = 0.0,
    this.deliveryAttempt = 1,
    this.eventIdOverride,
  });

  final TradeAlertKind kind;
  final RadarSignal signal;
  final DateTime createdAt;
  final EntryReadinessResult readiness;
  final double tickSize;
  final int deliveryAttempt;
  final String? eventIdOverride;

  String get eventId => eventIdOverride ?? '${kind.eventPrefix}:${signal.id}';

  double get riskRewardTp1 => _riskReward(signal.tp1);

  double get riskRewardTp2 => _riskReward(signal.tp2);

  double _riskReward(double target) {
    final double risk = signal.risk;
    if (risk <= 0.0) return 0.0;
    return (target - signal.entryPrice).abs() / risk;
  }

  double get stopDistancePercent =>
      signal.entryPrice <= 0.0 ? 0.0 : signal.risk / signal.entryPrice * 100.0;

  DateTime get confirmedAt => signal.entryConfirmedTime ?? signal.time;

  Duration get setupAge {
    final Duration value = createdAt.toUtc().difference(signal.time.toUtc());
    return value.isNegative ? Duration.zero : value;
  }
}
