import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'leverage_safety.dart';

class PositionCalculator {
  const PositionCalculator._();

  static SmartTradePlan calculate({
    required SmartPositionInput input,
    required FeeModel feeModel,
  }) {
    final List<String> blockingReasons = _validate(input, feeModel);
    final double margin = _positive(input.allocatedMargin);
    final double riskPercent = _positive(input.riskPercent);
    final double maxLoss = margin * riskPercent / 100.0;
    final double entry = _positive(input.entry);
    final double stop = _positive(input.stop);
    final double stopDistancePercent = entry == 0
        ? 0.0
        : (entry - stop).abs() / entry * 100.0;

    final double effectiveLossPercent = entry == 0 || stop == 0
        ? 0.0
        : stopDistancePercent +
              feeModel.feePercent(feeModel.entryOrderType) +
              feeModel.feePercent(feeModel.stopOrderType) * stop / entry +
              feeModel.estimatedSpreadPercent +
              feeModel.stopSlippagePercent * stop / entry +
              feeModel.safetyBufferPercent;
    final double effectiveLossRate = effectiveLossPercent / 100.0;
    final double maxNotionalByRisk =
        maxLoss > 0 && effectiveLossRate > 0 && effectiveLossRate.isFinite
        ? maxLoss / effectiveLossRate
        : 0.0;
    final double calculatedLeverage = margin > 0
        ? maxNotionalByRisk / margin
        : 0.0;
    final LeverageSafetyResult leverageSafety = LeverageSafety.evaluate(
      input: input,
      feeModel: feeModel,
      calculatedLeverage: calculatedLeverage,
      stopDistancePercent: stopDistancePercent,
    );

    int leverage = leverageSafety.recommendedLeverage;
    if (calculatedLeverage < 1.0) {
      blockingReasons.add(
        'Даже позиция 1x превышает заданный риск при текущем структурном Stop.',
      );
      leverage = 0;
    }

    final double requestedNotional = leverage <= 0 ? 0.0 : margin * leverage;
    final double rawQuantity = entry <= 0 ? 0.0 : requestedNotional / entry;
    final double quantity = _roundDown(rawQuantity, input.quantityStep);
    final double positionNotional = quantity * entry;

    if (leverage > 0 && input.minOrderQuantity > 0) {
      if (quantity + 1e-12 < input.minOrderQuantity) {
        blockingReasons.add(
          'Количество меньше минимально допустимого для инструмента.',
        );
      }
    }
    if (leverage > 0 && input.minNotional > 0) {
      if (positionNotional + 1e-9 < input.minNotional) {
        blockingReasons.add(
          'Размер позиции меньше минимальной стоимости ордера.',
        );
      }
    }

    final StopOutcome stopOutcome = _stopOutcome(
      input: input,
      feeModel: feeModel,
      quantity: quantity,
      notional: positionNotional,
    );
    if (stopOutcome.expectedLoss > maxLoss + 0.01) {
      blockingReasons.add(
        'Ожидаемый убыток по Stop превышает установленный лимит.',
      );
    }

    final List<TargetOutcome> targets = <TargetOutcome>[
      _targetOutcome(
        label: 'TP1',
        target: input.tp1,
        input: input,
        feeModel: feeModel,
        quantity: quantity,
        notional: positionNotional,
        stopOutcome: stopOutcome,
      ),
      _targetOutcome(
        label: 'TP2',
        target: input.tp2,
        input: input,
        feeModel: feeModel,
        quantity: quantity,
        notional: positionNotional,
        stopOutcome: stopOutcome,
      ),
      if (input.tp3 != null && input.tp3! > 0)
        _targetOutcome(
          label: 'TP3',
          target: input.tp3!,
          input: input,
          feeModel: feeModel,
          quantity: quantity,
          notional: positionNotional,
          stopOutcome: stopOutcome,
        ),
    ];
    final double targetMovePrice = entry <= 0
        ? 0.0
        : input.direction == SignalDirection.long
        ? entry * (1.0 + input.targetMovePercent / 100.0)
        : entry * (1.0 - input.targetMovePercent / 100.0);
    final TargetOutcome targetMoveOutcome = _targetOutcome(
      label: 'TARGET MOVE',
      target: targetMovePrice,
      input: input,
      feeModel: feeModel,
      quantity: quantity,
      notional: positionNotional,
      stopOutcome: stopOutcome,
    );

    final TargetOutcome primaryTarget = targets.length > 1
        ? targets[1]
        : targets.first;
    final TradeSafetyStatus status = _safetyStatus(
      input: input,
      primaryTarget: primaryTarget,
      blockingReasons: blockingReasons,
      leverageSafety: leverageSafety,
    );
    final List<String> reasons = <String>[
      ...blockingReasons,
      if (primaryTarget.verdict == TargetVerdict.skip)
        'Расходы или расстояние до цели не дают достаточного преимущества.',
      if (input.isChaos) 'Режим CHAOS / HIGH VOL запрещает обычный вход.',
      if (input.confidence < 55)
        'Confidence слишком низкий для открытия позиции.',
      if (status == TradeSafetyStatus.wait)
        'Расчёт готов, но Decision Engine ещё не подтвердил вход.',
      if (leverageSafety.calculatedLeverage > leverageSafety.safetyLimit)
        'Математическое плечо снижено Safety Gate.',
    ];
    final List<String> explanation = _explanation(
      input: input,
      maxLoss: maxLoss,
      stopDistancePercent: stopDistancePercent,
      effectiveLossPercent: effectiveLossPercent,
      maxNotionalByRisk: maxNotionalByRisk,
      leverageSafety: leverageSafety,
      feeModel: feeModel,
    );

    return SmartTradePlan(
      symbol: input.symbol,
      side: input.direction,
      entry: input.entry,
      stop: input.stop,
      targets: List<TargetOutcome>.unmodifiable(targets),
      margin: margin,
      leverage: leverage,
      quantity: quantity,
      positionNotional: positionNotional,
      maxLoss: maxLoss,
      estimatedFees: stopOutcome.costs.fees,
      estimatedSlippage: stopOutcome.costs.slippage + stopOutcome.costs.spread,
      rawRiskReward: primaryTarget.rawRiskReward,
      netRiskReward: primaryTarget.netRiskReward,
      confidence: input.confidence,
      setupType: input.setupType,
      safetyStatus: status,
      stopOutcome: stopOutcome,
      leverageSafety: leverageSafety,
      targetMoveOutcome: targetMoveOutcome,
      explanation: List<String>.unmodifiable(explanation),
      reasons: List<String>.unmodifiable(reasons.toSet()),
      maxNotionalByRisk: maxNotionalByRisk,
      effectiveLossPercent: effectiveLossPercent,
    );
  }

