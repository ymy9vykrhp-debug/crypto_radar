import 'decision_models.dart';
import 'execution_models.dart';
import 'market_models.dart';
import 'signal_models.dart';

enum RiskPreset { cautious, normal, active, custom }

extension RiskPresetValue on RiskPreset {
  double get defaultPercent {
    switch (this) {
      case RiskPreset.cautious:
        return 1.0;
      case RiskPreset.normal:
        return 2.0;
      case RiskPreset.active:
        return 3.0;
      case RiskPreset.custom:
        return 2.0;
    }
  }
}

enum FeeOrderType { maker, taker }

class FeeModel {
  const FeeModel({
    this.makerFeePercent = 0.020,
    this.takerFeePercent = 0.055,
    this.entryOrderType = FeeOrderType.taker,
    this.targetExitOrderType = FeeOrderType.taker,
    this.stopOrderType = FeeOrderType.taker,
    this.entrySlippagePercent = 0.015,
    this.targetSlippagePercent = 0.015,
    this.stopSlippagePercent = 0.040,
    this.estimatedSpreadPercent = 0.020,
    this.safetyBufferPercent = 0.010,
  });

  final double makerFeePercent;
  final double takerFeePercent;
  final FeeOrderType entryOrderType;
  final FeeOrderType targetExitOrderType;
  final FeeOrderType stopOrderType;
  final double entrySlippagePercent;
  final double targetSlippagePercent;
  final double stopSlippagePercent;
  final double estimatedSpreadPercent;
  final double safetyBufferPercent;

  double feePercent(FeeOrderType orderType) =>
      orderType == FeeOrderType.maker ? makerFeePercent : takerFeePercent;

  FeeModel copyWith({
    double? makerFeePercent,
    double? takerFeePercent,
    FeeOrderType? entryOrderType,
    FeeOrderType? targetExitOrderType,
    FeeOrderType? stopOrderType,
    double? entrySlippagePercent,
    double? targetSlippagePercent,
    double? stopSlippagePercent,
    double? estimatedSpreadPercent,
    double? safetyBufferPercent,
  }) {
    return FeeModel(
      makerFeePercent: makerFeePercent ?? this.makerFeePercent,
      takerFeePercent: takerFeePercent ?? this.takerFeePercent,
      entryOrderType: entryOrderType ?? this.entryOrderType,
      targetExitOrderType: targetExitOrderType ?? this.targetExitOrderType,
      stopOrderType: stopOrderType ?? this.stopOrderType,
      entrySlippagePercent: entrySlippagePercent ?? this.entrySlippagePercent,
      targetSlippagePercent:
          targetSlippagePercent ?? this.targetSlippagePercent,
      stopSlippagePercent: stopSlippagePercent ?? this.stopSlippagePercent,
      estimatedSpreadPercent:
          estimatedSpreadPercent ?? this.estimatedSpreadPercent,
      safetyBufferPercent: safetyBufferPercent ?? this.safetyBufferPercent,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'makerFeePercent': makerFeePercent,
    'takerFeePercent': takerFeePercent,
    'entryOrderType': entryOrderType.name,
    'targetExitOrderType': targetExitOrderType.name,
    'stopOrderType': stopOrderType.name,
    'entrySlippagePercent': entrySlippagePercent,
    'targetSlippagePercent': targetSlippagePercent,
    'stopSlippagePercent': stopSlippagePercent,
    'estimatedSpreadPercent': estimatedSpreadPercent,
    'safetyBufferPercent': safetyBufferPercent,
  };

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    const FeeModel defaults = FeeModel();
    return FeeModel(
      makerFeePercent: _safePercent(
        json['makerFeePercent'],
        defaults.makerFeePercent,
      ),
      takerFeePercent: _safePercent(
        json['takerFeePercent'],
        defaults.takerFeePercent,
      ),
      entryOrderType: _orderType(
        json['entryOrderType'],
        defaults.entryOrderType,
      ),
      targetExitOrderType: _orderType(
        json['targetExitOrderType'],
        defaults.targetExitOrderType,
      ),
      stopOrderType: _orderType(json['stopOrderType'], defaults.stopOrderType),
      entrySlippagePercent: _safePercent(
        json['entrySlippagePercent'],
        defaults.entrySlippagePercent,
      ),
      targetSlippagePercent: _safePercent(
        json['targetSlippagePercent'],
        defaults.targetSlippagePercent,
      ),
      stopSlippagePercent: _safePercent(
        json['stopSlippagePercent'],
        defaults.stopSlippagePercent,
      ),
      estimatedSpreadPercent: _safePercent(
        json['estimatedSpreadPercent'],
        defaults.estimatedSpreadPercent,
      ),
      safetyBufferPercent: _safePercent(
        json['safetyBufferPercent'],
        defaults.safetyBufferPercent,
      ),
    );
  }
}

