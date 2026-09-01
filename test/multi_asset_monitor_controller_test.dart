import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/services/multi_asset_monitor_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks unique symbols sequentially and isolates one failure', () async {
    final List<String> events = <String>[];
    final MultiAssetMonitorController controller = MultiAssetMonitorController(
      snapshotLoader: (String symbol) async {
        events.add('load:$symbol');
        if (symbol == 'BADUSDT') throw Exception('offline');
        return _market(symbol);
      },
      snapshotProcessor: (MarketSnapshot snapshot) async {
        events.add('process:${snapshot.symbol}');
      },
      clock: () => DateTime.utc(2026, 8, 31, 12),
    );

    final Map<String, MarketSnapshot> result = await controller.refresh(
      <String>[' btc/usdt ', 'BTCUSDT', 'BADUSDT', 'FARTCOINUSDT'],
    );

    expect(result.keys, <String>['BTCUSDT', 'FARTCOINUSDT']);
    expect(events, <String>[
      'load:BTCUSDT',
      'process:BTCUSDT',
      'load:BADUSDT',
      'load:FARTCOINUSDT',
      'process:FARTCOINUSDT',
    ]);
    expect(controller.statusFor('BTCUSDT').state, AssetMonitorState.ready);
    expect(controller.statusFor('BADUSDT').state, AssetMonitorState.error);
    expect(controller.statusFor('BADUSDT').error, contains('offline'));
    expect(controller.statusFor('FARTCOINUSDT').state, AssetMonitorState.ready);
    expect(controller.completedCycles, 1);
    expect(controller.running, isFalse);
  });
}

MarketSnapshot _market(String symbol) {
  final TimeframeAnalysis frame = _frame();
  return MarketSnapshot(
    symbol: symbol,
    ticker: const TickerStats(
      price: 100,
      change24hPercent: 1,
      turnover24h: 1000000,
    ),
    oneMinute: frame,
    fiveMinutes: frame,
    fifteenMinutes: frame,
    oneHour: frame,
    confirmations: const <ConfirmationItem>[],
    longScore: 8,
    shortScore: 2,
    signal: 'ПОКУПКА',
    strength: 80,
    magnetPrice: 105,
    magnetLabel: 'Resistance',
    potentialPercent: 5,
    expectedLow: 98,
    expectedHigh: 105,
    tradePlan: const TradePlan(
      bias: Bias.bullish,
      entryLow: 99,
      entryHigh: 101,
      stop: 97,
      tp1: 104,
      tp2: 108,
      leverage: 4,
      reason: 'test',
    ),
    updatedAt: DateTime.utc(2026, 8, 31, 12),
  );
}

TimeframeAnalysis _frame() => TimeframeAnalysis(
  name: '15m',
  candles: <Candle>[
    Candle(
      time: DateTime.utc(2026, 8, 31, 11, 45),
      open: 99,
      high: 101,
      low: 98,
      close: 100,
      volume: 1000,
    ),
  ],
  price: 100,
  ema20: 101,
  ema50: 99,
  ema200: 95,
  rsi: 55,
  macd: const MacdResult(macd: 1, signal: 0.5, histogram: 0.5),
  relativeVolume: 1.4,
  atr: 1,
  trend: Bias.bullish,
  ichimoku: const IchimokuResult(
    conversion: 101,
    base: 100,
    spanA: 101,
    spanB: 99,
    bias: Bias.bullish,
  ),
  fibonacci: const FibonacciResult(
    swingLow: 90,
    swingHigh: 110,
    nearestLevel: 100,
    ratio: 0.5,
  ),
  structure: const StructureResult(
    highLabel: 'HH',
    lowLabel: 'HL',
    bias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    lastSwingHigh: 110,
    lastSwingLow: 95,
  ),
  support: 98,
  resistance: 108,
  liquidity: const LiquidityResult(
    above: 108,
    below: 97,
    sweepAbove: false,
    sweepBelow: true,
  ),
  fairValueGaps: const <PriceZone>[],
  orderBlocks: const <PriceZone>[],
);
