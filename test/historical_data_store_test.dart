import 'package:crypto_radar/models/crypto_universe_models.dart';
import 'package:crypto_radar/models/historical_data_models.dart';
import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/historical_data_store.dart';
import 'package:crypto_radar/services/market_data_provider.dart';
import 'package:crypto_radar/services/storage/historical_candle_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'downloads more than one Bybit page and excludes open candles',
    () async {
      final DateTime asOf = DateTime.utc(2026, 8, 28, 12);
      final DateTime start = asOf.subtract(const Duration(minutes: 2500));
      final _FakeProvider provider = _FakeProvider(_candles(start, 2501));
      final HistoricalDataStore store = HistoricalDataStore(
        provider: provider,
        cache: _MemoryHistoryCache(),
      );

      final HistoricalDataSet result = await store.loadRange(
        'BTCUSDT',
        '1',
        start: start,
        end: asOf.add(const Duration(minutes: 1)),
        asOf: asOf,
      );

      expect(result.candles, hasLength(2500));
      expect(
        result.candles.last.time,
        asOf.subtract(const Duration(minutes: 1)),
      );
      expect(result.isComplete, isTrue);
      expect(provider.candleRequests, 3);
    },
  );

  test('second update requests only the missing tail', () async {
    final DateTime firstAsOf = DateTime.utc(2026, 8, 28, 12);
    final DateTime start = firstAsOf.subtract(const Duration(minutes: 300));
    final _FakeProvider provider = _FakeProvider(_candles(start, 310));
    final _MemoryHistoryCache cache = _MemoryHistoryCache();
    final HistoricalDataStore store = HistoricalDataStore(
      provider: provider,
      cache: cache,
    );
    await store.loadRange(
      'BTCUSDT',
      '1',
      start: start,
      end: firstAsOf,
      asOf: firstAsOf,
    );
    provider.candleRequests = 0;

    final DateTime secondAsOf = firstAsOf.add(const Duration(minutes: 10));
    final HistoricalDataSet result = await store.loadRange(
      'BTCUSDT',
      '1',
      start: start,
      end: secondAsOf,
      asOf: secondAsOf,
    );

    expect(result.candles, hasLength(310));
    expect(provider.candleRequests, 1);
    expect(result.isComplete, isTrue);
  });

  test('provider failure keeps the previously valid local cache', () async {
    final DateTime firstAsOf = DateTime.utc(2026, 8, 28, 12);
    final DateTime start = firstAsOf.subtract(const Duration(minutes: 300));
    final _FakeProvider provider = _FakeProvider(_candles(start, 310));
    final _MemoryHistoryCache cache = _MemoryHistoryCache();
    final HistoricalDataStore store = HistoricalDataStore(
      provider: provider,
      cache: cache,
    );
    await store.loadRange(
      'BTCUSDT',
      '1',
      start: start,
      end: firstAsOf,
      asOf: firstAsOf,
    );
    provider.fail = true;

    final HistoricalDataSet result = await store.loadRange(
      'BTCUSDT',
      '1',
      start: start,
      end: firstAsOf.add(const Duration(minutes: 10)),
      asOf: firstAsOf.add(const Duration(minutes: 10)),
    );

    expect(result.candles, hasLength(300));
    expect(result.issues, contains('PROVIDER_FAILURE'));
    expect(result.issues, contains('MISSING_CANDLES'));
    expect(cache.values, isNotEmpty);
  });
}

List<Candle> _candles(DateTime start, int count) {
  return List<Candle>.generate(count, (int index) {
    final double open = 100.0 + index / 1000.0;
    return Candle(
      time: start.add(Duration(minutes: index)),
      open: open,
      high: open + 0.2,
      low: open - 0.2,
      close: open + 0.1,
      volume: 1000.0,
    );
  }, growable: false);
}

class _MemoryHistoryCache implements HistoricalCandleCache {
  final Map<String, Map<String, dynamic>> values =
      <String, Map<String, dynamic>>{};

  @override
  Future<Map<String, dynamic>?> read(String key) async => values[key];

  @override
  Future<void> write(String key, Map<String, dynamic> value) async {
    values[key] = value;
  }
}

class _FakeProvider implements MarketDataProvider {
  _FakeProvider(this.candles);

  final List<Candle> candles;
  int candleRequests = 0;
  bool fail = false;

  @override
  ExchangeVenue get venue => ExchangeVenue.bybit;

  @override
  Future<List<Candle>> loadCandles(
    String symbol,
    String interval, {
    int limit = 240,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    candleRequests++;
    if (fail) throw Exception('network down');
    final List<Candle> filtered = candles
        .where(
          (Candle candle) =>
              (startTime == null || !candle.time.isBefore(startTime)) &&
              (endTime == null || !candle.time.isAfter(endTime)),
        )
        .toList(growable: false);
    if (filtered.length <= limit) return filtered;
    return filtered.sublist(filtered.length - limit);
  }

  @override
  Future<List<Candle>> loadHistoricalCandles(
    String symbol,
    String interval, {
    int count = 5000,
  }) async => candles;

  @override
  Future<InstrumentTradingRules?> loadTradingRules(String symbol) async => null;

  @override
  Future<List<CryptoAsset>> loadCryptoUniverse() async => const <CryptoAsset>[];

  @override
  Future<MarketSnapshot> load(String symbol) =>
      throw UnsupportedError('not needed');

  @override
  Future<TickerStats> loadTicker(String symbol) =>
      throw UnsupportedError('not needed');
}
