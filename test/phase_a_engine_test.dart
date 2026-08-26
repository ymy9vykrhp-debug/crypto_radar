import 'package:crypto_radar/engines/entry_engine.dart';
import 'package:crypto_radar/engines/false_breakout_engine.dart';
import 'package:crypto_radar/engines/phase_a_engine.dart';
import 'package:crypto_radar/engines/stop_engine.dart';
import 'package:crypto_radar/engines/trade_tracker.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime start = DateTime.utc(2026, 8, 26, 12);

  test('one level pierce is only FALSE_BREAKOUT_POSSIBLE', () {
    final List<Candle> candles = <Candle>[
      _candle(start, 99.0, 99.6, 98.8, 99.3),
      _candle(start.add(const Duration(minutes: 5)), 99.3, 99.7, 99.0, 99.4),
      _candle(start.add(const Duration(minutes: 10)), 99.2, 101.0, 98.9, 99.4),
    ];
    final FalseBreakoutAnalysis result = FalseBreakoutEngine.analyze(
      analysis: _analysis(candles: candles, trend: Bias.bearish),
      scenarioDirection: Bias.bearish,
    );

    expect(result.state, FalseBreakoutState.possible);
    expect(result.pierced, isTrue);
    expect(result.liquiditySweepConfirmed, isFalse);
  });

  test('reclaim plus following BOS confirms false breakout and sweep', () {
    final List<Candle> candles = <Candle>[
      _candle(start, 99.0, 99.6, 98.8, 99.3),
      _candle(start.add(const Duration(minutes: 5)), 99.3, 99.7, 99.0, 99.4),
      _candle(
        start.add(const Duration(minutes: 10)),
        99.2,
        101.0,
        98.8,
        99.4,
        volume: 1600.0,
      ),
      _candle(start.add(const Duration(minutes: 15)), 99.4, 99.5, 98.0, 98.4),
    ];
    final FalseBreakoutAnalysis result = FalseBreakoutEngine.analyze(
      analysis: _analysis(
        candles: candles,
        trend: Bias.bearish,
        bos: Bias.bearish,
      ),
      scenarioDirection: Bias.bearish,
    );

    expect(result.state, FalseBreakoutState.confirmed);
    expect(result.closedBackInside, isTrue);
    expect(result.reclaimed, isTrue);
    expect(result.structureConfirmed, isTrue);
    expect(result.liquiditySweepConfirmed, isTrue);
  });

  test('correction end and BOS move setup to ENTRY_CONFIRMED', () {
    final MarketSnapshot market = _market(
      start,
      fiveTrend: Bias.bearish,
      fiveBos: Bias.bearish,
    );
    final RadarSignal signal = _signal(
      start,
      direction: SignalDirection.short,
      stage: SignalStage.waitForTrigger,
    );
    final EntryAssessment result = EntryEngine.assess(
      signal: signal,
      market: market,
      falseBreakout: FalseBreakoutAnalysis.none,
      stopIsSafe: true,
      variant: EntryVariant.correctionEnd,
    );

    expect(result.stage, SignalStage.entryConfirmed);
    expect(result.localStructureConfirmed, isTrue);
    expect(result.bosConfirmed, isTrue);
    expect(result.confirmationCandle, isTrue);
  });

  test('Stop Engine adds dynamic buffer beyond structural invalidation', () {
    final RadarSignal signal = _signal(
      start,
      direction: SignalDirection.short,
      tp1: 96.0,
    );
    final StopPlan result = StopEngine.build(
      signal: signal,
      analysis: _analysis(
        candles: _trendCandles(start),
        trend: Bias.bearish,
        bos: Bias.bearish,
      ),
      falseBreakout: FalseBreakoutAnalysis.none,
    );

    expect(result.invalidationPrice, greaterThan(signal.entryPrice));
    expect(result.buffer, greaterThan(0.0));
    expect(result.stopPrice, greaterThan(result.invalidationPrice));
    expect(result.bufferAtr, greaterThan(0.0));
    expect(result.reasonCodes, contains('DYNAMIC_STOP_BUFFER'));
  });

  test('safe stop too far blocks the setup instead of widening risk', () {
    final RadarSignal signal = _signal(
      start,
      direction: SignalDirection.short,
      tp1: 100.2,
    );
    final StopPlan result = StopEngine.build(
      signal: signal,
      analysis: _analysis(candles: _trendCandles(start), trend: Bias.bearish),
      falseBreakout: FalseBreakoutAnalysis.none,
    );

    expect(result.safe, isFalse);
    expect(result.reasonCodes, contains('RISK_REWARD_POOR'));
  });

  test('tracks overshoot, reclaim and STOP_THEN_TARGET after stop', () {
    const TradeTracker tracker = TradeTracker();
    RadarSignal signal = _signal(
      start,
      direction: SignalDirection.long,
      stage: SignalStage.inPosition,
      status: SignalStatus.inPosition,
      entryTime: start,
      stop: 94.5,
      tp1: 105.0,
      tp2: 110.0,
    ).copyWith(invalidationPrice: 95.0, stopBuffer: 0.5, stopBufferAtr: 0.5);
    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 100.0, 101.0, 94.0, 96.0),
    );

    expect(signal.status, SignalStatus.stopped);
    expect(signal.overshootPoints, closeTo(1.0, 0.0001));
    expect(signal.reclaimedLevel, isTrue);
    expect(signal.postStopTp1, isFalse);

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 10)), 96.0, 106.0, 95.5, 105.5),
    );
    expect(signal.status, SignalStatus.stopped);
    expect(signal.postStopTp1, isTrue);
    expect(signal.postStopTp2, isFalse);
    expect(signal.reasonCodes, contains('STOP_THEN_TARGET'));
  });

  test('aggressive entry can enter while confirmed setup still waits', () {
    const TradeTracker tracker = TradeTracker();
    final Candle next = _candle(
      start.add(const Duration(minutes: 5)),
      102.0,
      102.8,
      101.0,
      102.5,
    );
    final RadarSignal aggressive = tracker.consume(
      _signal(
        start,
        direction: SignalDirection.long,
        stage: SignalStage.entryConfirmed,
        entryVariant: EntryVariant.immediate,
      ).copyWith(entryConfirmedTime: start),
      next,
    );
    final RadarSignal confirmed = tracker.consume(
      _signal(
        start,
        direction: SignalDirection.long,
        stage: SignalStage.waitForTrigger,
        entryVariant: EntryVariant.bosConfirmation,
      ),
      next,
    );

    expect(aggressive.status, SignalStatus.inPosition);
    expect(confirmed.status, SignalStatus.waitingEntry);
  });

  test('confirmation close cannot enter using an earlier candle', () {
    const TradeTracker tracker = TradeTracker();
    final DateTime confirmedAt = start.add(const Duration(minutes: 10));
    RadarSignal signal = _signal(
      start,
      direction: SignalDirection.long,
      stage: SignalStage.entryConfirmed,
      entryVariant: EntryVariant.bosConfirmation,
    ).copyWith(entryConfirmedTime: confirmedAt);

    signal = tracker.consume(
      signal,
      _candle(start.add(const Duration(minutes: 5)), 100.0, 101.0, 99.0, 100.5),
    );
    expect(signal.status, SignalStatus.waitingEntry);

    signal = tracker.consume(
      signal,
      _candle(confirmedAt, 100.0, 101.0, 99.0, 100.5),
    );
    expect(signal.status, SignalStatus.inPosition);
  });

  test('execution profile identity is deterministic for signal dedup', () {
    final MarketSnapshot market = _market(
      start,
      fiveTrend: Bias.bearish,
      fiveBos: Bias.bearish,
    );
    final RadarSignal source = _signal(start, direction: SignalDirection.short);
    final RadarSignal first = PhaseAEngine.prepare(
      market: market,
      signal: source,
      profileId: 'bos_atr',
    );
    final RadarSignal second = PhaseAEngine.prepare(
      market: market,
      signal: source,
      profileId: 'bos_atr',
    );

    expect(first.id, second.id);
    expect(first.id.endsWith(':bos_atr'), isTrue);
  });
}

