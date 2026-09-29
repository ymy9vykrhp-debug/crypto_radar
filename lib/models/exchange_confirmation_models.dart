import 'market_models.dart';

/// Lightweight, non-execution market confirmation from a secondary venue.
///
/// It deliberately contains only public price/volume context. It never carries
/// position sizing or trading permissions, so a secondary exchange cannot
/// become the source of truth for a Bybit trade.
class ExchangeConfirmationSnapshot {
  const ExchangeConfirmationSnapshot({
    required this.venue,
    required this.symbol,
    required this.updatedAt,
    required this.price,
    required this.change5mPercent,
    required this.change15mPercent,
    required this.change1hPercent,
    required this.trend5m,
    required this.trend15m,
    required this.trend1h,
    required this.relativeVolume5m,
  });

  final String venue;
  final String symbol;
  final DateTime updatedAt;
  final double price;
  final double change5mPercent;
  final double change15mPercent;
  final double change1hPercent;
  final Bias trend5m;
  final Bias trend15m;
  final Bias trend1h;
  final double relativeVolume5m;

  bool isFreshAt(
    DateTime now, {
    Duration maximumAge = const Duration(seconds: 75),
  }) {
    final Duration age = now.toUtc().difference(updatedAt.toUtc());
    return !age.isNegative && age <= maximumAge;
  }
}
