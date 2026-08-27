import '../../models/broker_models.dart';

abstract interface class ExecutionBroker {
  ExecutionMode get mode;

  Future<BrokerStatus> status();

  Future<BrokerOrderResult> place(BrokerOrderRequest request);

  Future<BrokerOrderResult> cancel(String clientOrderId);
}

/// Default broker used by the application. It proves that analytics and UI can
/// never place an order merely because a TradePlan exists.
class MonitorOnlyBroker implements ExecutionBroker {
  const MonitorOnlyBroker();

  @override
  ExecutionMode get mode => ExecutionMode.off;

  @override
  Future<BrokerStatus> status() async => const BrokerStatus(
    mode: ExecutionMode.off,
    readiness: BrokerReadiness.monitorOnly,
    message: 'MONITOR ONLY · order execution is disabled',
  );

  @override
  Future<BrokerOrderResult> place(BrokerOrderRequest request) async =>
      const BrokerOrderResult(
        accepted: false,
        message: 'ORDER BLOCKED: execution mode is OFF',
      );

  @override
  Future<BrokerOrderResult> cancel(String clientOrderId) async =>
      const BrokerOrderResult(
        accepted: false,
        message: 'ORDER BLOCKED: execution mode is OFF',
      );
}

/// Deliberately contains no HTTP client and no credentials. Live trading cannot
/// be enabled by a preference toggle or an accidental UI change.
class LiveBlockedBroker implements ExecutionBroker {
  const LiveBlockedBroker();

  @override
  ExecutionMode get mode => ExecutionMode.bybitLive;

  @override
  Future<BrokerStatus> status() async => const BrokerStatus(
    mode: ExecutionMode.bybitLive,
    readiness: BrokerReadiness.liveBlocked,
    message: 'LIVE BLOCKED · research, paper and demo gates are incomplete',
  );

  @override
  Future<BrokerOrderResult> place(BrokerOrderRequest request) async =>
      const BrokerOrderResult(
        accepted: false,
        message: 'LIVE ORDER BLOCKED by immutable safety policy',
      );

  @override
  Future<BrokerOrderResult> cancel(String clientOrderId) async =>
      const BrokerOrderResult(
        accepted: false,
        message: 'LIVE broker is not connected',
      );
}

class UnconfiguredExecutionBroker implements ExecutionBroker {
  const UnconfiguredExecutionBroker(this.mode);

  @override
  final ExecutionMode mode;

  @override
  Future<BrokerStatus> status() async => BrokerStatus(
    mode: mode,
    readiness: BrokerReadiness.notConfigured,
    message: '${mode.name.toUpperCase()} · NOT CONFIGURED',
  );

  @override
  Future<BrokerOrderResult> place(BrokerOrderRequest request) async =>
      BrokerOrderResult(
        accepted: false,
        message: '${mode.name.toUpperCase()} is not configured',
      );

  @override
  Future<BrokerOrderResult> cancel(String clientOrderId) async =>
      BrokerOrderResult(
        accepted: false,
        message: '${mode.name.toUpperCase()} is not configured',
      );
}
