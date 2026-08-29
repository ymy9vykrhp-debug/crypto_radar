import 'market_data_models.dart';
import 'market_models.dart';
import 'position_calculator_models.dart';
import 'signal_models.dart';

enum SimulatedExecutionStatus { completed, stopped, timeout, noEntry, invalid }

enum SimulationOrderType { market, limit }

class SlippageModel {
  const SlippageModel({
    this.entryPercent = 0.015,
    this.targetPercent = 0.015,
    this.stopPercent = 0.040,
  });

  final double entryPercent;
  final double targetPercent;
  final double stopPercent;
}

class HistoricalSpreadModel {
  const HistoricalSpreadModel({this.percent = 0.020});

  final double percent;
}

class HistoricalFundingPayment {
  const HistoricalFundingPayment({
    required this.timestamp,
    required this.ratePercent,
  });

  final DateTime timestamp;
  final double ratePercent;
}

class ExecutionSimulationInput {
  const ExecutionSimulationInput({
    required this.signal,
    required this.candles,
    required this.quantity,
    required this.instrumentRules,
    required this.feeModel,
    this.slippageModel = const SlippageModel(),
    this.spreadModel = const HistoricalSpreadModel(),
    this.entryOrderType = SimulationOrderType.limit,
    this.targetOrderType = SimulationOrderType.limit,
    this.stopOrderType = SimulationOrderType.market,
    this.targetPrices = const <double>[],
    this.targetFractions = const <double>[],
    this.funding = const <HistoricalFundingPayment>[],
    this.timeout = const Duration(hours: 24),
    this.moveStopToBreakEvenAfterTp1 = false,
    this.eligibleFrom,
  });

  final RadarSignal signal;
  final List<Candle> candles;
  final double quantity;
  final InstrumentTradingRules instrumentRules;
  final FeeModel feeModel;
  final SlippageModel slippageModel;
  final HistoricalSpreadModel spreadModel;
  final SimulationOrderType entryOrderType;
  final SimulationOrderType targetOrderType;
  final SimulationOrderType stopOrderType;
  final List<double> targetPrices;
  final List<double> targetFractions;
  final List<HistoricalFundingPayment> funding;
  final Duration timeout;
  final bool moveStopToBreakEvenAfterTp1;
  final DateTime? eligibleFrom;
}

class SimulatedExit {
  const SimulatedExit({
    required this.label,
    required this.timestamp,
    required this.plannedPrice,
    required this.actualPrice,
    required this.quantity,
    required this.notional,
    required this.fee,
    required this.grossPnl,
  });

  final String label;
  final DateTime timestamp;
  final double plannedPrice;
  final double actualPrice;
  final double quantity;
  final double notional;
  final double fee;
  final double grossPnl;
}

class ExecutionSimulationResult {
  const ExecutionSimulationResult({
    required this.status,
    required this.validationIssues,
    required this.plannedEntry,
    required this.actualEntry,
    required this.quantity,
    required this.entryNotional,
    required this.entryFee,
    required this.exits,
    required this.exitFees,
    required this.spreadCost,
    required this.slippageCost,
    required this.fundingCost,
    required this.grossPnl,
    required this.netPnl,
    required this.rawR,
    required this.netR,
    required this.mfeR,
    required this.maeR,
    required this.signalTime,
    required this.entryTime,
    required this.tp1Time,
    required this.tp2Time,
    required this.exitTime,
    required this.terminationReason,
  });

  final SimulatedExecutionStatus status;
  final List<String> validationIssues;
  final double plannedEntry;
  final double actualEntry;
  final double quantity;
  final double entryNotional;
  final double entryFee;
  final List<SimulatedExit> exits;
  final double exitFees;
  final double spreadCost;
  final double slippageCost;
  final double fundingCost;
  final double grossPnl;
  final double netPnl;
  final double rawR;
  final double netR;
  final double mfeR;
  final double maeR;
  final DateTime signalTime;
  final DateTime? entryTime;
  final DateTime? tp1Time;
  final DateTime? tp2Time;
  final DateTime? exitTime;
  final String terminationReason;

  Duration? get timeToEntry => entryTime?.difference(signalTime);

  Duration? get timeToTp1 => entryTime == null || tp1Time == null
      ? null
      : tp1Time!.difference(entryTime!);

  Duration? get timeToTp2 => entryTime == null || tp2Time == null
      ? null
      : tp2Time!.difference(entryTime!);

  Duration? get tradeDuration => entryTime == null || exitTime == null
      ? null
      : exitTime!.difference(entryTime!);
}