enum AssetRiskClass { major, standard, speculative }

enum TradeSafetyStatus { acceptable, wait, lowEdge, skip, blocked }

enum TargetVerdict { worthIt, lowEdge, skip }

enum ExecutionPriceMode { plannedLimit, market }

enum TradeValidationCode {
  invalidNumber,
  invalidMargin,
  invalidRisk,
  invalidEntryOrStop,
  zeroStopDistance,
  invalidStopDirection,
  invalidTarget,
  invalidTargetDirection,
  invalidTargetMove,
  invalidCosts,
  missingTickSize,
  missingQuantityStep,
  invalidMarketQuote,
  leverageBelowOne,
  quantityRoundsToZero,
  belowMinimumQuantity,
  belowMinimumNotional,
  riskLimitExceeded,
  invalidTargetAllocations,
}

class TradeValidationIssue {
  const TradeValidationIssue({required this.code, required this.message});

  final TradeValidationCode code;
  final String message;
}

class SmartPositionInput {
  const SmartPositionInput({
    required this.symbol,
    required this.direction,
    required this.decisionAction,
    required this.signalStage,
    required this.currentPrice,
    required this.entryZoneLow,
    required this.entryZoneHigh,
    required this.entry,
    required this.stop,
    required this.tp1,
    required this.tp2,
    required this.confidence,
    required this.atr,
    required this.volatilityPercent,
    required this.marketRegime,
    required this.setupType,
    required this.allocatedMargin,
    required this.riskPercent,
    this.tp3,
    this.targetMovePercent = 0.30,
    this.exchangeMaxLeverage = 10.0,
    this.assetRiskClass = AssetRiskClass.standard,
    this.hasSharpImpulse = false,
    this.isChaos = false,
    this.quantityStep = 0.0,
    this.minOrderQuantity = 0.0,
    this.minNotional = 0.0,
    this.tickSize = 0.0,
    this.observedSpreadPercent = 0.0,
    this.bidPrice = 0.0,
    this.askPrice = 0.0,
    this.executionPriceMode = ExecutionPriceMode.plannedLimit,
    this.targetAllocations = const <double>[],
    this.personalMaxLeverage = 10,
    this.highRiskLeverageEnabled = false,
  });

  factory SmartPositionInput.fromDecision({
    required MarketSnapshot market,
    required DecisionSnapshot decision,
    required double allocatedMargin,
    required double riskPercent,
    double volatilityPercent = 0.0,
    double exchangeMaxLeverage = 10.0,
    double quantityStep = 0.0,
    double minOrderQuantity = 0.0,
    double minNotional = 0.0,
    double tickSize = 0.0,
  }) {
    final double entry = (decision.entryLow + decision.entryHigh) / 2.0;
    final double atrPercent = entry <= 0 ? 0 : decision.atr / entry * 100.0;
    final double effectiveVolatility = volatilityPercent > 0
        ? volatilityPercent
        : atrPercent * 8.0;
    final SignalDirection direction = market.tradePlan.bias == Bias.bearish
        ? SignalDirection.short
        : SignalDirection.long;
    return SmartPositionInput(
      symbol: market.symbol,
      direction: direction,
      decisionAction: decision.decision,
      signalStage: decision.signalStage,
      currentPrice: decision.price,
      entryZoneLow: decision.entryLow,
      entryZoneHigh: decision.entryHigh,
      entry: entry,
      stop: decision.stop,
      tp1: decision.tp1,
      tp2: decision.tp2,
      confidence: decision.signalScore,
      atr: decision.atr,
      volatilityPercent: effectiveVolatility,
      marketRegime: decision.marketRegime,
      setupType: decision.selectedStrategy,
      allocatedMargin: allocatedMargin,
      riskPercent: riskPercent,
      exchangeMaxLeverage: exchangeMaxLeverage <= 0
          ? 10.0
          : exchangeMaxLeverage,
      quantityStep: quantityStep,
      minOrderQuantity: minOrderQuantity,
      minNotional: minNotional,
      tickSize: tickSize,
      observedSpreadPercent: market.ticker.spreadPercent,
      bidPrice: market.ticker.bidPrice,
      askPrice: market.ticker.askPrice,
      assetRiskClass: _classifyAsset(market.symbol),
      hasSharpImpulse: decision.expectedMovePercent >= 4.0 || atrPercent >= 2.0,
      isChaos: effectiveVolatility >= 30.0 || atrPercent >= 3.0,
    );
  }