  static List<String> _validate(SmartPositionInput input, FeeModel feeModel) {
    final List<String> reasons = <String>[];
    final List<double> requiredValues = <double>[
      input.allocatedMargin,
      input.riskPercent,
      input.entry,
      input.stop,
      input.tp1,
      input.tp2,
    ];
    if (requiredValues.any((double value) => !value.isFinite)) {
      reasons.add('В расчёте есть некорректное числовое значение.');
    }
    if (input.allocatedMargin <= 0) {
      reasons.add('Маржа должна быть больше нуля.');
    }
    if (input.riskPercent <= 0 || input.riskPercent > 20) {
      reasons.add('Риск должен быть больше 0% и не выше 20%.');
    }
    if (input.entry <= 0 || input.stop <= 0) {
      reasons.add('Entry и Stop должны быть больше нуля.');
    }
    if (input.entry == input.stop) {
      reasons.add('Stop не может совпадать с Entry.');
    }
    final bool long = input.direction == SignalDirection.long;
    if (input.entry > 0 && input.stop > 0) {
      if (long && input.stop >= input.entry) {
        reasons.add('Для LONG структурный Stop должен быть ниже Entry.');
      }
      if (!long && input.stop <= input.entry) {
        reasons.add('Для SHORT структурный Stop должен быть выше Entry.');
      }
    }
    final List<double> targets = <double>[
      input.tp1,
      input.tp2,
      if (input.tp3 != null) input.tp3!,
    ];
    if (targets.any((double target) => target <= 0)) {
      reasons.add('Take Profit должен быть больше нуля.');
    }
    if (long && targets.any((double target) => target <= input.entry)) {
      reasons.add('Для LONG цели должны быть выше Entry.');
    }
    if (!long && targets.any((double target) => target >= input.entry)) {
      reasons.add('Для SHORT цели должны быть ниже Entry.');
    }
    if (input.targetMovePercent <= 0 || !input.targetMovePercent.isFinite) {
      reasons.add('Target move должен быть больше нуля.');
    }
    final List<double> fees = <double>[
      feeModel.makerFeePercent,
      feeModel.takerFeePercent,
      feeModel.targetSlippagePercent,
      feeModel.stopSlippagePercent,
      feeModel.estimatedSpreadPercent,
      feeModel.safetyBufferPercent,
    ];
    if (fees.any((double value) => !value.isFinite || value < 0)) {
      reasons.add('Комиссии и оценочные расходы не могут быть отрицательными.');
    }
    return reasons;
  }

  static StopOutcome _stopOutcome({
    required SmartPositionInput input,
    required FeeModel feeModel,
    required double quantity,
    required double notional,
  }) {
    final double distancePercent = input.entry <= 0
        ? 0.0
        : (input.entry - input.stop).abs() / input.entry * 100.0;
    final double stopNotional = quantity * _positive(input.stop);
    final CostBreakdown costs = CostBreakdown(
      entryFee: notional * feeModel.feePercent(feeModel.entryOrderType) / 100.0,
      exitFee:
          stopNotional * feeModel.feePercent(feeModel.stopOrderType) / 100.0,
      spread: notional * feeModel.estimatedSpreadPercent / 100.0,
      slippage: stopNotional * feeModel.stopSlippagePercent / 100.0,
      safetyBuffer: notional * feeModel.safetyBufferPercent / 100.0,
    );
    return StopOutcome(
      distancePercent: distancePercent,
      movementLoss: quantity * (input.entry - input.stop).abs(),
      costs: costs,
    );
  }

