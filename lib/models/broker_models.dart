import 'position_calculator_models.dart';

enum ExecutionMode { off, paper, bybitDemo, bybitLive }

enum BrokerReadiness { monitorOnly, ready, notConfigured, liveBlocked }

class BrokerStatus {
  const BrokerStatus({
    required this.mode,
    required this.readiness,
    required this.message,
  });

  final ExecutionMode mode;
  final BrokerReadiness readiness;
  final String message;

  bool get canPlaceOrders => readiness == BrokerReadiness.ready;
}

class BrokerOrderRequest {
  const BrokerOrderRequest({required this.clientOrderId, required this.plan});

  final String clientOrderId;
  final SmartTradePlan plan;
}

class BrokerOrderResult {
  const BrokerOrderResult({
    required this.accepted,
    required this.message,
    this.exchangeOrderId,
  });

  final bool accepted;
  final String message;
  final String? exchangeOrderId;
}
