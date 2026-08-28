import 'package:crypto_radar/engines/position_calculator.dart';
import 'package:crypto_radar/models/decision_models.dart';
import 'package:crypto_radar/models/execution_models.dart';
import 'package:crypto_radar/models/position_calculator_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Smart Position Calculator', () {
    test('calculates a LONG from margin and keeps stop loss under risk', () {
      final SmartTradePlan plan = _calculate(_input());

      expect(plan.side, SignalDirection.long);
      expect(plan.allocatedMargin, 100);
      expect(plan.margin, lessThanOrEqualTo(plan.allocatedMargin));
      expect(plan.maxLoss, 3);
      expect(plan.leverage, greaterThanOrEqualTo(1));
      expect(plan.leverage, lessThanOrEqualTo(10));
      expect(plan.positionNotional, closeTo(plan.margin * plan.leverage, 1e-8));
      expect(plan.stopOutcome.expectedLoss, lessThanOrEqualTo(3.01));
      expect(
        plan.quantity,
        closeTo(plan.positionNotional / plan.effectiveEntry, 1e-8),
      );
      expect(plan.netRiskReward, lessThan(plan.rawRiskReward));
    });

    test('calculates SHORT price movement and target profit correctly', () {
      final SmartPositionInput input = _input(
        direction: SignalDirection.short,
        decisionAction: DecisionAction.short,
        stop: 100.65,
        tp1: 99.3,
        tp2: 98.3,
        regime: MarketRegimeHint.trendDown,
      );
      final SmartTradePlan plan = _calculate(input);

      expect(plan.side, SignalDirection.short);
      expect(plan.stopOutcome.distancePercent, closeTo(0.65, 1e-8));
      expect(plan.targets.first.movePercent, closeTo(0.7, 1e-8));
      expect(plan.targets.first.grossProfit, greaterThan(0));
      expect(
        plan.stopOutcome.expectedLoss,
        lessThanOrEqualTo(plan.maxLoss + 0.01),
      );
    });

    test('blocks a wide stop when even 1x exceeds the selected risk', () {
      final SmartTradePlan plan = _calculate(_input(stop: 94.0));

      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
      expect(plan.leverage, 0);
      expect(
        plan.reasons.any((String reason) => reason.contains('1x')),
        isTrue,
      );
    });

    test('small 0.3 percent move is skipped when costs consume the edge', () {
      const FeeModel expensive = FeeModel(
        makerFeePercent: 0.20,
        takerFeePercent: 0.20,
        targetSlippagePercent: 0.10,
        stopSlippagePercent: 0.10,
        estimatedSpreadPercent: 0.10,
        safetyBufferPercent: 0.05,
      );
      final SmartTradePlan plan = PositionCalculator.calculate(
        input: _input(targetMovePercent: 0.30),
        feeModel: expensive,
      );

      expect(plan.targetMoveOutcome.movePercent, closeTo(0.30, 1e-8));
      expect(plan.targetMoveOutcome.verdict, TargetVerdict.skip);
      expect(
        plan.targetMoveOutcome.costToGrossPercent,
        greaterThanOrEqualTo(60),
      );
    });

    test('high volatility caps leverage below the mathematical result', () {
      final SmartTradePlan plan = _calculate(
        _input(stop: 99.8, volatilityPercent: 25.0),
      );

      expect(plan.leverageSafety.calculatedLeverage, greaterThan(3));
      expect(plan.leverageSafety.safetyLimit, lessThanOrEqualTo(3));
      expect(plan.leverage, lessThanOrEqualTo(3));
      expect(
        plan.leverageSafety.reasons.any(
          (String reason) => reason.contains('волатильност'),
        ),
        isTrue,
      );
    });

    test('manual Entry Stop and TP changes recalculate all outcomes', () {
      final SmartPositionInput original = _input();
      final SmartTradePlan before = _calculate(original);
      final SmartTradePlan after = _calculate(
        original.copyWith(entry: 101, stop: 100.6, tp1: 102, tp2: 104),
      );

      expect(after.entry, 101);
      expect(after.stop, 100.6);
      expect(after.targets.first.price, 102);
      expect(after.leverage, isNot(before.leverage));
      expect(
        after.stopOutcome.distancePercent,
        isNot(before.stopOutcome.distancePercent),
      );
    });

    test('zero and invalid levels never divide by zero or return NaN', () {
      final SmartTradePlan plan = _calculate(
        _input(entry: 0, stop: 0, tp1: 0, tp2: 0),
      );

      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
      expect(plan.maxNotionalByRisk.isFinite, isTrue);
      expect(plan.effectiveLossPercent.isFinite, isTrue);
      expect(plan.quantity.isFinite, isTrue);
      expect(plan.netRiskReward.isFinite, isTrue);
    });

    test('quantity rounds down to future Bybit qtyStep', () {
      final SmartTradePlan plan = _calculate(
        _input(
          entry: 3,
          stop: 2.98,
          tp1: 3.05,
          tp2: 3.10,
        ).copyWith(quantityStep: 0.1),
      );

      expect(plan.quantity * 10, closeTo((plan.quantity * 10).round(), 1e-8));
      expect(
        plan.positionNotional,
        lessThanOrEqualTo(plan.margin * plan.leverage),
      );
    });

    test('spread changes execution only for an explicit market entry', () {
      final SmartTradePlan planned = _calculate(_input());
      final SmartTradePlan market = _calculate(
        _input().copyWith(
          executionPriceMode: ExecutionPriceMode.market,
          bidPrice: 99.9,
          askPrice: 100.1,
          observedSpreadPercent: 0.20,
        ),
      );

      expect(planned.effectiveEntry, lessThan(market.effectiveEntry));
      expect(market.stopOutcome.costs.spread, greaterThan(0));
      expect(market.maxNotionalByRisk, lessThan(planned.maxNotionalByRisk));
      expect(market.leverage, lessThanOrEqualTo(planned.leverage));
    });

    test('invalid LONG structural stop is blocked instead of moved', () {
      final SmartTradePlan plan = _calculate(_input(stop: 100.2));

      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
      expect(plan.stop, 100.2);
      expect(
        plan.reasons.any((String reason) => reason.contains('ниже Entry')),
        isTrue,
      );
    });

    test('unconfirmed setup remains WAIT while preserving the calculation', () {
      final SmartTradePlan plan = _calculate(
        _input(
          stage: SignalStage.waitForTrigger,
          decisionAction: DecisionAction.long,
        ),
      );

      expect(plan.safetyStatus, TradeSafetyStatus.wait);
      expect(plan.leverage, greaterThan(0));
      expect(plan.positionNotional, greaterThan(0));
    });

    test('entry and exit fees use their own notionals and order types', () {
      const FeeModel fees = FeeModel(
        makerFeePercent: 0.02,
        takerFeePercent: 0.06,
        entryOrderType: FeeOrderType.maker,
        targetExitOrderType: FeeOrderType.taker,
        stopOrderType: FeeOrderType.taker,
        entrySlippagePercent: 0,
        targetSlippagePercent: 0,
        stopSlippagePercent: 0,
        estimatedSpreadPercent: 0,
        safetyBufferPercent: 0,
      );
      final SmartTradePlan plan = PositionCalculator.calculate(
        input: _input(),
        feeModel: fees,
      );
      final TargetOutcome target = plan.targets.first;

      expect(
        target.costs.entryFee,
        closeTo(plan.quantity * plan.effectiveEntry * 0.0002, 1e-10),
      );
      expect(
        target.costs.exitFee,
        closeTo(plan.quantity * target.effectivePrice * 0.0006, 1e-10),
      );
      expect(target.costs.entryFee, isNot(target.costs.exitFee));
    });

    test('slippage changes execution prices in the adverse direction', () {
      const FeeModel slippage = FeeModel(
        makerFeePercent: 0,
        takerFeePercent: 0,
        entrySlippagePercent: 0.1,
        targetSlippagePercent: 0.1,
        stopSlippagePercent: 0.1,
        estimatedSpreadPercent: 0,
        safetyBufferPercent: 0,
      );
      final SmartTradePlan longPlan = PositionCalculator.calculate(
        input: _input(),
        feeModel: slippage,
      );
      final SmartTradePlan shortPlan = PositionCalculator.calculate(
        input: _input(
          direction: SignalDirection.short,
          decisionAction: DecisionAction.short,
          stop: 100.65,
          tp1: 99,
          tp2: 98,
          regime: MarketRegimeHint.trendDown,
        ),
        feeModel: slippage,
      );

      expect(longPlan.effectiveEntry, greaterThan(longPlan.entry));
      expect(
        longPlan.targets.first.effectivePrice,
        lessThan(longPlan.targets.first.price),
      );
      expect(shortPlan.effectiveEntry, lessThan(shortPlan.entry));
      expect(
        shortPlan.targets.first.effectivePrice,
        greaterThan(shortPlan.targets.first.price),
      );
    });

    test('stop and targets round conservatively by tick size', () {
      final SmartTradePlan longPlan = _calculate(
        _input(stop: 99.357, tp1: 101.237, tp2: 102.519),
      );
      final SmartTradePlan shortPlan = _calculate(
        _input(
          direction: SignalDirection.short,
          decisionAction: DecisionAction.short,
          stop: 100.653,
          tp1: 99.347,
          tp2: 98.331,
          regime: MarketRegimeHint.trendDown,
        ),
      );

      expect(longPlan.stop, 99.35);
      expect(longPlan.targets.first.price, 101.23);
      expect(shortPlan.stop, 100.66);
      expect(shortPlan.targets.first.price, 99.35);
    });

    test('target crossing Entry after tick rounding is blocked explicitly', () {
      final SmartTradePlan plan = _calculate(
        _input(tp1: 100.004, tp2: 100.006),
      );

      expect(
        plan.validationIssues.map((TradeValidationIssue issue) => issue.code),
        contains(TradeValidationCode.invalidTargetDirection),
      );
      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
    });

    test('missing exchange rules block the trade with typed errors', () {
      final SmartTradePlan plan = _calculate(
        _input().copyWith(tickSize: 0, quantityStep: 0),
      );

      expect(plan.isValid, isFalse);
      expect(
        plan.validationIssues.map((TradeValidationIssue issue) => issue.code),
        containsAll(<TradeValidationCode>[
          TradeValidationCode.missingTickSize,
          TradeValidationCode.missingQuantityStep,
        ]),
      );
    });

    test('quantity that floors to zero is blocked explicitly', () {
      final SmartTradePlan plan = _calculate(
        _input().copyWith(
          allocatedMargin: 1,
          quantityStep: 1,
          minOrderQuantity: 1,
        ),
      );

      expect(plan.quantity, 0);
      expect(
        plan.validationIssues.map((TradeValidationIssue issue) => issue.code),
        contains(TradeValidationCode.quantityRoundsToZero),
      );
      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
    });

    test('tiny prices stay finite and respect tick and quantity steps', () {
      final SmartTradePlan plan = _calculate(
        _input(
          entry: 0.00000012,
          stop: 0.00000011,
          tp1: 0.00000013,
          tp2: 0.00000015,
        ).copyWith(
          tickSize: 0.00000001,
          quantityStep: 1,
          minOrderQuantity: 1,
          minNotional: 1,
        ),
      );

      expect(plan.stop, 0.00000011);
      expect(plan.quantity.isFinite, isTrue);
      expect(plan.positionNotional.isFinite, isTrue);
      expect(plan.quantity, plan.quantity.floorToDouble());
    });

    test('partial TP allocation produces weighted raw and net Result R', () {
      final SmartTradePlan plan = _calculate(_input().copyWith(tp3: 104));

      expect(
        plan.targets.map((TargetOutcome target) => target.allocationFraction),
        <double>[0.5, 0.3, 0.2],
      );
      final double expectedRaw = plan.targets.fold<double>(
        0,
        (double total, TargetOutcome target) =>
            total + target.rawRiskReward * target.allocationFraction,
      );
      expect(plan.weightedRawResultR, closeTo(expectedRaw, 1e-12));
      expect(
        plan.weightedNetResultR,
        closeTo(plan.partialNetProfit / plan.stopOutcome.expectedLoss, 1e-12),
      );
    });

    test('invalid partial TP allocation is a typed blocking error', () {
      final SmartTradePlan plan = _calculate(
        _input().copyWith(tp3: 104, targetAllocations: <double>[0.8, 0.4, 0.2]),
      );

      expect(
        plan.validationIssues.map((TradeValidationIssue issue) => issue.code),
        contains(TradeValidationCode.invalidTargetAllocations),
      );
      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
    });

    test('personal risk mode permits up to 10x without exceeding 20% risk', () {
      final SmartTradePlan plan = _calculate(
        _input(volatilityPercent: 25).copyWith(
          riskPercent: 20,
          personalMaxLeverage: 10,
          highRiskLeverageEnabled: true,
        ),
      );

      expect(plan.maxLoss, 20);
      expect(plan.leverageSafety.safeLeverage, lessThan(10));
      expect(plan.leverageSafety.highRiskOverrideApplied, isTrue);
      expect(plan.leverage, 10);
      expect(plan.stopOutcome.expectedLoss, lessThanOrEqualTo(20.01));
    });

    test('risk above 20 percent remains blocked', () {
      final SmartTradePlan plan = _calculate(
        _input().copyWith(
          riskPercent: 20.1,
          personalMaxLeverage: 10,
          highRiskLeverageEnabled: true,
        ),
      );

      expect(
        plan.validationIssues.map((TradeValidationIssue issue) => issue.code),
        contains(TradeValidationCode.invalidRisk),
      );
      expect(plan.safetyStatus, TradeSafetyStatus.blocked);
    });

    test('high price calculations remain finite', () {
      final SmartTradePlan plan = _calculate(
        _input(
          entry: 1000000000,
          stop: 999000000,
          tp1: 1002000000,
          tp2: 1005000000,
        ).copyWith(
          tickSize: 0.1,
          quantityStep: 0.00000001,
          minOrderQuantity: 0.00000001,
          minNotional: 5,
        ),
      );

      expect(plan.quantity.isFinite, isTrue);
      expect(plan.positionNotional.isFinite, isTrue);
      expect(plan.stopOutcome.expectedLoss.isFinite, isTrue);
      expect(
        plan.targets.every((TargetOutcome target) => target.netProfit.isFinite),
        isTrue,
      );
    });
  });
}

