import '../models/execution_simulation_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import '../utils/exchange_decimal.dart';

/// Deterministic cost-aware execution model shared by research and future
/// Paper/Demo adapters. It never sends an order.
class ExecutionSimulator {
  const ExecutionSimulator._();

  static ExecutionSimulationResult simulate(ExecutionSimulationInput input) {
    final RadarSignal signal = input.signal;
    final bool long = signal.direction == SignalDirection.long;
    final double plannedEntry = signal.entryPrice;
    final List<String> issues = <String>[];
    if (!input.instrumentRules.isComplete) {
      issues.add('INSTRUMENT_RULES_UNAVAILABLE');
    }
    if (!plannedEntry.isFinite || plannedEntry <= 0.0) {
      issues.add('ENTRY_INVALID');
    }
    if (!signal.stop.isFinite ||
        signal.stop <= 0.0 ||
        (long ? signal.stop >= plannedEntry : signal.stop <= plannedEntry)) {
      issues.add('STOP_INVALID');
    }
    final double quantity = ExchangeDecimal.floorToStep(
      input.quantity,
      input.instrumentRules.quantityStep,
    );
    if (quantity <= 0.0) issues.add('QUANTITY_ROUNDS_TO_ZERO');
    if (quantity < input.instrumentRules.minOrderQuantity) {
      issues.add('BELOW_MIN_ORDER_QUANTITY');
    }
    final double plannedNotional = ExchangeDecimal.multiply(
      quantity,
      plannedEntry,
    );
    if (plannedNotional < input.instrumentRules.minNotional) {
      issues.add('BELOW_MIN_NOTIONAL');
    }

    final List<double> targets = input.targetPrices.isEmpty
        ? <double>[signal.tp1, signal.tp2]
        : List<double>.of(input.targetPrices);
    if (targets.isEmpty ||
        targets.any(
          (double target) =>
              !target.isFinite ||
              target <= 0.0 ||
              (long ? target <= plannedEntry : target >= plannedEntry),
        )) {
      issues.add('TARGET_INVALID');
    }
    final List<double> fractions = _fractions(
      targets.length,
      input.targetFractions,
    );
    if (fractions.isEmpty) issues.add('TARGET_FRACTIONS_INVALID');
    if (input.candles.isEmpty) issues.add('CANDLES_UNAVAILABLE');
    if (issues.isNotEmpty) {
      return _emptyResult(
        signal: signal,
        status: SimulatedExecutionStatus.invalid,
        plannedEntry: plannedEntry,
        quantity: quantity,
        issues: issues,
        reason: 'INVALID_INPUT',
      );
    }

    final DateTime eligibleFrom =
        input.eligibleFrom?.toUtc() ?? signal.time.toUtc();
    final List<Candle> candles =
        input.candles
            .where(
              (Candle candle) => !candle.time.toUtc().isBefore(eligibleFrom),
            )
            .toList(growable: false)
          ..sort(
            (Candle first, Candle second) => first.time.compareTo(second.time),
          );
    if (candles.isEmpty) {
      return _emptyResult(
        signal: signal,
        status: SimulatedExecutionStatus.noEntry,
        plannedEntry: plannedEntry,
        quantity: quantity,
        issues: const <String>[],
        reason: 'NO_FUTURE_CANDLES',
      );
    }

    final DateTime deadline = signal.time.add(input.timeout);
    DateTime? entryTime;
    double actualEntry = 0.0;
    double entryFee = 0.0;
    double entryNotional = 0.0;
    double spreadCost = 0.0;
    double remaining = quantity;
    double activeStop = signal.stop;
    DateTime? tp1Time;
    DateTime? tp2Time;
    final List<SimulatedExit> exits = <SimulatedExit>[];
    double bestFavorable = 0.0;
    double worstAdverse = 0.0;
    int nextTarget = 0;
    Candle? lastProcessed;
    SimulatedExecutionStatus status = SimulatedExecutionStatus.noEntry;
    String terminationReason = 'ENTRY_NOT_REACHED';

    for (final Candle candle in candles) {
      if (candle.time.isAfter(deadline)) break;
      lastProcessed = candle;
      if (entryTime == null) {
        final bool zoneTouched =
            candle.low <= signal.entryHigh && candle.high >= signal.entryLow;
        if (!zoneTouched) continue;
        entryTime = candle.time;
        actualEntry = _entryPrice(input, plannedEntry, long: long);
        entryNotional = ExchangeDecimal.multiply(quantity, actualEntry);
        entryFee = _fee(
          entryNotional,
          input.feeModel,
          input.feeModel.entryOrderType,
        );
        spreadCost = input.entryOrderType == SimulationOrderType.market
            ? ExchangeDecimal.multiply(
                quantity,
                (actualEntry -
                        _applyAdverse(
                          plannedEntry,
                          input.slippageModel.entryPercent,
                          increase: long,
                        ))
                    .abs(),
              )
            : 0.0;
        status = SimulatedExecutionStatus.timeout;
        terminationReason = 'TIMEOUT';
      }

      final double favorable = long
          ? candle.high - actualEntry
          : actualEntry - candle.low;
      final double adverse = long
          ? actualEntry - candle.low
          : candle.high - actualEntry;
      if (favorable > bestFavorable) bestFavorable = favorable;
      if (adverse > worstAdverse) worstAdverse = adverse;

      final bool stopTouched = long
          ? candle.low <= activeStop
          : candle.high >= activeStop;
      bool targetTouched = false;
      for (int index = nextTarget; index < targets.length; index++) {
        if (long
            ? candle.high >= targets[index]
            : candle.low <= targets[index]) {
          targetTouched = true;
          break;
        }
      }

      // The sequence inside an OHLC candle is unknown. A simultaneous Stop/TP
      // is therefore resolved against the strategy, never optimistically.
      if (stopTouched && targetTouched) {
        _addExit(
          exits: exits,
          label: 'STOP',
          timestamp: candle.time,
          plannedPrice: activeStop,
          actualPrice: _stopPrice(input, activeStop, long: long),
          quantity: remaining,
          entry: actualEntry,
          long: long,
          feeModel: input.feeModel,
          orderType: input.feeModel.stopOrderType,
        );
        remaining = 0.0;
        status = SimulatedExecutionStatus.stopped;
        terminationReason = 'STOP_AND_TARGET_SAME_CANDLE_CONSERVATIVE_STOP';
        break;
      }
      if (stopTouched) {
        _addExit(
          exits: exits,
          label: activeStop == plannedEntry ? 'BREAK_EVEN_STOP' : 'STOP',
          timestamp: candle.time,
          plannedPrice: activeStop,
          actualPrice: _stopPrice(input, activeStop, long: long),
          quantity: remaining,
          entry: actualEntry,
          long: long,
          feeModel: input.feeModel,
          orderType: input.feeModel.stopOrderType,
        );
        remaining = 0.0;
        status = SimulatedExecutionStatus.stopped;
        terminationReason = activeStop == plannedEntry
            ? 'BREAK_EVEN_STOP'
            : 'STOP';
        break;
      }

      while (nextTarget < targets.length &&
          (long
              ? candle.high >= targets[nextTarget]
              : candle.low <= targets[nextTarget])) {
        final bool lastTarget = nextTarget == targets.length - 1;
        final double requestedQuantity = lastTarget
            ? remaining
            : ExchangeDecimal.floorToStep(
                ExchangeDecimal.multiply(quantity, fractions[nextTarget]),
                input.instrumentRules.quantityStep,
              );
        final double exitQuantity = requestedQuantity > remaining
            ? remaining
            : requestedQuantity;
        if (exitQuantity > 0.0) {
          _addExit(
            exits: exits,
            label: 'TP${nextTarget + 1}',
            timestamp: candle.time,
            plannedPrice: targets[nextTarget],
            actualPrice: _targetPrice(input, targets[nextTarget], long: long),
            quantity: exitQuantity,
            entry: actualEntry,
            long: long,
            feeModel: input.feeModel,
            orderType: input.feeModel.targetExitOrderType,
          );
          remaining = ExchangeDecimal.subtract(remaining, exitQuantity);
          if (nextTarget == 0) tp1Time = candle.time;
          if (nextTarget == 1) tp2Time = candle.time;
          if (nextTarget == 0 && input.moveStopToBreakEvenAfterTp1) {
            activeStop = plannedEntry;
          }
        }
        nextTarget++;
      }
      if (remaining <= 0.0) {
        status = SimulatedExecutionStatus.completed;
        terminationReason = 'ALL_TARGETS_FILLED';
        break;
      }
    }

    if (entryTime == null) {
      return _emptyResult(
        signal: signal,
        status: SimulatedExecutionStatus.noEntry,
        plannedEntry: plannedEntry,
        quantity: quantity,
        issues: const <String>[],
        reason: 'ENTRY_NOT_REACHED_BEFORE_TIMEOUT',
      );
    }
    if (remaining > 0.0 && status == SimulatedExecutionStatus.timeout) {
      final Candle closeCandle = lastProcessed ?? candles.last;
      final double plannedExit = closeCandle.close;
      _addExit(
        exits: exits,
        label: 'TIMEOUT',
        timestamp: closeCandle.time,
        plannedPrice: plannedExit,
        actualPrice: _targetPrice(input, plannedExit, long: long),
        quantity: remaining,
        entry: actualEntry,
        long: long,
        feeModel: input.feeModel,
        orderType: FeeOrderType.taker,
      );
      remaining = 0.0;
    }

    final DateTime exitTime = exits.last.timestamp;
    final double exitFees = exits.fold<double>(
      0.0,
      (double sum, SimulatedExit exit) => ExchangeDecimal.add(sum, exit.fee),
    );
    final double grossPnl = exits.fold<double>(
      0.0,
      (double sum, SimulatedExit exit) =>
          ExchangeDecimal.add(sum, exit.grossPnl),
    );
    final double idealGrossPnl = exits.fold<double>(0.0, (
      double sum,
      SimulatedExit exit,
    ) {
      final double move = long
          ? exit.plannedPrice - plannedEntry
          : plannedEntry - exit.plannedPrice;
      return ExchangeDecimal.add(
        sum,
        ExchangeDecimal.multiply(move, exit.quantity),
      );
    });
    final double executionDifference = idealGrossPnl - grossPnl;
    final double slippageCost = executionDifference > spreadCost
        ? executionDifference - spreadCost
        : 0.0;
    final double fundingCost = _fundingCost(
      input,
      entryTime: entryTime,
      exitTime: exitTime,
      entryNotional: entryNotional,
      long: long,
    );
    final double netPnl = grossPnl - entryFee - exitFees - fundingCost;
    final double plannedRisk = ExchangeDecimal.multiply(
      (plannedEntry - signal.stop).abs(),
      quantity,
    );
    final double rawR = plannedRisk <= 0.0
        ? 0.0
        : ExchangeDecimal.divide(idealGrossPnl, plannedRisk);
    final double effectiveStopPrice = _stopPrice(
      input,
      signal.stop,
      long: long,
    );
    final double stopMoveLoss = ExchangeDecimal.multiply(
      (actualEntry - effectiveStopPrice).abs(),
      quantity,
    );
    final double stopExitFee = _fee(
      ExchangeDecimal.multiply(quantity, effectiveStopPrice),
      input.feeModel,
      input.feeModel.stopOrderType,
    );
    final double effectiveRisk = stopMoveLoss + entryFee + stopExitFee;
    final double netR = effectiveRisk <= 0.0
        ? 0.0
        : ExchangeDecimal.divide(netPnl, effectiveRisk);
    final double stopDistance = (plannedEntry - signal.stop).abs();

    return ExecutionSimulationResult(
      status: status,
      validationIssues: const <String>[],
      plannedEntry: plannedEntry,
      actualEntry: actualEntry,
      quantity: quantity,
      entryNotional: entryNotional,
      entryFee: entryFee,
      exits: List<SimulatedExit>.unmodifiable(exits),
      exitFees: exitFees,
      spreadCost: spreadCost,
      slippageCost: slippageCost,
      fundingCost: fundingCost,
      grossPnl: grossPnl,
      netPnl: netPnl,
      rawR: rawR,
      netR: netR,
      mfeR: stopDistance <= 0.0
          ? 0.0
          : ExchangeDecimal.divide(bestFavorable, stopDistance),
      maeR: stopDistance <= 0.0
          ? 0.0
          : ExchangeDecimal.divide(worstAdverse, stopDistance),
      signalTime: signal.time,
      entryTime: entryTime,
      tp1Time: tp1Time,
      tp2Time: tp2Time,
      exitTime: exitTime,
      terminationReason: terminationReason,
    );
  }

