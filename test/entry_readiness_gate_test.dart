import 'package:crypto_radar/engines/entry_readiness_gate.dart';
import 'package:crypto_radar/engines/decision_readiness_engine.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/first_move_models.dart';
import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EntryReadinessGate', () {
    test('returns ENTRY READY only when every required veto passes', () {
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(),
        signalId: 'signal-1',
      );

      expect(result.entryReady, isTrue);
      expect(result.status, EntryReadinessStatus.entryReady);
      expect(result.nextAction, EntryNextAction.enter);
      expect(result.signalId, 'signal-1');
      expect(result.reasons, isEmpty);
    });

    test('stale market data suspends permission, not strategy validity', () {
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(freshData: false),
        decision: _decision(),
        signalId: 'signal-1',
      );

      expect(result.entryReady, isFalse);
      expect(result.status, EntryReadinessStatus.suspended);
      expect(result.nextAction, EntryNextAction.waitForData);
      expect(result.reasons, contains(EntryReadinessReason.staleBidAsk));
    });

    test('price outside zone is almost ready and waits for zone', () {
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(price: 102),
        signalId: 'signal-1',
      );

      expect(result.status, EntryReadinessStatus.almostReady);
      expect(result.nextAction, EntryNextAction.waitForZone);
      expect(
        result.reasonCodes,
        contains(EntryReadinessReason.priceOutsideEntryZone.code),
      );
    });

    test('explicit NO TRADE invalidates the entry', () {
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(executionAction: 'NO TRADE: invalidated'),
        signalId: 'signal-1',
      );

      expect(result.status, EntryReadinessStatus.invalidated);
      expect(result.nextAction, EntryNextAction.skip);
      expect(result.hardBlocked, isTrue);
    });

    test('shared analysis keeps the tracked learned-profile signal id', () {
      final RadarSignal tracked = _trackedSignal();
      final DecisionReadinessAnalysis analysis =
          DecisionReadinessEngine.evaluate(
            market: _market(),
            trackedSignals: <RadarSignal>[tracked],
          );

      expect(analysis.executionSignal?.id, tracked.id);
      expect(analysis.readiness.signalId, tracked.id);
      expect(analysis.decision.signalStage, SignalStage.entryConfirmed);
    });

    test('strict gate accepts a structural plan with historical edge', () {
      final RadarSignal signal = _strictSignal();
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(stop: 98.2, tp1: 108, tp2: 110),
        signal: signal,
        signalId: signal.id,
      );

      expect(result.entryReady, isTrue);
      expect(result.targetMovePercent, greaterThanOrEqualTo(1.0));
      expect(result.netRiskReward, greaterThanOrEqualTo(1.8));
      expect(result.historicalSamples, 80);
    });

    test('strict gate rejects a target below one percent', () {
      final RadarSignal signal = _strictSignal().copyWith(
        tp1: 100.8,
        tp2: 101.0,
      );
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(stop: 98.2, tp1: 100.8, tp2: 101.0),
        signal: signal,
      );

      expect(result.entryReady, isFalse);
      expect(result.reasonCodes, contains('TARGET_TOO_CLOSE'));
    });

    test('strict gate rejects missing structural stop', () {
      final RadarSignal signal = _strictSignal().copyWith(
        structuralStop: 0,
        invalidationPrice: 0,
      );
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(stop: 98.2, tp1: 108, tp2: 110),
        signal: signal,
      );

      expect(result.entryReady, isFalse);
      expect(result.reasonCodes, contains('STRUCTURAL_STOP_MISSING'));
    });

    test('strict gate fails closed on insufficient historical samples', () {
      final RadarSignal signal = _strictSignal().copyWith(
        firstMove: const FirstMoveRecord(
          tradingMode: 'INTRADAY',
          marketRegime: 'TREND_UP',
          volatilityRegime: 'NORMAL',
          historicalSamples: 49,
          probability030: 99,
        ),
      );
      final EntryReadinessResult result = EntryReadinessGate.evaluate(
        market: _market(),
        decision: _decision(stop: 98.2, tp1: 108, tp2: 110),
        signal: signal,
      );

      expect(result.entryReady, isFalse);
      expect(result.reasonCodes, contains('HISTORICAL_SAMPLES_LOW'));
    });
  });
}

RadarSignal _strictSignal() => RadarSignal(
  id: 'strict-ready',
  symbol: 'BTCUSDT',
  time: DateTime.utc(2026, 8, 31, 11, 55),
  direction: SignalDirection.long,
  referencePrice: 100,
  entryLow: 99,
  entryHigh: 101,
  stop: 98.2,
  tp1: 108,
  tp2: 110,
  score: 90,
  trend5m: Bias.bullish,
  trend15m: Bias.bullish,
  trend1h: Bias.bullish,
  rsi: 55,
  macd: 1,
  ema20: 101,
  ema50: 99,
  ema200: 95,
  relativeVolume: 1.4,
  rvolBias: Bias.bullish,
  fvgBias: Bias.bullish,
  orderBlockBias: Bias.bullish,
  liquidityBias: Bias.bullish,
  bos: Bias.bullish,
  choch: Bias.neutral,
  stage: SignalStage.entryConfirmed,
  entryConfirmedTime: DateTime.utc(2026, 8, 31, 12),
  structuralStop: 98.5,
  invalidationPrice: 98.5,
  stopBuffer: 0.3,
  stopBufferAtr: 0.3,
  qualities: const SignalQualityScores(
    direction: 90,
    entry: 85,
    location: 85,
    liquidity: 80,
    stop: 80,
    risk: 80,
  ),
  liquiditySweepConfirmed: true,
  firstMove: const FirstMoveRecord(
    tradingMode: 'INTRADAY',
    marketRegime: 'TREND_UP',
    volatilityRegime: 'NORMAL',
    historicalSamples: 80,
    historicalConfidence: HistoricalConfidence.low,
    probability020: 86,
    probability030: 78,
    probability050: 71,
    probability075: 64,
    probability100: 58,
    probabilityStopFirst: 22,
  ),
);