  final String symbol;
  final SignalDirection direction;
  final DecisionAction decisionAction;
  final SignalStage signalStage;
  final double currentPrice;
  final double entryZoneLow;
  final double entryZoneHigh;
  final double entry;
  final double stop;
  final double tp1;
  final double tp2;
  final double? tp3;
  final int confidence;
  final double atr;
  final double volatilityPercent;
  final MarketRegimeHint marketRegime;
  final String setupType;
  final double allocatedMargin;
  final double riskPercent;
  final double targetMovePercent;
  final double exchangeMaxLeverage;
  final AssetRiskClass assetRiskClass;
  final bool hasSharpImpulse;
  final bool isChaos;
  final double quantityStep;
  final double minOrderQuantity;
  final double minNotional;
  final double tickSize;
  final double observedSpreadPercent;
  final double bidPrice;
  final double askPrice;
  final ExecutionPriceMode executionPriceMode;
  final List<double> targetAllocations;
  final int personalMaxLeverage;
  final bool highRiskLeverageEnabled;

  double get atrPercent => entry <= 0 ? 0 : atr / entry * 100.0;

  SmartPositionInput copyWith({
    double? entry,
    double? stop,
    double? tp1,
    double? tp2,
    double? tp3,
    bool clearTp3 = false,
    double? allocatedMargin,
    double? riskPercent,
    double? targetMovePercent,
    double? exchangeMaxLeverage,
    double? quantityStep,
    double? minOrderQuantity,
    double? minNotional,
    double? tickSize,
    double? observedSpreadPercent,
    double? bidPrice,
    double? askPrice,
    ExecutionPriceMode? executionPriceMode,
    List<double>? targetAllocations,
    int? personalMaxLeverage,
    bool? highRiskLeverageEnabled,
  }) {
    return SmartPositionInput(
      symbol: symbol,
      direction: direction,
      decisionAction: decisionAction,
      signalStage: signalStage,
      currentPrice: currentPrice,
      entryZoneLow: entryZoneLow,
      entryZoneHigh: entryZoneHigh,
      entry: entry ?? this.entry,
      stop: stop ?? this.stop,
      tp1: tp1 ?? this.tp1,
      tp2: tp2 ?? this.tp2,
      tp3: clearTp3 ? null : tp3 ?? this.tp3,
      confidence: confidence,
      atr: atr,
      volatilityPercent: volatilityPercent,
      marketRegime: marketRegime,
      setupType: setupType,
      allocatedMargin: allocatedMargin ?? this.allocatedMargin,
      riskPercent: riskPercent ?? this.riskPercent,
      targetMovePercent: targetMovePercent ?? this.targetMovePercent,
      exchangeMaxLeverage: exchangeMaxLeverage ?? this.exchangeMaxLeverage,
      assetRiskClass: assetRiskClass,
      hasSharpImpulse: hasSharpImpulse,
      isChaos: isChaos,
      quantityStep: quantityStep ?? this.quantityStep,
      minOrderQuantity: minOrderQuantity ?? this.minOrderQuantity,
      minNotional: minNotional ?? this.minNotional,
      tickSize: tickSize ?? this.tickSize,
      observedSpreadPercent:
          observedSpreadPercent ?? this.observedSpreadPercent,
      bidPrice: bidPrice ?? this.bidPrice,
      askPrice: askPrice ?? this.askPrice,
      executionPriceMode: executionPriceMode ?? this.executionPriceMode,
      targetAllocations: targetAllocations ?? this.targetAllocations,
      personalMaxLeverage: personalMaxLeverage ?? this.personalMaxLeverage,
      highRiskLeverageEnabled:
          highRiskLeverageEnabled ?? this.highRiskLeverageEnabled,
    );
  }
}

class CostBreakdown {
  const CostBreakdown({
    required this.entryFee,
    required this.exitFee,
    required this.spread,
    required this.slippage,
    required this.safetyBuffer,
  });

  final double entryFee;
  final double exitFee;
  final double spread;
  final double slippage;
  final double safetyBuffer;

  double get fees => entryFee + exitFee;
  double get cashCharges => fees + safetyBuffer;
  double get total => fees + spread + slippage + safetyBuffer;
}

class StopOutcome {
  const StopOutcome({
    required this.distancePercent,
    required this.movementLoss,
    required this.costs,
    required this.price,
    required this.effectivePrice,
  });

  final double distancePercent;
  final double movementLoss;
  final CostBreakdown costs;
  final double price;
  final double effectivePrice;