  static TargetOutcome _targetOutcome({
    required String label,
    required double target,
    required SmartPositionInput input,
    required FeeModel feeModel,
    required double quantity,
    required double notional,
    required StopOutcome stopOutcome,
  }) {
    final bool long = input.direction == SignalDirection.long;
    final double favorableMove = long
        ? target - input.entry
        : input.entry - target;
    final double movePercent = input.entry <= 0
        ? 0.0
        : favorableMove / input.entry * 100.0;
    final double exitNotional = quantity * _positive(target);
    final CostBreakdown costs = CostBreakdown(
      entryFee: notional * feeModel.feePercent(feeModel.entryOrderType) / 100.0,
      exitFee:
          exitNotional *
          feeModel.feePercent(feeModel.targetExitOrderType) /
          100.0,
      spread: notional * feeModel.estimatedSpreadPercent / 100.0,
      slippage: exitNotional * feeModel.targetSlippagePercent / 100.0,
      safetyBuffer: 0.0,
    );
    final double gross = quantity * favorableMove;
    final double net = gross - costs.total;
    final double rawRr = stopOutcome.movementLoss <= 0
        ? 0.0
        : gross / stopOutcome.movementLoss;
    final double netRr = stopOutcome.expectedLoss <= 0
        ? 0.0
        : net / stopOutcome.expectedLoss;
    final double costRatio = gross <= 0 ? 1000.0 : costs.total / gross * 100.0;
    final TargetVerdict verdict = net <= 0 || costRatio >= 60.0 || netRr < 0.5
        ? TargetVerdict.skip
        : costRatio >= 35.0 || netRr < 1.0
        ? TargetVerdict.lowEdge
        : TargetVerdict.worthIt;
    return TargetOutcome(
      label: label,
      price: target,
      movePercent: movePercent,
      grossProfit: gross,
      costs: costs,
      netProfit: net,
      rawRiskReward: rawRr,
      netRiskReward: netRr,
      costToGrossPercent: costRatio,
      verdict: verdict,
    );
  }

  static TradeSafetyStatus _safetyStatus({
    required SmartPositionInput input,
    required TargetOutcome primaryTarget,
    required List<String> blockingReasons,
    required LeverageSafetyResult leverageSafety,
  }) {
    if (blockingReasons.isNotEmpty || leverageSafety.recommendedLeverage <= 0) {
      return TradeSafetyStatus.blocked;
    }
    if (input.isChaos ||
        input.confidence < 55 ||
        primaryTarget.verdict == TargetVerdict.skip ||
        primaryTarget.netRiskReward < 0.8) {
      return TradeSafetyStatus.skip;
    }
    if (input.decisionAction == DecisionAction.wait ||
        input.signalStage != SignalStage.entryConfirmed) {
      return TradeSafetyStatus.wait;
    }
    if (primaryTarget.verdict == TargetVerdict.lowEdge ||
        input.confidence < 70 ||
        leverageSafety.calculatedLeverage > leverageSafety.safetyLimit) {
      return TradeSafetyStatus.lowEdge;
    }
    return TradeSafetyStatus.acceptable;
  }

  static List<String> _explanation({
    required SmartPositionInput input,
    required double maxLoss,
    required double stopDistancePercent,
    required double effectiveLossPercent,
    required double maxNotionalByRisk,
    required LeverageSafetyResult leverageSafety,
    required FeeModel feeModel,
  }) {
    return <String>[
      'Ты выделил ${_money(input.allocatedMargin)} маржи на эту сделку.',
      'Максимальный риск ${input.riskPercent.toStringAsFixed(2)}% — ${_money(maxLoss)}.',
      'Структурный Stop находится на расстоянии ${stopDistancePercent.toStringAsFixed(3)}%.',
      'С комиссиями, Spread, Slippage и буфером эффективный риск составляет около ${effectiveLossPercent.toStringAsFixed(3)}%.',
      'Максимальный размер позиции по лимиту риска — ${_money(maxNotionalByRisk)}.',
      'Расчётное плечо ${leverageSafety.calculatedLeverage.toStringAsFixed(2)}x; Safety limit ${leverageSafety.safetyLimit}x; рекомендация ${leverageSafety.recommendedLeverage}x.',
      'Комиссии являются оценкой (${feeModel.makerFeePercent.toStringAsFixed(3)}% maker / ${feeModel.takerFeePercent.toStringAsFixed(3)}% taker), а не данными аккаунта Bybit.',
      ...leverageSafety.reasons,
    ];
  }

  static double _roundDown(double value, double step) {
    if (!value.isFinite || value <= 0) return 0.0;
    if (!step.isFinite || step <= 0) return value;
    return (value / step).floorToDouble() * step;
  }

  static double _positive(double value) =>
      value.isFinite && value > 0 ? value : 0.0;

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
}
