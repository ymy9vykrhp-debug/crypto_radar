import 'package:crypto_radar/models/broker_models.dart';
import 'package:crypto_radar/services/execution/execution_broker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Execution safety boundary', () {
    test('default broker is monitor-only and rejects mutations', () async {
      const MonitorOnlyBroker broker = MonitorOnlyBroker();
      final BrokerStatus status = await broker.status();

      expect(status.mode, ExecutionMode.off);
      expect(status.canPlaceOrders, isFalse);
      expect((await broker.cancel('any')).accepted, isFalse);
    });

    test('live broker remains hard blocked', () async {
      const LiveBlockedBroker broker = LiveBlockedBroker();
      final BrokerStatus status = await broker.status();

      expect(status.mode, ExecutionMode.bybitLive);
      expect(status.readiness, BrokerReadiness.liveBlocked);
      expect(status.canPlaceOrders, isFalse);
      expect((await broker.cancel('any')).message, contains('not connected'));
    });

    test('paper and demo foundations report not configured', () async {
      for (final ExecutionMode mode in <ExecutionMode>[
        ExecutionMode.paper,
        ExecutionMode.bybitDemo,
      ]) {
        final UnconfiguredExecutionBroker broker = UnconfiguredExecutionBroker(
          mode,
        );
        final BrokerStatus status = await broker.status();
        expect(status.readiness, BrokerReadiness.notConfigured);
        expect(status.canPlaceOrders, isFalse);
      }
    });
  });
}
