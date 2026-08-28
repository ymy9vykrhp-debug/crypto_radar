import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'exchange_decimal.dart';
import 'leverage_safety.dart';

class PositionCalculator {
  const PositionCalculator._();

  static SmartTradePlan calculate({
    required SmartPositionInput input,
    required FeeModel feeModel,
  }) {
    final FeeModel effectiveFeeModel = input.observedSpreadPercent > 0
        ? feeModel.copyWith(estimatedSpreadPercent: input.observedSpreadPercent)
        : feeModel;
    final List<TradeValidationIssue> issues = _validate(
      input,
      effectiveFeeModel,
    );
    final bool long = input.direction == SignalDirection.long;
    final double allocatedMargin = _positive(input.allocatedMargin);
    final double riskPercent = _positive(input.riskPercent);
    final double maxLoss = ExchangeDecimal.percentOf(
      allocatedMargin,
      riskPercent,
    );

    final double plannedEntry = _positive(input.entry);
    final double normalizedStop = _normalizeStop(
      input.stop,
      input.tickSize,
      long: long,
    );
    final List<double> normalizedTargets = <double>[
      _normalizeTarget(input.tp1, input.tickSize, long: long),
      _normalizeTarget(input.tp2, input.tickSize, long: long),
      if (input.tp3 != null && input.tp3! > 0)
        _normalizeTarget(input.tp3!, input.tickSize, long: long),
    ];
    if ((long &&
            normalizedTargets.any((double target) => target <= plannedEntry)) ||
        (!long &&
            normalizedTargets.any((double target) => target >= plannedEntry))) {
      _addIssue(
        issues,
        TradeValidationCode.invalidTargetDirection,
        'После биржевого округления Take Profit оказался на неверной стороне Entry.',
      );
    }
    final List<double> targetAllocations = _targetAllocations(
      input,
      normalizedTargets.length,
      issues,
    );

    final double quotedEntry = _quotedEntry(input, issues);
    final double effectiveEntry = _applyEntrySlippage(
      quotedEntry,
      effectiveFeeModel.entrySlippagePercent,
      long: long,
    );
    final double effectiveStop = _applyExitSlippage(
      normalizedStop,
      effectiveFeeModel.stopSlippagePercent,
      long: long,
    );

    final double rawStopDistance = plannedEntry <= 0
        ? 0.0
        : (plannedEntry - normalizedStop).abs();
    final double effectiveStopDistance = effectiveEntry <= 0
        ? 0.0
        : _lossDistance(entry: effectiveEntry, exit: effectiveStop, long: long);
    if (rawStopDistance <= 0 || effectiveStopDistance <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.zeroStopDistance,
        'После биржевого округления Stop совпадает с Entry или находится на неверной стороне.',
      );
    }

    final double stopDistancePercent = plannedEntry <= 0
        ? 0.0
        : ExchangeDecimal.divide(rawStopDistance, plannedEntry) * 100.0;
    final double riskPerUnit = _riskPerUnit(
      effectiveEntry: effectiveEntry,
      effectiveStop: effectiveStop,
      feeModel: effectiveFeeModel,
      long: long,
    );
    final double effectiveLossRate = effectiveEntry > 0 && riskPerUnit > 0
        ? ExchangeDecimal.divide(riskPerUnit, effectiveEntry)
        : 0.0;
    final double effectiveLossPercent = effectiveLossRate * 100.0;
    final double maxNotionalByRisk =
        maxLoss > 0 && effectiveLossRate > 0 && effectiveLossRate.isFinite
        ? ExchangeDecimal.divide(maxLoss, effectiveLossRate)
        : 0.0;
    final double calculatedLeverage = allocatedMargin > 0
        ? ExchangeDecimal.divide(maxNotionalByRisk, allocatedMargin)
        : 0.0;
    final LeverageSafetyResult leverageSafety = LeverageSafety.evaluate(
      input: input,
      feeModel: effectiveFeeModel,
      calculatedLeverage: calculatedLeverage,
      stopDistancePercent: stopDistancePercent,
    );

    int leverage = leverageSafety.recommendedLeverage;
    if (calculatedLeverage < 1.0) {
      _addIssue(
        issues,
        TradeValidationCode.leverageBelowOne,
        'Даже позиция 1x превышает заданный риск при текущем структурном Stop.',
      );
      leverage = 0;
    }