RadarSignal _signal(
  DateTime time, {
  required SignalDirection direction,
  SignalStage stage = SignalStage.setupFound,
  SignalStatus status = SignalStatus.waitingEntry,
  EntryVariant entryVariant = EntryVariant.bosConfirmation,
  DateTime? entryTime,
  double? stop,
  double? tp1,
  double? tp2,
}) {
  return RadarSignal(
    id: 'BTCUSDT:${direction.name}:${time.millisecondsSinceEpoch}',
    symbol: 'BTCUSDT',
    time: time,
    direction: direction,
    referencePrice: 100.0,
    entryLow: 99.5,
    entryHigh: 100.5,
    stop: stop ?? (direction == SignalDirection.long ? 98.0 : 102.0),
    tp1: tp1 ?? (direction == SignalDirection.long ? 103.0 : 97.0),
    tp2: tp2 ?? (direction == SignalDirection.long ? 106.0 : 94.0),
    score: 85,
    trend5m: direction.bias,
    trend15m: direction.bias,
    trend1h: direction.bias,
    rsi: direction == SignalDirection.long ? 58.0 : 42.0,
    macd: direction == SignalDirection.long ? 1.0 : -1.0,
    ema20: 100.0,
    ema50: 101.0,
    ema200: 102.0,
    relativeVolume: 1.2,
    rvolBias: direction.bias,
    fvgBias: direction.bias,
    orderBlockBias: direction.bias,
    liquidityBias: direction.bias,
    bos: direction.bias,
    choch: Bias.neutral,
    stage: stage,
    status: status,
    entryVariant: entryVariant,
    entryMode: entryVariant.mode,
    entryTime: entryTime,
    lastTrackedCandleTime: time,
  );
}

