import 'market_models.dart';

enum DecisionAction { long, short, wait }

extension DecisionActionText on DecisionAction {
  String get label {
    switch (this) {
      case DecisionAction.long:
        return 'LONG';
      case DecisionAction.short:
        return 'SHORT';
      case DecisionAction.wait:
        return 'WAIT';
    }
  }

  Bias get bias {
    switch (this) {
      case DecisionAction.long:
        return Bias.bullish;
      case DecisionAction.short:
        return Bias.bearish;
      case DecisionAction.wait:
        return Bias.neutral;
    }
  }
}

enum EntryDecision { enterNow, waitForZone, tooLate }

extension EntryDecisionText on EntryDecision {
  String get label {
    switch (this) {
      case EntryDecision.enterNow:
        return 'ENTER NOW';
      case EntryDecision.waitForZone:
        return 'WAIT FOR ENTRY ZONE';
      case EntryDecision.tooLate:
        return 'ENTRY TOO LATE';
    }
  }
}

enum MarketRegimeHint { trendUp, trendDown, range, mixed }

extension MarketRegimeHintText on MarketRegimeHint {
  String get label {
    switch (this) {
      case MarketRegimeHint.trendUp:
        return 'TREND UP';
      case MarketRegimeHint.trendDown:
        return 'TREND DOWN';
      case MarketRegimeHint.range:
        return 'RANGE';
      case MarketRegimeHint.mixed:
        return 'MIXED / UNCERTAIN';
    }
  }
}

enum DataQuality { high, medium, low }

extension DataQualityText on DataQuality {
  String get label => name.toUpperCase();
}

enum ReasonSeverity { supporting, warning, invalidation }

enum ReasonCode {
  bullish1mStructure,
  bearish1mStructure,
  bullish5mStructure,
  bearish5mStructure,
  bullish15mStructure,
  bearish15mStructure,
  bullish1hStructure,
  bearish1hStructure,
  bullish5mCorrection,
  bearish5mCorrection,
  correctionNotFinished,
  bosConfirmed,
  chochWarning,
  bullishChoch,
  bearishChoch,
  strongResistanceAbove,
  strongSupportBelow,
  bearishOrderBlock,
  bullishOrderBlock,
  fvgConfluence,
  liquidityAbove,
  liquidityBelow,
  liquiditySweep,
  rvolHigh,
  rvolLow,
  rvolAverage,
  atrHigh,
  entryTooLate,
  entryAtGoodZone,
  waitForEntryZone,
  riskRewardPoor,
  riskRewardGood,
  timeframeConflict,
  newsRiskHigh,
  noStructureConfirmation,
  noTradeConditions,
  macdAligned,
  macdOpposes,
  rsiAligned,
  rsiOverextended,
  emaAligned,
  emaOpposes,
  dataQualityLow,
  invalidationAboveStop,
  invalidationBelowStop,
  closeAboveResistance,
  closeBelowSupport,
}

extension ReasonCodeWire on ReasonCode {
  String get code {
    switch (this) {
      case ReasonCode.bullish1mStructure:
        return 'BULLISH_1M_STRUCTURE';
      case ReasonCode.bearish1mStructure:
        return 'BEARISH_1M_STRUCTURE';
      case ReasonCode.bullish5mStructure:
        return 'BULLISH_5M_STRUCTURE';
      case ReasonCode.bearish5mStructure:
        return 'BEARISH_5M_STRUCTURE';
      case ReasonCode.bullish15mStructure:
        return 'BULLISH_15M_STRUCTURE';
      case ReasonCode.bearish15mStructure:
        return 'BEARISH_15M_STRUCTURE';
      case ReasonCode.bullish1hStructure:
        return 'BULLISH_1H_STRUCTURE';
      case ReasonCode.bearish1hStructure:
        return 'BEARISH_1H_STRUCTURE';
      case ReasonCode.bullish5mCorrection:
        return 'BULLISH_5M_CORRECTION';
      case ReasonCode.bearish5mCorrection:
        return 'BEARISH_5M_CORRECTION';
      case ReasonCode.correctionNotFinished:
        return 'CORRECTION_NOT_FINISHED';
      case ReasonCode.bosConfirmed:
        return 'BOS_CONFIRMED';
      case ReasonCode.chochWarning:
        return 'CHOCH_WARNING';
      case ReasonCode.bullishChoch:
        return 'BULLISH_CHOCH';
      case ReasonCode.bearishChoch:
        return 'BEARISH_CHOCH';
      case ReasonCode.strongResistanceAbove:
        return 'STRONG_RESISTANCE_ABOVE';
      case ReasonCode.strongSupportBelow:
        return 'STRONG_SUPPORT_BELOW';
      case ReasonCode.bearishOrderBlock:
        return 'BEARISH_ORDER_BLOCK';
      case ReasonCode.bullishOrderBlock:
        return 'BULLISH_ORDER_BLOCK';
      case ReasonCode.fvgConfluence:
        return 'FVG_CONFLUENCE';
      case ReasonCode.liquidityAbove:
        return 'LIQUIDITY_ABOVE';
      case ReasonCode.liquidityBelow:
        return 'LIQUIDITY_BELOW';
      case ReasonCode.liquiditySweep:
        return 'LIQUIDITY_SWEEP';
      case ReasonCode.rvolHigh:
        return 'RVOL_HIGH';
      case ReasonCode.rvolLow:
        return 'RVOL_LOW';
      case ReasonCode.rvolAverage:
        return 'RVOL_AVERAGE';
      case ReasonCode.atrHigh:
        return 'ATR_HIGH';
      case ReasonCode.entryTooLate:
        return 'ENTRY_TOO_LATE';
      case ReasonCode.entryAtGoodZone:
        return 'ENTRY_AT_GOOD_ZONE';
      case ReasonCode.waitForEntryZone:
        return 'WAIT_FOR_ENTRY_ZONE';
      case ReasonCode.riskRewardPoor:
        return 'RISK_REWARD_POOR';
      case ReasonCode.riskRewardGood:
        return 'RISK_REWARD_GOOD';
      case ReasonCode.timeframeConflict:
        return 'TIMEFRAME_CONFLICT';
      case ReasonCode.newsRiskHigh:
        return 'NEWS_RISK_HIGH';
      case ReasonCode.noStructureConfirmation:
        return 'NO_STRUCTURE_CONFIRMATION';
      case ReasonCode.noTradeConditions:
        return 'NO_TRADE_CONDITIONS';
      case ReasonCode.macdAligned:
        return 'MACD_ALIGNED';
      case ReasonCode.macdOpposes:
        return 'MACD_OPPOSES';
      case ReasonCode.rsiAligned:
        return 'RSI_ALIGNED';
      case ReasonCode.rsiOverextended:
        return 'RSI_OVEREXTENDED';
      case ReasonCode.emaAligned:
        return 'EMA_ALIGNED';
      case ReasonCode.emaOpposes:
        return 'EMA_OPPOSES';
      case ReasonCode.dataQualityLow:
        return 'DATA_QUALITY_LOW';
      case ReasonCode.invalidationAboveStop:
        return 'INVALIDATION_ABOVE_STOP';
      case ReasonCode.invalidationBelowStop:
        return 'INVALIDATION_BELOW_STOP';
      case ReasonCode.closeAboveResistance:
        return 'CLOSE_ABOVE_RESISTANCE';
      case ReasonCode.closeBelowSupport:
        return 'CLOSE_BELOW_SUPPORT';
    }
  }