SmartTradePlan _calculate(SmartPositionInput input) =>
    PositionCalculator.calculate(input: input, feeModel: const FeeModel());

SmartPositionInput _input({
  SignalDirection direction = SignalDirection.long,
  DecisionAction decisionAction = DecisionAction.long,
  SignalStage stage = SignalStage.entryConfirmed,
  double entry = 100,
  double stop = 99.35,
  double tp1 = 101,
  double tp2 = 102.5,
  double volatilityPercent = 5,
  double targetMovePercent = 0.30,
  MarketRegimeHint regime = MarketRegimeHint.trendUp,
}) {
  return SmartPositionInput(
    symbol: 'BTCUSDT',
    direction: direction,
    decisionAction: decisionAction,
    signalStage: stage,
    currentPrice: entry,
    entryZoneLow: entry * 0.999,
    entryZoneHigh: entry * 1.001,
    entry: entry,
    stop: stop,
    tp1: tp1,
    tp2: tp2,
    confidence: 88,
    atr: entry * 0.003,
    volatilityPercent: volatilityPercent,
    marketRegime: regime,
    setupType: 'TEST_SETUP',
    allocatedMargin: 100,
    riskPercent: 3,
    targetMovePercent: targetMovePercent,
    exchangeMaxLeverage: 10,
    assetRiskClass: AssetRiskClass.major,
    quantityStep: 0.001,
    minOrderQuantity: 0.001,
    minNotional: 5,
    tickSize: 0.01,
  );
}