  static List<double> _fractions(int count, List<double> supplied) {
    final List<double> values;
    if (supplied.isNotEmpty) {
      values = List<double>.of(supplied);
    } else if (count == 1) {
      values = <double>[1.0];
    } else if (count == 2) {
      values = <double>[0.5, 0.5];
    } else if (count == 3) {
      values = <double>[0.5, 0.3, 0.2];
    } else {
      return const <double>[];
    }
    if (values.length != count || values.any((double value) => value <= 0.0)) {
      return const <double>[];
    }
    final double total = values.fold<double>(
      0.0,
      (double a, double b) => a + b,
    );
    return (total - 1.0).abs() <= 0.0000001 ? values : const <double>[];
  }

  static double _entryPrice(
    ExecutionSimulationInput input,
    double planned, {
    required bool long,
  }) {
    double quoted = planned;
    if (input.entryOrderType == SimulationOrderType.market) {
      quoted = ExchangeDecimal.applyPercent(
        planned,
        input.spreadModel.percent / 2.0,
        increase: long,
      );
    }
    return _applyAdverse(
      quoted,
      input.slippageModel.entryPercent,
      increase: long,
    );
  }

  static double _targetPrice(
    ExecutionSimulationInput input,
    double planned, {
    required bool long,
  }) {
    if (input.targetOrderType == SimulationOrderType.limit) return planned;
    return _applyAdverse(
      planned,
      input.slippageModel.targetPercent,
      increase: !long,
    );
  }

