import 'package:crypto_radar/engines/adaptive_grid_engine.dart';
import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns analysis-only grid assessment inside a structural range', () {
    final MarketSnapshot market = _market();
    final AdaptiveGridAssessment result = AdaptiveGridEngine.evaluate(
      market: market,
      maximumLeverage: 10,
    );

    expect(result.hasRange, isTrue);
    expect(result.rangeLow, 95);
    expect(result.rangeHigh, 105);
    expect(result.rangeQuality, greaterThan(0));
    expect(result.stepPercent, greaterThan(0));
    expect(result.levels, inInclusiveRange(4, 24));
    expect(result.recommendedLeverage, lessThanOrEqualTo(10));
  });

  test('critical market data turns grid off', () {
    final MarketSnapshot market = _market(critical: true);
    final AdaptiveGridAssessment result = AdaptiveGridEngine.evaluate(
      market: market,
    );

    expect(result.state, AdaptiveGridState.off);
    expect(result.mode, AdaptiveGridMode.off);
    expect(result.breakoutRisk, 100);
  });
}

MarketSnapshot _market({bool critical = false}) {
  final DateTime now = DateTime.utc(2026, 9, 28, 12);
  final TimeframeAnalysis frame = _frame(now);
  return MarketSnapshot(
    symbol: 'FARTCOINUSDT',
    ticker: TickerStats(
      price: 100,
      change24hPercent: 1,
      turnover24h: 1000000,
      bidPrice: 99.95,
      askPrice: 100.05,
      sourceUpdatedAt: now,
    ),
    oneMinute: frame,
    fiveMinutes: frame,
    fifteenMinutes: frame,
    oneHour: frame,
    confirmations: const <ConfirmationItem>[],
    longScore: 50,
    shortScore: 50,
    signal: 'ЖДАТЬ',
    strength: 60,
    magnetPrice: 105,
    magnetLabel: 'Range high',
    potentialPercent: 5,
    expectedLow: 95,
    expectedHigh: 105,
    tradePlan: const TradePlan(
      bias: Bias.neutral,
      entryLow: 98,
      entryHigh: 102,
      stop: 94,
      tp1: 104,
      tp2: 105,
      leverage: 1,
      reason: 'test',
    ),
    updatedAt: now,
    dataIntegrity: MarketDataIntegrity(
      level: critical
          ? MarketDataQualityLevel.low
          : MarketDataQualityLevel.high,
      issues: critical ? const <String>['TEST_CRITICAL'] : const <String>[],
      hasCriticalIssue: critical,
      hasFreshBidAsk: true,
      hasInstrumentRules: true,
      minimumCandleCount: 200,
      checkedAt: now,
    ),
  );
}

TimeframeAnalysis _frame(DateTime now) => TimeframeAnalysis(
  name: '15m',
  candles: <Candle>[
    Candle(
      time: now.subtract(const Duration(minutes: 15)),
      open: 99,
      high: 101,
      low: 98,
      close: 100,
      volume: 1000,
    ),
  ],
  price: 100,
  ema20: 100,
  ema50: 100,
  ema200: 100,
  rsi: 50,
  macd: const MacdResult(macd: 0, signal: 0, histogram: 0),
  relativeVolume: 1,
  atr: 1,
  trend: Bias.neutral,
  ichimoku: const IchimokuResult(
    conversion: 100,
    base: 100,
    spanA: 100,
    spanB: 100,
    bias: Bias.neutral,
  ),
  fibonacci: const FibonacciResult(
    swingLow: 95,
    swingHigh: 105,
    nearestLevel: 100,
    ratio: 0.5,
  ),
  structure: const StructureResult(
    highLabel: 'HH',
    lowLabel: 'HL',
    bias: Bias.neutral,
    bos: Bias.neutral,
    choch: Bias.neutral,
    lastSwingHigh: 105,
    lastSwingLow: 95,
  ),
  support: 95,
  resistance: 105,
  liquidity: const LiquidityResult(
    above: 105,
    below: 95,
    sweepAbove: false,
    sweepBelow: false,
  ),
  fairValueGaps: const <PriceZone>[],
  orderBlocks: const <PriceZone>[],
);