  double get expectedLoss => movementLoss + costs.cashCharges;
}

class TargetOutcome {
  const TargetOutcome({
    required this.label,
    required this.price,
    required this.effectivePrice,
    required this.allocationFraction,
    required this.movePercent,
    required this.idealGrossProfit,
    required this.grossProfit,
    required this.costs,
    required this.netProfit,
    required this.rawRiskReward,
    required this.netRiskReward,
    required this.costToGrossPercent,
    required this.verdict,
  });

  final String label;
  final double price;
  final double effectivePrice;
  final double allocationFraction;
  final double movePercent;
  final double idealGrossProfit;
  final double grossProfit;
  final CostBreakdown costs;
  final double netProfit;
  final double rawRiskReward;
  final double netRiskReward;
  final double costToGrossPercent;
  final TargetVerdict verdict;
}

class LeverageSafetyResult {
  const LeverageSafetyResult({
    required this.calculatedLeverage,
    required this.safetyLimit,
    required this.safeLeverage,
    required this.aggressiveLeverage,
    required this.dangerousFromLeverage,
    required this.recommendedLeverage,
    required this.personalMaxLeverage,
    required this.highRiskOverrideApplied,
    required this.estimatedLiquidationDistancePercent,
    required this.reasons,
  });

  final double calculatedLeverage;
  final int safetyLimit;
  final int safeLeverage;
  final int aggressiveLeverage;
  final int dangerousFromLeverage;
  final int recommendedLeverage;
  final int personalMaxLeverage;
  final bool highRiskOverrideApplied;
  final double estimatedLiquidationDistancePercent;
  final List<String> reasons;
}

class SmartTradePlan {
  const SmartTradePlan({
    required this.symbol,
    required this.side,
    required this.allocatedMargin,
    required this.entry,
    required this.effectiveEntry,
    required this.stop,
    required this.targets,
    required this.margin,
    required this.leverage,
    required this.quantity,
    required this.positionNotional,
    required this.maxLoss,
    required this.estimatedFees,
    required this.estimatedSlippage,
    required this.rawRiskReward,
    required this.netRiskReward,
    required this.weightedRawResultR,
    required this.weightedNetResultR,
    required this.partialNetProfit,
    required this.confidence,
    required this.setupType,
    required this.safetyStatus,
    required this.stopOutcome,
    required this.leverageSafety,
    required this.targetMoveOutcome,
    required this.explanation,
    required this.reasons,
    required this.validationIssues,
    required this.maxNotionalByRisk,
    required this.effectiveLossPercent,
  });

  final String symbol;
  final SignalDirection side;
  final double allocatedMargin;
  final double entry;
  final double effectiveEntry;
  final double stop;
  final List<TargetOutcome> targets;
  final double margin;
  final int leverage;
  final double quantity;
  final double positionNotional;
  final double maxLoss;
  final double estimatedFees;
  final double estimatedSlippage;
  final double rawRiskReward;
  final double netRiskReward;
  final double weightedRawResultR;
  final double weightedNetResultR;
  final double partialNetProfit;
  final int confidence;
  final String setupType;
  final TradeSafetyStatus safetyStatus;
  final StopOutcome stopOutcome;
  final LeverageSafetyResult leverageSafety;
  final TargetOutcome targetMoveOutcome;
  final List<String> explanation;
  final List<String> reasons;
  final List<TradeValidationIssue> validationIssues;
  final double maxNotionalByRisk;
  final double effectiveLossPercent;

  bool get isBlocked => safetyStatus == TradeSafetyStatus.blocked;
  bool get isValid => validationIssues.isEmpty;
}

AssetRiskClass _classifyAsset(String symbol) {
  final String base = symbol.toUpperCase().replaceFirst(RegExp(r'USDT$'), '');
  if (base == 'BTC' || base == 'ETH') return AssetRiskClass.major;
  const Set<String> speculative = <String>{
    'FARTCOIN',
    'DOGE',
    'SHIB',
    'PEPE',
    'BONK',
    'WIF',
    'FLOKI',
    'POPCAT',
    'MEME',
  };
  return speculative.contains(base)
      ? AssetRiskClass.speculative
      : AssetRiskClass.standard;
}

FeeOrderType _orderType(Object? raw, FeeOrderType fallback) {
  return FeeOrderType.values
          .where((FeeOrderType value) => value.name == '$raw')
          .firstOrNull ??
      fallback;
}

double _safePercent(Object? raw, double fallback) {
  final double? value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (value == null || !value.isFinite || value < 0 || value > 5) {
    return fallback;
  }
  return value;
}
