import 'package:crypto_radar/engines/decision_engine.dart';
import 'package:crypto_radar/engines/explanation_engine.dart';
import 'package:crypto_radar/engines/help_engine.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/screens/why_now_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds stable reasons and warnings from analyzed snapshot values', () {
    final DecisionSnapshot decision = DecisionEngine.build(_market());

    expect(decision.decision, DecisionAction.long);
    expect(decision.entryDecision, EntryDecision.enterNow);
    expect(
      decision.reasonCodes,
      containsAll(<ReasonCode>[
        ReasonCode.bullish15mStructure,
        ReasonCode.bullish1hStructure,
        ReasonCode.bosConfirmed,
        ReasonCode.entryAtGoodZone,
      ]),
    );
    expect(
      decision.warningCodes,
      containsAll(<ReasonCode>[
        ReasonCode.bearish5mCorrection,
        ReasonCode.correctionNotFinished,
        ReasonCode.rvolLow,
      ]),
    );
    expect(decision.persistedReasonCodes, contains('BULLISH_15M_STRUCTURE'));
    expect(ReasonCodeWire.fromCode('BOS_CONFIRMED'), ReasonCode.bosConfirmed);
  });

  test('WAIT is explained as a decision with opposing factors', () {
    final DecisionSnapshot decision = DecisionEngine.build(
      _market(signal: 'ЖДАТЬ'),
    );
    final DecisionExplanation explanation = ExplanationEngine.explain(decision);

    expect(decision.decision, DecisionAction.wait);
    expect(decision.warningCodes, contains(ReasonCode.noTradeConditions));
    expect(explanation.whyDecision, contains('осознанный результат'));
    expect(explanation.opposing, isNotEmpty);
    expect(explanation.whatChangesMind, hasLength(2));
  });

  test('help engine is a read-only projection of one decision snapshot', () {
    final DecisionSnapshot decision = DecisionEngine.build(_market());
    final help = HelpEngine.contextual(decision);

    expect(identical(help.decision, decision), isTrue);
    expect(help.summary, contains('SignalEngine'));
    expect(help.supporting, isNotEmpty);
    expect(help.nextSteps, isNotEmpty);
    expect(HelpEngine.articles.map((article) => article.id), contains('risk'));
  });

  testWidgets('WHY screen shows support and counterarguments', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: WhyNowScreen(marketSnapshot: _market())),
      ),
    );

    expect(find.text('ПОЧЕМУ СЕЙЧАС?'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Подтверждает'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Подтверждает'), findsOneWidget);
    expect(find.text('Против / риски'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Что изменит решение радара'),
      400.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Что изменит решение радара'), findsOneWidget);
  });
}

MarketSnapshot _market({String signal = 'ПОКУПКА'}) {
  final TimeframeAnalysis one = _timeframe('1м', Bias.bullish);
  final TimeframeAnalysis five = _timeframe('5м', Bias.bearish);
  final TimeframeAnalysis fifteen = _timeframe(
    '15м',
    Bias.bullish,
    relativeVolume: 0.6,
    bos: Bias.bullish,
  );
  final TimeframeAnalysis hour = _timeframe('1ч', Bias.bullish);
  return MarketSnapshot(
    symbol: 'BTCUSDT',
    ticker: const TickerStats(
      price: 100.0,
      change24hPercent: 1.0,
      turnover24h: 1000000.0,
    ),
    oneMinute: one,
    fiveMinutes: five,
    fifteenMinutes: fifteen,
    oneHour: hour,
    confirmations: const <ConfirmationItem>[],
    longScore: 12,
    shortScore: 4,
    signal: signal,
    strength: 90,
    magnetPrice: 108.0,
    magnetLabel: 'Сопротивление',
    potentialPercent: 8.0,
    expectedLow: 98.0,
    expectedHigh: 102.0,
    tradePlan: const TradePlan(
      bias: Bias.bullish,
      entryLow: 99.0,
      entryHigh: 101.0,
      stop: 97.0,
      tp1: 104.0,
      tp2: 108.0,
      leverage: 5,
      reason: 'Тестовый сценарий',
    ),
    updatedAt: DateTime.utc(2026, 8, 25, 12),
  );
}

TimeframeAnalysis _timeframe(
  String name,
  Bias trend, {
  double relativeVolume = 1.3,
  Bias bos = Bias.neutral,
  Bias choch = Bias.neutral,
}) {
  return TimeframeAnalysis(
    name: name,
    candles: _candles(),
    price: 100.0,
    ema20: trend == Bias.bearish ? 99.0 : 103.0,
    ema50: 101.0,
    ema200: trend == Bias.bearish ? 103.0 : 99.0,
    rsi: 58.0,
    macd: const MacdResult(macd: 1.0, signal: 0.5, histogram: 0.5),
    relativeVolume: relativeVolume,
    atr: 1.0,
    trend: trend,
    ichimoku: IchimokuResult(
      conversion: 101.0,
      base: 100.0,
      spanA: 100.5,
      spanB: 99.5,
      bias: trend,
    ),
    fibonacci: const FibonacciResult(
      swingLow: 90.0,
      swingHigh: 110.0,
      nearestLevel: 100.0,
      ratio: 0.5,
    ),
    structure: StructureResult(
      highLabel: trend == Bias.bearish ? 'LH' : 'HH',
      lowLabel: trend == Bias.bearish ? 'LL' : 'HL',
      bias: trend,
      bos: bos,
      choch: choch,
      lastSwingHigh: 110.0,
      lastSwingLow: 90.0,
    ),
    support: 95.0,
    resistance: 110.0,
    liquidity: const LiquidityResult(
      above: 109.0,
      below: 94.0,
      sweepAbove: false,
      sweepBelow: true,
    ),
    fairValueGaps: <PriceZone>[
      PriceZone(
        lower: 98.0,
        upper: 99.0,
        bias: trend,
        kind: ZoneKind.fairValueGap,
        timeframe: name,
      ),
    ],
    orderBlocks: <PriceZone>[
      PriceZone(
        lower: 97.0,
        upper: 99.0,
        bias: trend,
        kind: ZoneKind.orderBlock,
        timeframe: name,
      ),
    ],
  );
}

List<Candle> _candles() {
  final DateTime start = DateTime.utc(2026, 8, 24);
  return List<Candle>.generate(200, (int index) {
    return Candle(
      time: start.add(Duration(minutes: index)),
      open: 99.5,
      high: 101.0,
      low: 99.0,
      close: 100.0,
      volume: 1000.0,
    );
  }, growable: false);
}
