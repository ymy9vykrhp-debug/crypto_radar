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
    this.leverageStep = 0.0,
  });

  final String symbol;
  final ExchangeVenue venue;
  final double tickSize;
  final double quantityStep;
  final double minOrderQuantity;
  final double minNotional;
  final double maxLeverage;
  final double leverageStep;

  bool get isComplete =>
      tickSize > 0 &&
      quantityStep > 0 &&
      minOrderQuantity > 0 &&
      minNotional > 0 &&
      maxLeverage > 0 &&
      leverageStep > 0;
}

enum MarketDataQualityLevel { high, medium, low }

extension MarketDataQualityLevelText on MarketDataQualityLevel {
  String get label => name.toUpperCase();
}

/// Immutable diagnostics produced at the market-data boundary.
///
/// Missing values are never replaced with invented numbers. Consumers can use
/// [hasCriticalIssue] as a deterministic safety veto before creating an entry.
class MarketDataIntegrity {
  const MarketDataIntegrity({
    required this.level,
    required this.issues,
    required this.hasCriticalIssue,
    required this.hasFreshBidAsk,
    required this.hasInstrumentRules,
    required this.minimumCandleCount,
    required this.checkedAt,
  });

  const MarketDataIntegrity.unavailable()
    : level = MarketDataQualityLevel.low,
      issues = const <String>['DATA_INTEGRITY_NOT_EVALUATED'],
      hasCriticalIssue = true,
      hasFreshBidAsk = false,
      hasInstrumentRules = false,
      minimumCandleCount = 0,
      checkedAt = null;

  final MarketDataQualityLevel level;
  final List<String> issues;
  final bool hasCriticalIssue;
  final bool hasFreshBidAsk;
  final bool hasInstrumentRules;
  final int minimumCandleCount;
  final DateTime? checkedAt;
}
