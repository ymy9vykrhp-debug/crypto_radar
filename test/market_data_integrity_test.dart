import 'package:crypto_radar/engines/market_data_integrity_engine.dart';
import 'package:crypto_radar/engines/signal_engine.dart';
import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SignalEngine preserves every ticker microstructure field', () {
    final DateTime observedAt = DateTime.utc(2026, 8, 28, 12);
    final TickerStats ticker = TickerStats(
      price: 100.25,
      change24hPercent: 1.5,
      turnover24h: 1234567.0,
      bidPrice: 100.24,
      askPrice: 100.26,
      markPrice: 100.23,
      indexPrice: 100.22,
      fundingRatePercent: 0.01,
      openInterest: 5000.0,
      openInterestValue: 501250.0,
      orderBookUpdatedAt: observedAt,
      sourceUpdatedAt: observedAt,
      fundingUpdatedAt: observedAt,
    );
    final MarketSnapshot snapshot = SignalEngine.buildSnapshot(
      symbol: 'BTCUSDT',
      ticker: ticker,
      oneCandles: _candles(const Duration(minutes: 1), observedAt),
      fiveCandles: _candles(const Duration(minutes: 5), observedAt),
      fifteenCandles: _candles(const Duration(minutes: 15), observedAt),
      hourCandles: _candles(const Duration(hours: 1), observedAt),
      tradingRules: _rules,
      observedAt: observedAt,
    );

    expect(snapshot.ticker.price, ticker.price);
    expect(snapshot.ticker.bidPrice, ticker.bidPrice);
    expect(snapshot.ticker.askPrice, ticker.askPrice);
    expect(snapshot.ticker.spreadPercent, ticker.spreadPercent);
    expect(snapshot.ticker.markPrice, ticker.markPrice);
    expect(snapshot.ticker.indexPrice, ticker.indexPrice);
    expect(snapshot.ticker.fundingRatePercent, ticker.fundingRatePercent);
    expect(snapshot.ticker.openInterest, ticker.openInterest);
    expect(snapshot.ticker.openInterestValue, ticker.openInterestValue);
    expect(snapshot.ticker.orderBookUpdatedAt, ticker.orderBookUpdatedAt);
    expect(snapshot.ticker.sourceUpdatedAt, ticker.sourceUpdatedAt);
    expect(snapshot.ticker.fundingUpdatedAt, ticker.fundingUpdatedAt);
    expect(snapshot.tradingRules, same(_rules));
    expect(snapshot.dataIntegrity.level, MarketDataQualityLevel.high);
    expect(snapshot.dataIntegrity.hasCriticalIssue, isFalse);
  });

  test('missing instrument rules are a critical LOW data-quality veto', () {
    final DateTime now = DateTime.utc(2026, 8, 28, 12);
    final MarketDataIntegrity result = MarketDataIntegrityEngine.assess(
      ticker: TickerStats(
        price: 100.0,
        change24hPercent: 0.0,
        turnover24h: 1.0,
        bidPrice: 99.99,
        askPrice: 100.01,
        sourceUpdatedAt: now,
        orderBookUpdatedAt: now,
        fundingUpdatedAt: now,
      ),
      candlesByTimeframe: <Duration, List<Candle>>{
        const Duration(minutes: 1): _candles(const Duration(minutes: 1), now),
      },
      tradingRules: null,
      checkedAt: now,
    );

    expect(result.level, MarketDataQualityLevel.low);
    expect(result.hasCriticalIssue, isTrue);
    expect(result.issues, contains('INSTRUMENT_RULES_UNAVAILABLE'));
  });

  test('stale bid and ask are rejected for a live market entry', () {
    final DateTime now = DateTime.utc(2026, 8, 28, 12);
    final MarketDataIntegrity result = MarketDataIntegrityEngine.assess(
      ticker: TickerStats(
        price: 100.0,
        change24hPercent: 0.0,
        turnover24h: 1.0,
        bidPrice: 99.99,
        askPrice: 100.01,
        sourceUpdatedAt: now,
        orderBookUpdatedAt: now.subtract(const Duration(minutes: 2)),
        fundingUpdatedAt: now,
      ),
      candlesByTimeframe: <Duration, List<Candle>>{
        const Duration(minutes: 1): _candles(const Duration(minutes: 1), now),
      },
      tradingRules: _rules,
      checkedAt: now,
    );

    expect(result.level, MarketDataQualityLevel.low);
    expect(result.hasFreshBidAsk, isFalse);
    expect(result.issues, contains('BID_ASK_STALE'));
  });
}

List<Candle> _candles(Duration timeframe, DateTime observedAt) {
  final DateTime first = observedAt.subtract(timeframe * 200);
  return List<Candle>.generate(200, (int index) {
    final double open = 99.0 + index * 0.01;
    final double close = open + 0.005;
    return Candle(
      time: first.add(timeframe * index),
      open: open,
      high: close + 0.01,
      low: open - 0.01,
      close: close,
      volume: 1000.0 + index,
    );
  }, growable: false);
}

const InstrumentTradingRules _rules = InstrumentTradingRules(
  symbol: 'BTCUSDT',
  venue: ExchangeVenue.bybit,
  tickSize: 0.1,
  quantityStep: 0.001,
  minOrderQuantity: 0.001,
  minNotional: 5.0,
  maxLeverage: 100.0,
  leverageStep: 0.01,
);
