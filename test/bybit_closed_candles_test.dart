import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/bybit_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('live snapshot excludes forming bars on every timeframe', () async {
    final client = http.Client();
    addTearDown(client.close);
    final service = _FixtureService(client);
    final snapshot = await service.load('BTCUSDT');
    for (final frame in [
      snapshot.oneMinute,
      snapshot.fiveMinutes,
      snapshot.fifteenMinutes,
      snapshot.oneHour,
    ]) {
      expect(frame.candles.length, 240);
      expect(frame.candles.last.time.isBefore(_now), isTrue);
      expect(frame.candles.any((c) => c.close == 999), isFalse);
    }
    expect(snapshot.dataIntegrity.hasCriticalIssue, isFalse);
  });

  test(
    'early failure of a later timeframe is observed while first is pending',
    () async {
      final client = http.Client();
      addTearDown(client.close);
      final service = _FixtureService(client, fail: true);
      await expectLater(service.load('BTCUSDT'), throwsStateError);
    },
  );
}

final _now = DateTime.utc(2026, 9, 9, 12);

class _FixtureService extends BybitService {
  _FixtureService(super.client, {this.fail = false}) : super(clock: () => _now);
  final bool fail;

  @override
  Future<List<Candle>> loadCandles(
    String symbol,
    String interval, {
    int limit = 240,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (fail && interval == '5') throw StateError('test candle failure');
    if (interval == '1') {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    final step = Duration(minutes: int.parse(interval));
    return List.generate(
      241,
      (i) => Candle(
        time: _now.subtract(step * (240 - i)),
        open: 100,
        high: i == 240 ? 1000 : 101,
        low: 99,
        close: i == 240 ? 999 : 100,
        volume: 1000,
      ),
    );
  }

  @override
  Future<TickerStats> loadTicker(String symbol) async => TickerStats(
    price: 100,
    change24hPercent: 0,
    turnover24h: 1000,
    bidPrice: 99.99,
    askPrice: 100.01,
    sourceUpdatedAt: _now,
    orderBookUpdatedAt: _now,
    fundingUpdatedAt: _now,
  );

  @override
  Future<InstrumentTradingRules?> loadTradingRules(String symbol) async =>
      InstrumentTradingRules(
        symbol: symbol,
        venue: ExchangeVenue.bybit,
        tickSize: 0.01,
        quantityStep: 0.001,
        minOrderQuantity: 0.001,
        minNotional: 5,
        maxLeverage: 100,
        leverageStep: 0.01,
      );
}