    final double requestedNotional = leverage <= 0
        ? 0.0
        : ExchangeDecimal.multiply(allocatedMargin, leverage.toDouble());
    final double rawQuantity = effectiveEntry <= 0
        ? 0.0
        : ExchangeDecimal.divide(requestedNotional, effectiveEntry);
    final double quantity = ExchangeDecimal.floorToStep(
      rawQuantity,
      input.quantityStep,
    );
    if (rawQuantity > 0 && quantity <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.quantityRoundsToZero,
        'Количество после округления по qtyStep стало равно нулю.',
      );
    }
    final double positionNotional = quantity <= 0 || effectiveEntry <= 0
        ? 0.0
        : ExchangeDecimal.multiply(quantity, effectiveEntry);
    final double actualMargin = leverage <= 0
        ? 0.0
        : ExchangeDecimal.divide(positionNotional, leverage.toDouble());

    if (leverage > 0 && input.minOrderQuantity > 0) {
      if (_lessThan(quantity, input.minOrderQuantity)) {
        _addIssue(
          issues,
          TradeValidationCode.belowMinimumQuantity,
          'Количество меньше минимально допустимого для инструмента.',
        );
      }
    }
    if (leverage > 0 && input.minNotional > 0) {
      if (_lessThan(positionNotional, input.minNotional)) {
        _addIssue(
          issues,
          TradeValidationCode.belowMinimumNotional,
          'Размер позиции меньше минимальной стоимости ордера.',
        );
      }
    }

    final StopOutcome stopOutcome = _stopOutcome(
      input: input,
      feeModel: effectiveFeeModel,
      quantity: quantity,
      plannedEntry: plannedEntry,
      quotedEntry: quotedEntry,
      effectiveEntry: effectiveEntry,
      normalizedStop: normalizedStop,
      effectiveStop: effectiveStop,
    );
    if (stopOutcome.expectedLoss > maxLoss + 0.00000001) {
      _addIssue(
        issues,
        TradeValidationCode.riskLimitExceeded,
        'Ожидаемый убыток по Stop превышает установленный лимит.',
      );
    }

    final List<TargetOutcome> targets = <TargetOutcome>[
      for (int index = 0; index < normalizedTargets.length; index++)
        _targetOutcome(
          label: 'TP${index + 1}',
          target: normalizedTargets[index],
          input: input,
          feeModel: effectiveFeeModel,
          quantity: quantity,
          plannedEntry: plannedEntry,
          quotedEntry: quotedEntry,
          effectiveEntry: effectiveEntry,
          normalizedStop: normalizedStop,
          stopOutcome: stopOutcome,
          allocationFraction: targetAllocations[index],
        ),
    ];
    final double rawTargetMovePrice = plannedEntry <= 0
        ? 0.0
        : long
        ? ExchangeDecimal.applyPercent(
            plannedEntry,
            input.targetMovePercent,
            increase: true,
          )
        : ExchangeDecimal.applyPercent(
            plannedEntry,
            input.targetMovePercent,
            increase: false,
          );
    final double targetMovePrice = _normalizeTarget(
      rawTargetMovePrice,
      input.tickSize,
      long: long,
    );
    final TargetOutcome targetMoveOutcome = _targetOutcome(
      label: 'TARGET MOVE',
      target: targetMovePrice,
      input: input,
      feeModel: effectiveFeeModel,
      quantity: quantity,
      plannedEntry: plannedEntry,
      quotedEntry: quotedEntry,
      effectiveEntry: effectiveEntry,
      normalizedStop: normalizedStop,
      stopOutcome: stopOutcome,
      allocationFraction: 1.0,
    );

    final TargetOutcome primaryTarget = targets.length > 1
        ? targets[1]
        : targets.first;
    final double weightedRawResultR = targets.fold<double>(
      0.0,
      (double total, TargetOutcome target) =>
          total + target.rawRiskReward * target.allocationFraction,
    );
    final double partialNetProfit = targets.fold<double>(
      0.0,
      (double total, TargetOutcome target) =>
          total + target.netProfit * target.allocationFraction,
    );
    final double weightedNetResultR = stopOutcome.expectedLoss <= 0
        ? 0.0
        : ExchangeDecimal.divide(partialNetProfit, stopOutcome.expectedLoss);
    final List<String> blockingReasons = issues
        .map<String>((TradeValidationIssue issue) => issue.message)
        .toList(growable: true);
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
      feeModel: effectiveFeeModel,
      effectiveEntry: effectiveEntry,
    );

    return SmartTradePlan(
      symbol: input.symbol,
      side: input.direction,
      allocatedMargin: allocatedMargin,
      entry: plannedEntry,
      effectiveEntry: effectiveEntry,
      stop: normalizedStop,
      targets: List<TargetOutcome>.unmodifiable(targets),
      margin: actualMargin,
      leverage: leverage,
      quantity: quantity,
      positionNotional: positionNotional,
      maxLoss: maxLoss,
      estimatedFees: stopOutcome.costs.fees,
      estimatedSlippage: stopOutcome.costs.slippage + stopOutcome.costs.spread,
      rawRiskReward: primaryTarget.rawRiskReward,
      netRiskReward: primaryTarget.netRiskReward,
      weightedRawResultR: weightedRawResultR,
      weightedNetResultR: weightedNetResultR,
      partialNetProfit: partialNetProfit,
      confidence: input.confidence,
      setupType: input.setupType,
      safetyStatus: status,
      stopOutcome: stopOutcome,
      leverageSafety: leverageSafety,
      targetMoveOutcome: targetMoveOutcome,
      explanation: List<String>.unmodifiable(explanation),
      reasons: List<String>.unmodifiable(reasons.toSet()),
      validationIssues: List<TradeValidationIssue>.unmodifiable(issues),
      maxNotionalByRisk: maxNotionalByRisk,
      effectiveLossPercent: effectiveLossPercent,
    );
  }

  static List<TradeValidationIssue> _validate(
    SmartPositionInput input,
    FeeModel feeModel,
  ) {
    final List<TradeValidationIssue> issues = <TradeValidationIssue>[];
    final List<double> requiredValues = <double>[
      input.allocatedMargin,
      input.riskPercent,
      input.entry,
      input.stop,
      input.tp1,
      input.tp2,
    ];
    if (requiredValues.any((double value) => !value.isFinite)) {
      _addIssue(
        issues,
        TradeValidationCode.invalidNumber,
        'В расчёте есть некорректное числовое значение.',
      );
    }
    if (input.allocatedMargin <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.invalidMargin,
        'Маржа должна быть больше нуля.',
      );
    }
    if (input.riskPercent <= 0 || input.riskPercent > 20) {
      _addIssue(
        issues,
        TradeValidationCode.invalidRisk,
        'Риск должен быть больше 0% и не выше 20%.',
      );
    }
    if (input.entry <= 0 || input.stop <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.invalidEntryOrStop,
        'Entry и Stop должны быть больше нуля.',
      );
    }
    if (input.entry == input.stop) {
      _addIssue(
        issues,
        TradeValidationCode.zeroStopDistance,
        'Stop не может совпадать с Entry.',
      );
    }
    final bool long = input.direction == SignalDirection.long;
    if (input.entry > 0 && input.stop > 0) {
      if ((long && input.stop >= input.entry) ||
          (!long && input.stop <= input.entry)) {
        _addIssue(
          issues,
          TradeValidationCode.invalidStopDirection,
          long
              ? 'Для LONG структурный Stop должен быть ниже Entry.'
              : 'Для SHORT структурный Stop должен быть выше Entry.',
        );
      }
    }
    final List<double> targets = <double>[
      input.tp1,
      input.tp2,
      if (input.tp3 != null) input.tp3!,
    ];
    if (targets.any((double target) => target <= 0 || !target.isFinite)) {
      _addIssue(
        issues,
        TradeValidationCode.invalidTarget,
        'Take Profit должен быть конечным числом больше нуля.',
      );
    }
    if ((long && targets.any((double target) => target <= input.entry)) ||
        (!long && targets.any((double target) => target >= input.entry))) {
      _addIssue(
        issues,
        TradeValidationCode.invalidTargetDirection,
        long
            ? 'Для LONG цели должны быть выше Entry.'
            : 'Для SHORT цели должны быть ниже Entry.',
      );
    }
    if (input.targetMovePercent <= 0 || !input.targetMovePercent.isFinite) {
      _addIssue(
        issues,
        TradeValidationCode.invalidTargetMove,
        'Target move должен быть больше нуля.',
      );
    }
    final List<double> costs = <double>[
      feeModel.makerFeePercent,
      feeModel.takerFeePercent,
      feeModel.entrySlippagePercent,
      feeModel.targetSlippagePercent,
      feeModel.stopSlippagePercent,
      feeModel.estimatedSpreadPercent,
      feeModel.safetyBufferPercent,
    ];
    if (costs.any((double value) => !value.isFinite || value < 0)) {
      _addIssue(
        issues,
        TradeValidationCode.invalidCosts,
        'Комиссии и оценочные расходы не могут быть отрицательными.',
      );
    }
    if (!input.tickSize.isFinite || input.tickSize <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.missingTickSize,
        'Не получен tickSize инструмента — безопасное округление цен невозможно.',
      );
    }
    if (!input.quantityStep.isFinite || input.quantityStep <= 0) {
      _addIssue(
        issues,
        TradeValidationCode.missingQuantityStep,
        'Не получен qtyStep инструмента — безопасное округление количества невозможно.',
      );
    }
    return issues;
  }

  static double _quotedEntry(
    SmartPositionInput input,
    List<TradeValidationIssue> issues,
  ) {
    if (input.executionPriceMode != ExecutionPriceMode.market) {
      return _positive(input.entry);
    }
    final bool long = input.direction == SignalDirection.long;
    final double quote = long ? input.askPrice : input.bidPrice;
    final bool validBook =
        input.bidPrice > 0 &&
        input.askPrice > 0 &&
        input.askPrice >= input.bidPrice;
    if (!validBook || !quote.isFinite) {
      _addIssue(
        issues,
        TradeValidationCode.invalidMarketQuote,
        'Для market-входа отсутствуют корректные bid/ask.',
      );
      return _positive(input.entry);
    }
    return quote;
  }

  static StopOutcome _stopOutcome({
    required SmartPositionInput input,
    required FeeModel feeModel,
    required double quantity,
    required double plannedEntry,
    required double quotedEntry,
    required double effectiveEntry,
    required double normalizedStop,
    required double effectiveStop,
  }) {
    final bool long = input.direction == SignalDirection.long;
    final double distance = _lossDistance(
      entry: effectiveEntry,
      exit: effectiveStop,
      long: long,
    );
    final double plannedDistance = plannedEntry <= 0
        ? 0.0
        : (plannedEntry - normalizedStop).abs();
    final double distancePercent = plannedEntry <= 0
        ? 0.0
        : ExchangeDecimal.divide(plannedDistance, plannedEntry) * 100.0;
    final double entryNotional = _notional(quantity, effectiveEntry);
    final double stopNotional = _notional(quantity, effectiveStop);
    final double spread = input.executionPriceMode == ExecutionPriceMode.market
        ? _notional(quantity, (quotedEntry - plannedEntry).abs())
        : 0.0;
    final double entrySlippage = _notional(
      quantity,
      (effectiveEntry - quotedEntry).abs(),
    );
    final double stopSlippage = _notional(
      quantity,
      (effectiveStop - normalizedStop).abs(),
    );
    final CostBreakdown costs = CostBreakdown(
      entryFee: ExchangeDecimal.percentOf(
        entryNotional,
        feeModel.feePercent(feeModel.entryOrderType),
      ),
      exitFee: ExchangeDecimal.percentOf(
        stopNotional,
        feeModel.feePercent(feeModel.stopOrderType),
      ),
      spread: spread,
      slippage: ExchangeDecimal.add(entrySlippage, stopSlippage),
      safetyBuffer: ExchangeDecimal.percentOf(
        entryNotional,
        feeModel.safetyBufferPercent,
      ),
    );
    return StopOutcome(
      distancePercent: distancePercent,
      movementLoss: _notional(quantity, distance),
      costs: costs,
      price: normalizedStop,
      effectivePrice: effectiveStop,
    );
  }

  static TargetOutcome _targetOutcome({
    required String label,
    required double target,
    required SmartPositionInput input,
    required FeeModel feeModel,
    required double quantity,
    required double plannedEntry,
    required double quotedEntry,
    required double effectiveEntry,
    required double normalizedStop,
    required StopOutcome stopOutcome,
    required double allocationFraction,
  }) {
    final bool long = input.direction == SignalDirection.long;
    final double effectiveTarget = _applyExitSlippage(
      target,
      feeModel.targetSlippagePercent,
      long: long,
    );
    final double idealMove = _profitDistance(
      entry: plannedEntry,
      exit: target,
      long: long,
    );
    final double executedMove = _profitDistance(
      entry: effectiveEntry,
      exit: effectiveTarget,
      long: long,
    );
    final double movePercent = plannedEntry <= 0
        ? 0.0
        : ExchangeDecimal.divide(idealMove, plannedEntry) * 100.0;
    final double entryNotional = _notional(quantity, effectiveEntry);
    final double exitNotional = _notional(quantity, effectiveTarget);
    final double spread = input.executionPriceMode == ExecutionPriceMode.market
        ? _notional(quantity, (quotedEntry - plannedEntry).abs())
        : 0.0;
    final double entrySlippage = _notional(
      quantity,
      (effectiveEntry - quotedEntry).abs(),
    );
    final double exitSlippage = _notional(
      quantity,
      (effectiveTarget - target).abs(),
    );
    final CostBreakdown costs = CostBreakdown(
      entryFee: ExchangeDecimal.percentOf(
        entryNotional,
        feeModel.feePercent(feeModel.entryOrderType),
      ),
      exitFee: ExchangeDecimal.percentOf(
        exitNotional,
        feeModel.feePercent(feeModel.targetExitOrderType),
      ),
      spread: spread,
      slippage: ExchangeDecimal.add(entrySlippage, exitSlippage),
      safetyBuffer: 0.0,
    );
    final double idealGross = _signedPositionValue(quantity, idealMove);
    final double gross = _signedPositionValue(quantity, executedMove);
    final double net = ExchangeDecimal.subtract(gross, costs.fees);
    final double rawRiskAmount = _notional(
      quantity,
      (plannedEntry - normalizedStop).abs(),
    );
    final double rawRr = rawRiskAmount <= 0
        ? 0.0
        : ExchangeDecimal.divide(idealGross, rawRiskAmount);
    final double netRr = stopOutcome.expectedLoss <= 0
        ? 0.0
        : ExchangeDecimal.divide(net, stopOutcome.expectedLoss);
    final double totalEconomicCost = idealGross > net
        ? ExchangeDecimal.subtract(idealGross, net)
        : 0.0;
    final double costRatio = idealGross <= 0
        ? 1000.0
        : ExchangeDecimal.divide(totalEconomicCost, idealGross) * 100.0;
    final TargetVerdict verdict = net <= 0 || costRatio >= 60.0 || netRr < 0.5
        ? TargetVerdict.skip
        : costRatio >= 35.0 || netRr < 1.0
        ? TargetVerdict.lowEdge
        : TargetVerdict.worthIt;
    return TargetOutcome(
      label: label,
      price: target,
      effectivePrice: effectiveTarget,
      allocationFraction: allocationFraction,
      movePercent: movePercent,
      idealGrossProfit: idealGross,
      grossProfit: gross,
      costs: costs,
      netProfit: net,
      rawRiskReward: rawRr,
      netRiskReward: netRr,
      costToGrossPercent: costRatio,
      verdict: verdict,
    );
  }

  static List<double> _targetAllocations(
    SmartPositionInput input,
    int count,
    List<TradeValidationIssue> issues,
  ) {
    final List<double> defaults = count >= 3
        ? <double>[0.5, 0.3, 0.2]
        : count == 2
        ? <double>[0.5, 0.5]
        : <double>[1.0];
    if (input.targetAllocations.isEmpty) return defaults;
    final double total = input.targetAllocations.fold<double>(
      0.0,
      (double sum, double value) => sum + value,
    );
    final bool invalid =
        input.targetAllocations.length != count ||
        input.targetAllocations.any(
          (double value) => !value.isFinite || value <= 0 || value > 1,
        ) ||
        total > 1.000000001;
    if (invalid) {
      _addIssue(
        issues,
        TradeValidationCode.invalidTargetAllocations,
        'Доли частичных TP должны быть положительными, соответствовать числу целей и в сумме не превышать 100%.',
      );
      return defaults;
    }
    return List<double>.of(input.targetAllocations, growable: false);
  }

  static double _riskPerUnit({
    required double effectiveEntry,
    required double effectiveStop,
    required FeeModel feeModel,
    required bool long,
  }) {
    if (effectiveEntry <= 0 || effectiveStop <= 0) return 0.0;
    final double priceLoss = _lossDistance(
      entry: effectiveEntry,
      exit: effectiveStop,
      long: long,
    );
    final double entryFee = ExchangeDecimal.percentOf(
      effectiveEntry,
      feeModel.feePercent(feeModel.entryOrderType),
    );
    final double stopFee = ExchangeDecimal.percentOf(
      effectiveStop,
      feeModel.feePercent(feeModel.stopOrderType),
    );
    final double safety = ExchangeDecimal.percentOf(
      effectiveEntry,
      feeModel.safetyBufferPercent,
    );
    return ExchangeDecimal.add(
      ExchangeDecimal.add(priceLoss, entryFee),
      ExchangeDecimal.add(stopFee, safety),
    );
  }

  static double _applyEntrySlippage(
    double price,
    double percent, {
    required bool long,
  }) {
    if (price <= 0) return 0.0;
    return ExchangeDecimal.applyPercent(price, percent, increase: long);
  }

  static double _applyExitSlippage(
    double price,
    double percent, {
    required bool long,
  }) {
    if (price <= 0) return 0.0;
    return ExchangeDecimal.applyPercent(price, percent, increase: !long);
  }

  static double _normalizeStop(
    double value,
    double tickSize, {
    required bool long,
  }) => long
      ? ExchangeDecimal.floorToStep(value, tickSize)
      : ExchangeDecimal.ceilToStep(value, tickSize);

  static double _normalizeTarget(
    double value,
    double tickSize, {
    required bool long,
  }) => long
      ? ExchangeDecimal.floorToStep(value, tickSize)
      : ExchangeDecimal.ceilToStep(value, tickSize);

  static double _lossDistance({
    required double entry,
    required double exit,
    required bool long,
  }) {
    final double value = long
        ? ExchangeDecimal.subtract(entry, exit)
        : ExchangeDecimal.subtract(exit, entry);
    return value > 0 ? value : 0.0;
  }

  static double _profitDistance({
    required double entry,
    required double exit,
    required bool long,
  }) {
    final double value = long
        ? ExchangeDecimal.subtract(exit, entry)
        : ExchangeDecimal.subtract(entry, exit);
    return value;
  }

  static double _signedPositionValue(double quantity, double priceMove) {
    if (quantity <= 0 || !priceMove.isFinite) return 0.0;
    return ExchangeDecimal.multiply(quantity, priceMove);
  }

  static double _notional(double quantity, double price) {
    if (quantity <= 0 || price <= 0) return 0.0;
    return ExchangeDecimal.multiply(quantity, price);
  }

  static bool _lessThan(double first, double second) =>
      ExchangeDecimal.fromDouble(first) < ExchangeDecimal.fromDouble(second);

  static void _addIssue(
    List<TradeValidationIssue> issues,
    TradeValidationCode code,
    String message,
  ) {
    if (issues.any((TradeValidationIssue issue) => issue.code == code)) return;
    issues.add(TradeValidationIssue(code: code, message: message));
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
    required double effectiveEntry,
  }) {
    return <String>[
      'Ты выделил ${_money(input.allocatedMargin)} маржи на эту сделку.',
      'Максимальный риск ${input.riskPercent.toStringAsFixed(2)}% — ${_money(maxLoss)}.',
      'Структурный Stop после tickSize находится на расстоянии ${stopDistancePercent.toStringAsFixed(3)}%.',
      'С исполнением, комиссиями и буфером эффективный риск составляет около ${effectiveLossPercent.toStringAsFixed(3)}%.',
      if ((effectiveEntry - input.entry).abs() > 0)
        'Оценочная цена исполнения Entry с учётом режима и slippage: ${effectiveEntry.toStringAsPrecision(10)}.',
      'Максимальный размер позиции по лимиту риска — ${_money(maxNotionalByRisk)}.',
      'Расчётное плечо ${leverageSafety.calculatedLeverage.toStringAsFixed(2)}x; Safety limit ${leverageSafety.safetyLimit}x; рекомендация ${leverageSafety.recommendedLeverage}x.',
      'Комиссии являются оценкой (${feeModel.makerFeePercent.toStringAsFixed(3)}% maker / ${feeModel.takerFeePercent.toStringAsFixed(3)}% taker), а не данными аккаунта Bybit.',
      ...leverageSafety.reasons,
    ];
  }

  static double _positive(double value) =>
      value.isFinite && value > 0 ? value : 0.0;

  static String _money(double value) => '\$${value.toStringAsFixed(2)}';
}
