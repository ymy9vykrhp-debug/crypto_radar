import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:crypto_radar/services/trade_alert_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('alerts only on a strong transition to ENTRY_CONFIRMED', () {
    DateTime now = DateTime.utc(2026, 8, 26, 12);
    final TradeAlertController controller = TradeAlertController(
      clock: () => now,
    );
    final RadarSignal waiting = _signal(
      id: 'first',
      stage: SignalStage.waitForTrigger,
    );
    controller.prime(<RadarSignal>[waiting]);

    final RadarSignal confirmed = waiting.copyWith(
      stage: SignalStage.entryConfirmed,
      entryConfirmedTime: now,
    );
    expect(controller.evaluate(<RadarSignal>[confirmed]), isNotNull);
    expect(controller.evaluate(<RadarSignal>[confirmed]), isNull);
    expect(controller.history, hasLength(1));

    final RadarSignal repeatedSameDirection = _signal(
      id: 'second',
      stage: SignalStage.entryConfirmed,
    );
    expect(
      controller.evaluate(<RadarSignal>[confirmed, repeatedSameDirection]),
      isNull,
    );

    now = now.add(const Duration(minutes: 31));
    final RadarSignal afterCooldown = _signal(
      id: 'third',
      stage: SignalStage.entryConfirmed,
    );
    expect(
      controller.evaluate(<RadarSignal>[confirmed, afterCooldown]),
      isNotNull,
    );
    controller.dispose();
  });

  test('direction change bypasses cooldown but a weak setup never alerts', () {
    final DateTime now = DateTime.utc(2026, 8, 26, 12);
    final TradeAlertController controller = TradeAlertController(
      clock: () => now,
    );
    expect(
      controller.evaluate(<RadarSignal>[
        _signal(id: 'long', stage: SignalStage.entryConfirmed),
      ]),
      isNotNull,
    );
    expect(
      controller.evaluate(<RadarSignal>[
        _signal(id: 'short', stage: SignalStage.entryConfirmed, short: true),
      ]),
      isNotNull,
    );
    expect(
      controller.evaluate(<RadarSignal>[
        _signal(id: 'weak', stage: SignalStage.entryConfirmed, score: 75),
      ]),
      isNull,
    );
    controller.dispose();
  });
}

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
