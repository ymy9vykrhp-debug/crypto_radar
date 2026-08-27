enum ExchangeVenue { bybit, okx, binance, coinbase }

extension ExchangeVenueText on ExchangeVenue {
  String get label => name.toUpperCase();
}

class InstrumentTradingRules {
  const InstrumentTradingRules({
    required this.symbol,
    required this.venue,
    this.tickSize = 0.0,
    this.quantityStep = 0.0,
    this.minOrderQuantity = 0.0,
    this.minNotional = 0.0,
    this.maxLeverage = 0.0,
  });

  final String symbol;
  final ExchangeVenue venue;
  final double tickSize;
  final double quantityStep;
  final double minOrderQuantity;
  final double minNotional;
  final double maxLeverage;

  bool get isComplete =>
      tickSize > 0 &&
      quantityStep > 0 &&
      minOrderQuantity >= 0 &&
      minNotional >= 0 &&
      maxLeverage > 0;
}