  static ReasonCode? fromCode(String value) {
    for (final ReasonCode reason in ReasonCode.values) {
      if (reason.code == value) {
        return reason;
      }
    }
    return null;
  }
}

class DecisionReason {
  const DecisionReason({
    required this.code,
    required this.title,
    required this.detail,
    required this.severity,
  });

  final ReasonCode code;
  final String title;
  final String detail;
  final ReasonSeverity severity;
}

class DecisionSnapshot {
  const DecisionSnapshot({
    required this.symbol,
    required this.timestamp,
    required this.price,
    required this.decision,
    required this.signalScore,
    required this.marketRegime,
    required this.selectedStrategy,
    required this.entryDecision,
    required this.entryLow,
    required this.entryHigh,
    required this.stop,
    required this.tp1,
    required this.tp2,
    required this.riskReward,
    required this.leverage,
    required this.expectedMovePercent,
    required this.priceMagnet,
    required this.timeframeTrends,
    required this.correctionState,
    required this.bos,
    required this.choch,
    required this.support,
    required this.resistance,
    required this.orderBlocks,
    required this.fairValueGaps,
    required this.liquidity,
    required this.atr,
    required this.relativeVolume,
    required this.rsi,
    required this.macd,
    required this.ema20,
    required this.ema50,
    required this.ema200,
    required this.dataQuality,
    required this.reasonCodes,
    required this.warningCodes,
    required this.invalidationCodes,
    this.breakoutScore,
    this.rejectionScore,
    this.newsRisk = 'NOT_CONNECTED',
  });

  final String symbol;
  final DateTime timestamp;
  final double price;
  final DecisionAction decision;
  final int signalScore;
  final MarketRegimeHint marketRegime;
  final String selectedStrategy;
  final EntryDecision entryDecision;
  final double entryLow;
  final double entryHigh;
  final double stop;
  final double tp1;
  final double tp2;
  final double riskReward;
  final int leverage;
  final double expectedMovePercent;
  final double priceMagnet;
  final Map<String, Bias> timeframeTrends;
  final String correctionState;
  final Bias bos;
  final Bias choch;
  final double? support;
  final double? resistance;
  final List<PriceZone> orderBlocks;
  final List<PriceZone> fairValueGaps;
  final LiquidityResult liquidity;
  final double atr;
  final double relativeVolume;
  final double rsi;
  final MacdResult macd;
  final double ema20;
  final double ema50;
  final double ema200;
  final int? breakoutScore;
  final int? rejectionScore;
  final String newsRisk;
  final DataQuality dataQuality;
  final List<ReasonCode> reasonCodes;
  final List<ReasonCode> warningCodes;
  final List<ReasonCode> invalidationCodes;

  List<String> get persistedReasonCodes => <String>{
    ...reasonCodes.map<String>((ReasonCode reason) => reason.code),
    ...warningCodes.map<String>((ReasonCode reason) => reason.code),
    ...invalidationCodes.map<String>((ReasonCode reason) => reason.code),
  }.toList(growable: false);
}

class DecisionExplanation {
  const DecisionExplanation({
    required this.whatIsHappening,
    required this.whyDecision,
    required this.supporting,
    required this.opposing,
    required this.whatWeWaitFor,
    required this.entryExplanation,
    required this.stopExplanation,
    required this.targetExplanation,
    required this.invalidation,
    required this.whatChangesMind,
    required this.riskNotice,
  });

  final String whatIsHappening;
  final String whyDecision;
  final List<DecisionReason> supporting;
  final List<DecisionReason> opposing;
  final List<String> whatWeWaitFor;
  final String entryExplanation;
  final String stopExplanation;
  final String targetExplanation;
  final List<String> invalidation;
  final List<String> whatChangesMind;
  final String riskNotice;
}
