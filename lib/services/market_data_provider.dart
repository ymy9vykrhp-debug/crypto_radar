import '../models/crypto_universe_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';

/// Common boundary for exchange adapters. SignalEngine only receives normalized
/// models and never depends on an exchange-specific JSON response.
abstract interface class MarketDataProvider {
  ExchangeVenue get venue;

  Future<List<CryptoAsset>> loadCryptoUniverse();

  Future<MarketSnapshot> load(String symbol);

  Future<TickerStats> loadTicker(String symbol);

  Future<List<Candle>> loadCandles(
    String symbol,
    String interval, {
    int limit = 240,
    DateTime? startTime,
    DateTime? endTime,
  });

  Future<List<Candle>> loadHistoricalCandles(
    String symbol,
    String interval, {
    int count = 5000,
  });

  Future<InstrumentTradingRules?> loadTradingRules(String symbol);
}
