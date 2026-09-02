import 'package:crypto_radar/engines/entry_readiness_gate.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:crypto_radar/models/trade_alert_models.dart';
import 'package:crypto_radar/services/trade_alert_controller.dart';
import 'package:crypto_radar/services/notifications/trade_alert_event_ledger.dart';
import 'package:crypto_radar/services/storage/local_storage_base.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alerts once when a strong signal becomes entry ready', () async {
    DateTime now = DateTime.utc(2026, 8, 26, 12);
    final TradeAlertController controller = TradeAlertController(
      clock: () => now,
      ledger: TradeAlertEventLedger(storage: _MemoryStorage()),
    );
    await controller.initialize();
    final RadarSignal waiting = _signal(
      id: 'first',
      stage: SignalStage.waitForTrigger,
    );
    controller.prime(<RadarSignal>[waiting]);

    final RadarSignal confirmed = waiting.copyWith(
      stage: SignalStage.entryConfirmed,
      entryConfirmedTime: now,
    );
    final first = controller.evaluate(<RadarSignal>[
      confirmed,
    ], readiness: _ready('first'));
    expect(first, isNotNull);
    await controller.recordDelivery(first!, successful: true);
    expect(
      controller.evaluate(<RadarSignal>[confirmed], readiness: _ready('first')),
      isNull,
    );
    expect(controller.history, hasLength(1));

    final RadarSignal repeatedSameDirection = _signal(
      id: 'second',
      stage: SignalStage.entryConfirmed,
    );
    expect(
      controller.evaluate(<RadarSignal>[
        confirmed,
        repeatedSameDirection,
      ], readiness: _ready('second')),
      isNull,
    );

    now = now.add(const Duration(minutes: 31));
    final RadarSignal afterCooldown = _signal(
      id: 'third',
      stage: SignalStage.entryConfirmed,
    );
    expect(
      controller.evaluate(<RadarSignal>[
        confirmed,
        afterCooldown,
      ], readiness: _ready('third')),
      isNotNull,
    );
    controller.dispose();
  });

  test(
    'direction change bypasses cooldown but a weak setup never alerts',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 26, 12);
      final TradeAlertController controller = TradeAlertController(
        clock: () => now,
        ledger: TradeAlertEventLedger(storage: _MemoryStorage()),
      );
      await controller.initialize();
      final longAlert = controller.evaluate(<RadarSignal>[
        _signal(id: 'long', stage: SignalStage.entryConfirmed),
      ], readiness: _ready('long'));
      expect(longAlert, isNotNull);
      await controller.recordDelivery(longAlert!, successful: true);
      final shortAlert = controller.evaluate(<RadarSignal>[
        _signal(id: 'short', stage: SignalStage.entryConfirmed, short: true),
      ], readiness: _ready('short'));
      expect(shortAlert, isNotNull);
      await controller.recordDelivery(shortAlert!, successful: true);
      expect(
        controller.evaluate(<RadarSignal>[
          _signal(id: 'weak', stage: SignalStage.entryConfirmed, score: 75),
        ], readiness: _ready('weak')),
        isNull,
      );
      controller.dispose();
    },
  );

  test('failed delivery retries the same event id after backoff', () async {
    DateTime now = DateTime.utc(2026, 8, 26, 12);
    final TradeAlertController controller = TradeAlertController(
      clock: () => now,
      ledger: TradeAlertEventLedger(storage: _MemoryStorage()),
    );
    await controller.initialize();
    final RadarSignal signal = _signal(
      id: 'retry',
      stage: SignalStage.entryConfirmed,
    );

    final first = controller.evaluate(<RadarSignal>[
      signal,
    ], readiness: _ready('retry'));
    expect(first, isNotNull);
    await controller.recordDelivery(first!, successful: false);
    expect(
      controller.evaluate(<RadarSignal>[signal], readiness: _ready('retry')),
      isNull,
    );

    now = now.add(const Duration(seconds: 15));
    final retry = controller.evaluate(<RadarSignal>[
      signal,
    ], readiness: _ready('retry'));
    expect(retry?.eventId, first.eventId);
    expect(retry?.deliveryAttempt, 2);
    controller.dispose();
  });

  test('delivered event stays deduplicated after controller restart', () async {
    final _MemoryStorage storage = _MemoryStorage();
    final RadarSignal signal = _signal(
      id: 'persisted',
      stage: SignalStage.entryConfirmed,
    );
    final TradeAlertController firstController = TradeAlertController(
      ledger: TradeAlertEventLedger(storage: storage),
    );
    await firstController.initialize();
    final alert = firstController.evaluate(<RadarSignal>[
      signal,
    ], readiness: _ready('persisted'));
    expect(alert, isNotNull);
    await firstController.recordDelivery(alert!, successful: true);
    firstController.dispose();

    final TradeAlertController restarted = TradeAlertController(
      ledger: TradeAlertEventLedger(storage: storage),
    );
    await restarted.initialize();
    expect(
      restarted.evaluate(<RadarSignal>[signal], readiness: _ready('persisted')),
      isNull,
    );
    restarted.dispose();
  });

  test('tracker transition emits TP1 and gate loss is debounced', () async {
    final TradeAlertController controller = TradeAlertController(
      ledger: TradeAlertEventLedger(storage: _MemoryStorage()),
    );
    await controller.initialize();
    final RadarSignal confirmed = _signal(
      id: 'tracked',
      stage: SignalStage.entryConfirmed,
    );
    final TradeAlert? ready = controller.evaluate(<RadarSignal>[
      confirmed,
    ], readiness: _ready('tracked'));
    expect(ready?.kind, TradeAlertKind.entryReady);
    await controller.recordDelivery(ready!, successful: true);

    expect(
      controller.evaluate(<RadarSignal>[
        confirmed,
      ], readiness: _notReady('tracked')),
      isNull,
    );
    final TradeAlert? revoked = controller.evaluate(<RadarSignal>[
      confirmed,
    ], readiness: _notReady('tracked'));
    expect(revoked?.kind, TradeAlertKind.entryRevoked);

    final RadarSignal inPosition = confirmed.copyWith(
      stage: SignalStage.inPosition,
      status: SignalStatus.inPosition,
    );
    controller.prime(<RadarSignal>[inPosition]);
    final RadarSignal tp1 = inPosition.copyWith(
      stage: SignalStage.tp1Hit,
      status: SignalStatus.tp1Hit,
    );
    final List<TradeAlert> events = controller.evaluateEvents(<RadarSignal>[
      tp1,
    ], readiness: _notReady('tracked'));
    expect(
      events.map<TradeAlertKind>((TradeAlert event) => event.kind),
      contains(TradeAlertKind.tp1Hit),
    );
    controller.dispose();
  });

  test(
    'post-entry critical conflict emits informational warning only',
    () async {
      final TradeAlertController controller = TradeAlertController(
        ledger: TradeAlertEventLedger(storage: _MemoryStorage()),
      );
      await controller.initialize();
      final RadarSignal confirmed = _signal(
        id: 'managed',
        stage: SignalStage.entryConfirmed,
      );
      final TradeAlert? ready = controller.evaluate(<RadarSignal>[
        confirmed,
      ], readiness: _ready('managed'));
      expect(ready?.kind, TradeAlertKind.entryReady);
      await controller.recordDelivery(ready!, successful: true);

      final RadarSignal inPosition = confirmed.copyWith(
        stage: SignalStage.inPosition,
        status: SignalStatus.inPosition,
      );
      controller.prime(<RadarSignal>[confirmed]);
      final List<TradeAlert> first = controller.evaluateEvents(<RadarSignal>[
        inPosition,
      ], readiness: _criticalNotReady('managed'));
      expect(
        first.map<TradeAlertKind>((TradeAlert alert) => alert.kind),
        contains(TradeAlertKind.positionActive),
      );
      final TradeAlert? warning = controller.evaluate(<RadarSignal>[
        inPosition,
      ], readiness: _criticalNotReady('managed'));
      expect(warning?.kind, TradeAlertKind.conditionsWorsened);
      controller.dispose();
    },
  );
}