  static double _stopPrice(
    ExecutionSimulationInput input,
    double planned, {
    required bool long,
  }) {
    if (input.stopOrderType == SimulationOrderType.limit) return planned;
    return _applyAdverse(
      planned,
      input.slippageModel.stopPercent,
      increase: !long,
    );
  }

  static double _applyAdverse(
    double price,
    double percent, {
    required bool increase,
  }) {
    return ExchangeDecimal.applyPercent(price, percent, increase: increase);
  }

  static void _addExit({
    required List<SimulatedExit> exits,
    required String label,
    required DateTime timestamp,
    required double plannedPrice,
    required double actualPrice,
    required double quantity,
    required double entry,
    required bool long,
    required FeeModel feeModel,
    required FeeOrderType orderType,
  }) {
    final double notional = ExchangeDecimal.multiply(quantity, actualPrice);
    final double move = long ? actualPrice - entry : entry - actualPrice;
    exits.add(
      SimulatedExit(
        label: label,
        timestamp: timestamp,
        plannedPrice: plannedPrice,
        actualPrice: actualPrice,
        quantity: quantity,
        notional: notional,
        fee: _fee(notional, feeModel, orderType),
        grossPnl: ExchangeDecimal.multiply(move, quantity),
      ),
    );
  }

  static double _fundingCost(
    ExecutionSimulationInput input, {
    required DateTime entryTime,
    required DateTime exitTime,
    required double entryNotional,
    required bool long,
  }) {
    double total = 0.0;
    for (final HistoricalFundingPayment payment in input.funding) {
      if (payment.timestamp.isBefore(entryTime) ||
          payment.timestamp.isAfter(exitTime)) {
        continue;
      }
      final double amount = ExchangeDecimal.percentOf(
        entryNotional,
        payment.ratePercent.abs(),
      );
      final bool traderPays = payment.ratePercent >= 0.0 ? long : !long;
      total = ExchangeDecimal.add(total, traderPays ? amount : -amount);
    }
    return total;
  }

  static double _fee(double notional, FeeModel model, FeeOrderType orderType) =>
      ExchangeDecimal.percentOf(notional, model.feePercent(orderType));

  static ExecutionSimulationResult _emptyResult({
    required RadarSignal signal,
    required SimulatedExecutionStatus status,
    required double plannedEntry,
    required double quantity,
    required List<String> issues,
    required String reason,
  }) {
    return ExecutionSimulationResult(
      status: status,
      validationIssues: List<String>.unmodifiable(issues),
      plannedEntry: plannedEntry,
      actualEntry: 0.0,
      quantity: quantity,
      entryNotional: 0.0,
      entryFee: 0.0,
      exits: const <SimulatedExit>[],
      exitFees: 0.0,
      spreadCost: 0.0,
      slippageCost: 0.0,
      fundingCost: 0.0,
      grossPnl: 0.0,
      netPnl: 0.0,
      rawR: 0.0,
      netR: 0.0,
      mfeR: 0.0,
      maeR: 0.0,
      signalTime: signal.time,
      entryTime: null,
      tp1Time: null,
      tp2Time: null,
      exitTime: null,
      terminationReason: reason,
    );
  }
}