RadarSignal _trackedSignal() => RadarSignal(
  id: 'BTCUSDT:standard:long:1:learned_best',
  symbol: 'BTCUSDT',
  time: DateTime.utc(2026, 8, 31, 11),
  direction: SignalDirection.long,
  referencePrice: 100,
  entryLow: 99,
  entryHigh: 101,
  stop: 97,
  tp1: 104,
  tp2: 108,
  score: 90,
  trend5m: Bias.bullish,
  trend15m: Bias.bullish,
  trend1h: Bias.bullish,
  rsi: 55,
  macd: 1,
  ema20: 101,
  ema50: 99,
  ema200: 95,
  relativeVolume: 1.4,
  rvolBias: Bias.bullish,
  fvgBias: Bias.bullish,
  orderBlockBias: Bias.bullish,
  liquidityBias: Bias.bullish,
  bos: Bias.bullish,
  choch: Bias.neutral,
  stage: SignalStage.entryConfirmed,
  executionProfileId: 'learned_best',
  entryConfirmedTime: DateTime.utc(2026, 8, 31, 12),
  liquiditySweepConfirmed: true,
  qualities: const SignalQualityScores(
    direction: 90,
    entry: 85,
    location: 85,
    liquidity: 80,
    stop: 80,
    risk: 80,
  ),
);

MarketSnapshot _market({bool freshData = true}) {
  final TimeframeAnalysis frame = _frame();
  return MarketSnapshot(
    symbol: 'BTCUSDT',
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
    longScore: 10,
    shortScore: 2,
    signal: 'ПОКУПКА',
    strength: 90,
    magnetPrice: 105,
    magnetLabel: 'Resistance',
    potentialPercent: 5,
    expectedLow: 98,
    expectedHigh: 104,
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
    tradingRules: const InstrumentTradingRules(
      symbol: 'BTCUSDT',
      venue: ExchangeVenue.bybit,
      tickSize: 0.1,
      quantityStep: 0.001,
      minOrderQuantity: 0.001,
      minNotional: 5,
      maxLeverage: 100,
      leverageStep: 0.01,
    ),
    dataIntegrity: MarketDataIntegrity(
      level: freshData
          ? MarketDataQualityLevel.high
          : MarketDataQualityLevel.low,
      issues: freshData ? const <String>[] : const <String>['BID_ASK_STALE'],
      hasCriticalIssue: false,
      hasFreshBidAsk: freshData,
      hasInstrumentRules: true,
      minimumCandleCount: 200,
      checkedAt: DateTime.utc(2026, 8, 31, 12),
    ),
  );
}

DecisionSnapshot _decision({
  double price = 100,
  String executionAction = 'ENTRY READY',
  double stop = 97,
  double tp1 = 104,
  double tp2 = 108,
}) => DecisionSnapshot(
  symbol: 'BTCUSDT',
  timestamp: DateTime.utc(2026, 8, 31, 12),
  price: price,
  decision: DecisionAction.long,
  signalScore: 90,
  marketRegime: MarketRegimeHint.trendUp,
  selectedStrategy: 'STANDARD_CONFIRMATION_V1',
  entryDecision: EntryDecision.enterNow,
  entryLow: 99,
  entryHigh: 101,
  stop: stop,
  tp1: tp1,
  tp2: tp2,
  riskReward: 2,
  leverage: 4,
  expectedMovePercent: 4,
  priceMagnet: 105,
  timeframeTrends: const <String, Bias>{'5m': Bias.bullish},
  correctionState: 'FINISHED',
  bos: Bias.bullish,
  choch: Bias.neutral,
  support: 98,
  resistance: 108,
  orderBlocks: const <PriceZone>[],
  fairValueGaps: const <PriceZone>[],
  liquidity: const LiquidityResult(
    above: 108,
    below: 97,
    sweepAbove: false,
    sweepBelow: true,
  ),
  atr: 1,
  relativeVolume: 1.4,
  rsi: 55,
  macd: const MacdResult(macd: 1, signal: 0.5, histogram: 0.5),
  ema20: 101,
  ema50: 99,
  ema200: 95,
  dataQuality: DataQuality.high,
  reasonCodes: const <ReasonCode>[],
  warningCodes: const <ReasonCode>[],
  invalidationCodes: const <ReasonCode>[],
  signalStage: SignalStage.entryConfirmed,
  qualityScores: const SignalQualityScores(
    direction: 90,
    entry: 85,
    location: 85,
    liquidity: 80,
    stop: 80,
    risk: 80,
  ),
  liquiditySweepConfirmed: true,
  executionAction: executionAction,
);

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
