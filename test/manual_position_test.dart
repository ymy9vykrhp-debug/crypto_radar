import 'package:crypto_radar/engines/manual_assistant_engine.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('position protection never widens the original direction risk', () {
    final ManualPosition position = ManualPosition(
      side: SignalDirection.long,
      entry: 0.14,
      stop: 0.13,
      initialStop: 0.13,
      quantity: 1000,
      openedAt: DateTime.utc(2026, 9, 28),
      qualityAtOpen: 82,
      entryLowAtOpen: 0.139,
      entryHighAtOpen: 0.141,
      plannedTargets: const <double>[0.142, 0.145, 0.148],
    );

    final ManualPosition protected = position.protect(0.135);
    expect(protected.stop, 0.135);
    expect(protected.qualityAtOpen, 82);
    expect(protected.plannedTargets, const <double>[0.142, 0.145, 0.148]);

    expect(() => position.protect(0.125), throwsArgumentError);
  });

  test('legacy stored positions remain readable', () {
    final ManualPosition restored = ManualPosition.fromJson(<String, dynamic>{
      'side': 'short',
      'entry': 0.15,
      'stop': 0.16,
      'initialStop': 0.16,
      'quantity': 500,
      'openedAt': '2026-09-28T12:00:00.000Z',
      'partialTaken': false,
    });

    expect(restored.side, SignalDirection.short);
    expect(restored.qualityAtOpen, isNull);
    expect(restored.plannedTargets, isEmpty);
  });
}