class _MemoryStorage implements LocalStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

EntryReadinessResult _ready(String signalId) => EntryReadinessResult(
  signalId: signalId,
  evaluatedAt: DateTime.utc(2026, 8, 26, 12),
  status: EntryReadinessStatus.entryReady,
  nextAction: EntryNextAction.enter,
  reasons: const <EntryReadinessReason>[],
  dataQuality: DataQuality.high,
  hardBlocked: false,
  marketDataReady: true,
  microstructureReady: true,
  entryConfirmed: true,
  priceInZone: true,
  liquidityReady: true,
  riskReady: true,
  directionReady: true,
  entryReady: true,
);

EntryReadinessResult _notReady(String signalId) => EntryReadinessResult(
  signalId: signalId,
  evaluatedAt: DateTime.utc(2026, 8, 26, 12),
  status: EntryReadinessStatus.almostReady,
  nextAction: EntryNextAction.waitForZone,
  reasons: const <EntryReadinessReason>[
    EntryReadinessReason.priceOutsideEntryZone,
  ],
  dataQuality: DataQuality.high,
  hardBlocked: false,
  marketDataReady: true,
  microstructureReady: true,
  entryConfirmed: true,
  priceInZone: false,
  liquidityReady: true,
  riskReady: true,
  directionReady: true,
  entryReady: false,
);

EntryReadinessResult _criticalNotReady(String signalId) => EntryReadinessResult(
  signalId: signalId,
  evaluatedAt: DateTime.utc(2026, 8, 26, 12),
  status: EntryReadinessStatus.almostReady,
  nextAction: EntryNextAction.waitForDirection,
  reasons: const <EntryReadinessReason>[EntryReadinessReason.marketConflict],
  dataQuality: DataQuality.high,
  hardBlocked: false,
  marketDataReady: true,
  microstructureReady: true,
  entryConfirmed: true,
  priceInZone: false,
  liquidityReady: true,
  riskReady: true,
  directionReady: false,
  entryReady: false,
  marketContextReady: false,
);

RadarSignal _signal({
  required String id,
  required SignalStage stage,
  bool short = false,
  int score = 88,
}) {
  final SignalDirection direction = short
      ? SignalDirection.short
      : SignalDirection.long;
  return RadarSignal(
    id: id,
    symbol: 'BTCUSDT',
    time: DateTime.utc(2026, 8, 26, 11),
    direction: direction,
    referencePrice: 100,
    entryLow: 99,
    entryHigh: 100,
    stop: short ? 102 : 97,
    tp1: short ? 95 : 104,
    tp2: short ? 92 : 108,
    score: score,
    trend5m: direction.bias,
    trend15m: direction.bias,
    trend1h: direction.bias,
    rsi: 55,
    macd: 1,
    ema20: 100,
    ema50: 99,
    ema200: 95,
    relativeVolume: 1.4,
    rvolBias: direction.bias,
    fvgBias: direction.bias,
    orderBlockBias: direction.bias,
    liquidityBias: direction.bias,
    bos: direction.bias,
    choch: Bias.neutral,
    stage: stage,
    stopIsSafe: true,
    qualities: const SignalQualityScores(
      direction: 88,
      entry: 80,
      stop: 78,
      risk: 75,
    ),
  );
}
