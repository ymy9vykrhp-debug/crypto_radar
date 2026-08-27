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
      expect(plan.margin, 100);
      expect(plan.maxLoss, 3);
      expect(plan.leverage, greaterThanOrEqualTo(1));
      expect(plan.leverage, lessThanOrEqualTo(10));
      expect(plan.positionNotional, closeTo(plan.margin * plan.leverage, 1e-8));
      expect(plan.stopOutcome.expectedLoss, lessThanOrEqualTo(3.01));
      expect(plan.quantity, closeTo(plan.positionNotional / plan.entry, 1e-8));
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

    test('observed public spread overrides the configured estimate', () {
      final SmartTradePlan estimated = _calculate(_input());
      final SmartTradePlan observed = _calculate(
        _input().copyWith(observedSpreadPercent: 0.25),
      );

      expect(
        observed.effectiveLossPercent,
        greaterThan(estimated.effectiveLossPercent),
      );
      expect(observed.maxNotionalByRisk, lessThan(estimated.maxNotionalByRisk));
      expect(observed.leverage, lessThanOrEqualTo(estimated.leverage));
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
  );
}