MarketSnapshot _market(
  DateTime start, {
  required Bias fiveTrend,
  required Bias fiveBos,
}) {
  final List<Candle> candles = _trendCandles(start);
  final TimeframeAnalysis one = _analysis(
    candles: candles,
    trend: fiveTrend,
    bos: fiveBos,
    name: '1м',
  );
  final TimeframeAnalysis five = _analysis(
    candles: candles,
    trend: fiveTrend,
    bos: fiveBos,
    name: '5м',
  );
  final TimeframeAnalysis fifteen = _analysis(
    candles: candles,
    trend: fiveTrend,
    bos: fiveBos,
    name: '15м',
  );
  return MarketSnapshot(
    symbol: 'BTCUSDT',
    ticker: const TickerStats(
      price: 100.0,
      change24hPercent: 0.0,
      turnover24h: 1000000.0,
    ),
    oneMinute: one,
    fiveMinutes: five,
    fifteenMinutes: fifteen,
    oneHour: fifteen,
    confirmations: const <ConfirmationItem>[],
    longScore: fiveTrend == Bias.bullish ? 12 : 3,
    shortScore: fiveTrend == Bias.bearish ? 12 : 3,
    signal: fiveTrend == Bias.bullish ? 'ПОКУПКА' : 'ПРОДАЖА',
    strength: 88,
    magnetPrice: fiveTrend == Bias.bullish ? 105.0 : 95.0,
    magnetLabel: 'Liquidity',
    potentialPercent: 5.0,
    expectedLow: 98.0,
    expectedHigh: 102.0,
    tradePlan: TradePlan(
      bias: fiveTrend,
      entryLow: 99.5,
      entryHigh: 100.5,
      stop: fiveTrend == Bias.bullish ? 98.0 : 102.0,
      tp1: fiveTrend == Bias.bullish ? 103.0 : 97.0,
      tp2: fiveTrend == Bias.bullish ? 106.0 : 94.0,
      leverage: 5,
      reason: 'test',
    ),
    updatedAt: start,
  );
}

TimeframeAnalysis _analysis({
  required List<Candle> candles,
  required Bias trend,
  Bias bos = Bias.neutral,
  String name = '5м',
}) {
  return TimeframeAnalysis(
    name: name,
    candles: candles,
    price: candles.last.close,
    ema20: trend == Bias.bearish ? 99.0 : 103.0,
    ema50: 101.0,
    ema200: trend == Bias.bearish ? 103.0 : 99.0,
    rsi: trend == Bias.bearish ? 42.0 : 58.0,
    macd: MacdResult(
      macd: trend == Bias.bearish ? -1.0 : 1.0,
      signal: 0.0,
      histogram: trend == Bias.bearish ? -1.0 : 1.0,
    ),
    relativeVolume: 1.2,
    atr: 1.0,
    trend: trend,
    ichimoku: IchimokuResult(
      conversion: 100.0,
      base: 100.0,
      spanA: 100.0,
      spanB: 100.0,
      bias: trend,
    ),
    fibonacci: const FibonacciResult(
      swingLow: 95.0,
      swingHigh: 105.0,
      nearestLevel: 100.0,
      ratio: 0.5,
    ),
    structure: StructureResult(
      highLabel: trend == Bias.bearish ? 'LH' : 'HH',
      lowLabel: trend == Bias.bullish ? 'HL' : 'LL',
      bias: trend,
      bos: bos,
      choch: Bias.neutral,
      lastSwingHigh: 101.0,
      lastSwingLow: 99.0,
    ),
    support: 99.0,
    resistance: 100.0,
    liquidity: const LiquidityResult(
      above: 100.0,
      below: 99.0,
      sweepAbove: false,
      sweepBelow: false,
    ),
    fairValueGaps: const <PriceZone>[],
    orderBlocks: const <PriceZone>[],
  );
}

List<Candle> _trendCandles(DateTime start) {
  return <Candle>[
    _candle(start, 101.0, 101.2, 100.0, 100.5),
    _candle(start.add(const Duration(minutes: 5)), 100.5, 100.7, 99.2, 99.5),
  ];
}

Candle _candle(
  DateTime time,
  double open,
  double high,
  double low,
  double close, {
  double volume = 1000.0,
}) {
  return Candle(
    time: time,
    open: open,
    high: high,
    low: low,
    close: close,
    volume: volume,
  );
}
