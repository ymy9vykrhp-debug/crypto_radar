import 'signal_models.dart';

class TradeAlert {
  const TradeAlert({required this.signal, required this.createdAt});

  final RadarSignal signal;
  final DateTime createdAt;

  double get riskReward {
    final double risk = signal.risk;
    if (risk <= 0.0) return 0.0;
    return (signal.tp1 - signal.entryPrice).abs() / risk;
  }
}
