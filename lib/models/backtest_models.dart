import 'market_models.dart';
import 'execution_models.dart';
import 'first_move_models.dart';
import 'signal_models.dart';
import '../engines/first_move_probability_engine.dart';

class FactorPerformance {
  const FactorPerformance({
    required this.name,
    required this.trades,
    required this.winRate,
    required this.averageR,
  });

  final String name;
  final int trades;
  final double winRate;
  final double averageR;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'trades': trades,
    'winRate': winRate,
    'averageR': averageR,
  };

  factory FactorPerformance.fromJson(Map<String, dynamic> json) {
    return FactorPerformance(
      name: json['name']?.toString() ?? '',
      trades: _asInt(json['trades']),
      winRate: _asDouble(json['winRate']),
      averageR: _asDouble(json['averageR']),
    );
  }
}

class StrategyPerformance {
  const StrategyPerformance({
    required this.style,
    required this.signals,
    required this.trades,
    required this.winRate,
    required this.averageR,
    required this.profitFactor,
  });

  final SignalStyle style;
  final int signals;
  final int trades;
  final double winRate;
  final double averageR;
  final double profitFactor;

  Map<String, Object?> toJson() => <String, Object?>{
    'style': style.name,
    'signals': signals,
    'trades': trades,
    'winRate': winRate,
    'averageR': averageR,
    'profitFactor': profitFactor,
  };

  factory StrategyPerformance.fromJson(Map<String, dynamic> json) {
    return StrategyPerformance(
      style: _enumByName(
        SignalStyle.values,
        json['style'],
        SignalStyle.standard,
      ),
      signals: _asInt(json['signals']),
      trades: _asInt(json['trades']),
      winRate: _asDouble(json['winRate']),
      averageR: _asDouble(json['averageR']),
      profitFactor: _asDouble(json['profitFactor']),
    );
  }
}

class ExecutionPerformance {
  const ExecutionPerformance({
    required this.profileId,
    required this.label,
    required this.entryVariant,
    required this.stopVariant,
    required this.signals,
    required this.trades,
    required this.winRate,
    required this.averageR,
    required this.profitFactor,
    required this.maxDrawdownR,
    required this.stopThenTargetPercent,
    required this.trainTrades,
    required this.trainAverageR,
    required this.validationTrades,
    required this.validationAverageR,
    required this.outOfSampleTrades,
    required this.outOfSampleAverageR,
  });

  final String profileId;
  final String label;
  final EntryVariant entryVariant;
  final StopVariant stopVariant;
  final int signals;
  final int trades;
  final double winRate;
  final double averageR;
  final double profitFactor;
  final double maxDrawdownR;
  final double stopThenTargetPercent;
  final int trainTrades;
  final double trainAverageR;
  final int validationTrades;
  final double validationAverageR;
  final int outOfSampleTrades;
  final double outOfSampleAverageR;

  Map<String, Object?> toJson() => <String, Object?>{
    'profileId': profileId,
    'label': label,
    'entryVariant': entryVariant.name,
    'stopVariant': stopVariant.name,
    'signals': signals,
    'trades': trades,
    'winRate': winRate,
    'averageR': averageR,
    'profitFactor': profitFactor,
    'maxDrawdownR': maxDrawdownR,
    'stopThenTargetPercent': stopThenTargetPercent,
    'trainTrades': trainTrades,
    'trainAverageR': trainAverageR,
    'validationTrades': validationTrades,
    'validationAverageR': validationAverageR,
    'outOfSampleTrades': outOfSampleTrades,
    'outOfSampleAverageR': outOfSampleAverageR,
  };

  factory ExecutionPerformance.fromJson(Map<String, dynamic> json) {
    return ExecutionPerformance(
      profileId: json['profileId']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      entryVariant: enumByName(
        EntryVariant.values,
        json['entryVariant'],
        EntryVariant.bosConfirmation,
      ),
      stopVariant: enumByName(
        StopVariant.values,
        json['stopVariant'],
        StopVariant.structuralAtr,
      ),
      signals: _asInt(json['signals']),
      trades: _asInt(json['trades']),
      winRate: _asDouble(json['winRate']),
      averageR: _asDouble(json['averageR']),
      profitFactor: _asDouble(json['profitFactor']),
      maxDrawdownR: _asDouble(json['maxDrawdownR']),
      stopThenTargetPercent: _asDouble(json['stopThenTargetPercent']),
      trainTrades: _asInt(json['trainTrades']),
      trainAverageR: _asDouble(json['trainAverageR']),
      validationTrades: _asInt(json['validationTrades']),
      validationAverageR: _asDouble(json['validationAverageR']),
      outOfSampleTrades: _asInt(json['outOfSampleTrades']),
      outOfSampleAverageR: _asDouble(json['outOfSampleAverageR']),
    );
  }
}

class BacktestReport {
  const BacktestReport({
    required this.symbol,
    required this.startedAt,
    required this.finishedAt,
    required this.signals,
    required this.trades,
    required this.winRate,
    required this.tp1Percent,
    required this.tp2Percent,
    required this.stopPercent,
    required this.averageR,
    required this.profitFactor,
    required this.maxDrawdownR,
    required this.averageMovePercent,
    required this.averageTradeMinutes,
    required this.factors,
    this.rawAverageR = 0.0,
    this.netAverageR = 0.0,
    this.rawProfitFactor = 0.0,
    this.netProfitFactor = 0.0,
    this.rawMaxDrawdownR = 0.0,
    this.netMaxDrawdownR = 0.0,
    this.totalExecutionCosts = 0.0,
    this.costToGrossPercent = 0.0,
    this.stopThenTp1Percent = 0.0,
    this.stopThenTp2Percent = 0.0,
    this.averageStopOvershootAtr = 0.0,
    this.strategies = const <StrategyPerformance>[],
    this.reasonCodes = const <FactorPerformance>[],
    this.executionComparisons = const <ExecutionPerformance>[],
    this.firstMoveBuckets = const <FirstMoveHistoricalBucket>[],
    this.calibrationBuckets = const <ProbabilityCalibrationBucket>[],
  });

  final String symbol;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int signals;
  final int trades;
  final double winRate;
  final double tp1Percent;
  final double tp2Percent;
  final double stopPercent;
  final double averageR;
  final double profitFactor;
  final double maxDrawdownR;
  final double averageMovePercent;
  final double averageTradeMinutes;
  final double stopThenTp1Percent;
  final double stopThenTp2Percent;
  final double averageStopOvershootAtr;
  final List<FactorPerformance> factors;
  final double rawAverageR;
  final double netAverageR;
  final double rawProfitFactor;
  final double netProfitFactor;
  final double rawMaxDrawdownR;
  final double netMaxDrawdownR;
  final double totalExecutionCosts;
  final double costToGrossPercent;
  final List<StrategyPerformance> strategies;
  final List<FactorPerformance> reasonCodes;
  final List<ExecutionPerformance> executionComparisons;
  final List<FirstMoveHistoricalBucket> firstMoveBuckets;
  final List<ProbabilityCalibrationBucket> calibrationBuckets;

  factory BacktestReport.fromSignals({
    required String symbol,
    required DateTime startedAt,
    required DateTime finishedAt,
    required List<RadarSignal> source,
  }) {
    final List<RadarSignal> primarySignals = _primarySignals(source);
    final List<RadarSignal> trades = primarySignals
        .where((RadarSignal signal) => signal.entryTime != null)
        .toList(growable: false);
    final List<RadarSignal> finished = trades
        .where((RadarSignal signal) => !signal.status.isActive)
        .toList(growable: false);
    final int winners = finished
        .where((RadarSignal signal) => signal.resultR > 0.0)
        .length;
    final int tp1Hits = trades
        .where((RadarSignal signal) => signal.tp1Time != null)
        .length;
    final int tp2Hits = trades
        .where((RadarSignal signal) => signal.tp2Time != null)
        .length;
    final int stops = trades
        .where((RadarSignal signal) => signal.status == SignalStatus.stopped)
        .length;
    final List<RadarSignal> stoppedSignals = trades
        .where((RadarSignal signal) => signal.status == SignalStatus.stopped)
        .toList(growable: false);
    final double netProfitR = finished
        .where((RadarSignal signal) => signal.resultR > 0.0)
        .fold<double>(0.0, (double sum, RadarSignal signal) {
          return sum + signal.resultR;
        });
    final double netLossR = finished
        .where((RadarSignal signal) => signal.resultR < 0.0)
        .fold<double>(0.0, (double sum, RadarSignal signal) {
          return sum + signal.resultR.abs();
        });

    final List<double> netResults = finished
        .map<double>((RadarSignal signal) => signal.resultR)
        .toList(growable: false);
    final List<double> rawResults = finished
        .map<double>(
          (RadarSignal signal) =>
              signal.hasCostAwareResult ? signal.rawResultR : signal.resultR,
        )
        .toList(growable: false);
    final double rawProfitR = rawResults
        .where((double result) => result > 0.0)
        .fold<double>(0.0, (double sum, double result) => sum + result);
    final double rawLossR = rawResults
        .where((double result) => result < 0.0)
        .fold<double>(0.0, (double sum, double result) => sum + result.abs());
    final double totalExecutionCosts = finished.fold<double>(0.0, (
      double sum,
      RadarSignal signal,
    ) {
      return sum +
          signal.entryFee +
          signal.exitFees +
          signal.spreadCost +
          signal.slippageCost +
          signal.fundingCost;
    });
    final double positiveGrossPnl = finished
        .where((RadarSignal signal) => signal.grossPnl > 0.0)
        .fold<double>(
          0.0,
          (double sum, RadarSignal signal) => sum + signal.grossPnl,
        );
    final double rawAverageR = _average(rawResults);
    final double netAverageR = _average(netResults);
    final double rawProfitFactor = rawLossR == 0.0
        ? rawProfitR
        : rawProfitR / rawLossR;
    final double netProfitFactor = netLossR == 0.0
        ? netProfitR
        : netProfitR / netLossR;
    final double rawMaxDrawdown = _maxDrawdown(rawResults);
    final double netMaxDrawdown = _maxDrawdown(netResults);

    return BacktestReport(
      symbol: symbol,
      startedAt: startedAt,
      finishedAt: finishedAt,
      signals: primarySignals.length,
      trades: trades.length,
      winRate: _percent(winners, finished.length),
      tp1Percent: _percent(tp1Hits, trades.length),
      tp2Percent: _percent(tp2Hits, trades.length),
      stopPercent: _percent(stops, trades.length),
      averageR: netAverageR,
      profitFactor: netProfitFactor,
      maxDrawdownR: netMaxDrawdown,
      averageMovePercent: _average(
        trades.map<double>((RadarSignal signal) => signal.mfePercent),
      ),
      averageTradeMinutes: _average(
        finished.map<double>((RadarSignal signal) {
          return signal.tradeDuration?.inMinutes.toDouble() ?? 0.0;
        }),
      ),
      rawAverageR: rawAverageR,
      netAverageR: netAverageR,
      rawProfitFactor: rawProfitFactor,
      netProfitFactor: netProfitFactor,
      rawMaxDrawdownR: rawMaxDrawdown,
      netMaxDrawdownR: netMaxDrawdown,
      totalExecutionCosts: totalExecutionCosts,
      costToGrossPercent: positiveGrossPnl <= 0.0
          ? 0.0
          : totalExecutionCosts / positiveGrossPnl * 100.0,
      stopThenTp1Percent: _percent(
        stoppedSignals.where((RadarSignal signal) => signal.postStopTp1).length,
        stoppedSignals.length,
      ),
      stopThenTp2Percent: _percent(
        stoppedSignals.where((RadarSignal signal) => signal.postStopTp2).length,
        stoppedSignals.length,
      ),
      averageStopOvershootAtr: _average(
        stoppedSignals.map<double>((RadarSignal signal) => signal.overshootAtr),
      ),
      factors: _factorPerformance(finished),
      strategies: _strategyPerformance(primarySignals),
      reasonCodes: _reasonCodePerformance(finished),
      executionComparisons: _executionPerformance(source),
      firstMoveBuckets: FirstMoveProbabilityEngine.buildHistoricalBuckets(
        primarySignals,
      ),
      calibrationBuckets: FirstMoveProbabilityEngine.buildCalibrationBuckets(
        primarySignals,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'symbol': symbol,
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    'signals': signals,
    'trades': trades,
    'winRate': winRate,
    'tp1Percent': tp1Percent,
    'tp2Percent': tp2Percent,
    'stopPercent': stopPercent,
    'averageR': averageR,
    'profitFactor': profitFactor,
    'maxDrawdownR': maxDrawdownR,
    'averageMovePercent': averageMovePercent,
    'averageTradeMinutes': averageTradeMinutes,
    'rawAverageR': rawAverageR,
    'netAverageR': netAverageR,
    'rawProfitFactor': rawProfitFactor,
    'netProfitFactor': netProfitFactor,
    'rawMaxDrawdownR': rawMaxDrawdownR,
    'netMaxDrawdownR': netMaxDrawdownR,
    'totalExecutionCosts': totalExecutionCosts,
    'costToGrossPercent': costToGrossPercent,
    'stopThenTp1Percent': stopThenTp1Percent,
    'stopThenTp2Percent': stopThenTp2Percent,
    'averageStopOvershootAtr': averageStopOvershootAtr,
    'factors': factors
        .map<Map<String, Object?>>(
          (FactorPerformance factor) => factor.toJson(),
        )
        .toList(growable: false),
    'strategies': strategies
        .map<Map<String, Object?>>(
          (StrategyPerformance strategy) => strategy.toJson(),
        )
        .toList(growable: false),
    'reasonCodes': reasonCodes
        .map<Map<String, Object?>>(
          (FactorPerformance reason) => reason.toJson(),
        )
        .toList(growable: false),
    'executionComparisons': executionComparisons
        .map<Map<String, Object?>>(
          (ExecutionPerformance comparison) => comparison.toJson(),
        )
        .toList(growable: false),
    'firstMoveBuckets': firstMoveBuckets
        .map<Map<String, Object?>>(
          (FirstMoveHistoricalBucket bucket) => bucket.toJson(),
        )
        .toList(growable: false),
    'calibrationBuckets': calibrationBuckets
        .map<Map<String, Object?>>(
          (ProbabilityCalibrationBucket bucket) => bucket.toJson(),
        )
        .toList(growable: false),
  };

  factory BacktestReport.fromJson(Map<String, dynamic> json) {
    final Object? rawFactors = json['factors'];
    final Object? rawStrategies = json['strategies'];
    final Object? rawReasonCodes = json['reasonCodes'];
    final Object? rawExecutionComparisons = json['executionComparisons'];
    final Object? rawFirstMoveBuckets = json['firstMoveBuckets'];
    final Object? rawCalibrationBuckets = json['calibrationBuckets'];
    return BacktestReport(
      symbol: json['symbol']?.toString() ?? '',
      startedAt:
          DateTime.tryParse(json['startedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      finishedAt:
          DateTime.tryParse(json['finishedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      signals: _asInt(json['signals']),
      trades: _asInt(json['trades']),
      winRate: _asDouble(json['winRate']),
      tp1Percent: _asDouble(json['tp1Percent']),
      tp2Percent: _asDouble(json['tp2Percent']),
      stopPercent: _asDouble(json['stopPercent']),
      averageR: _asDouble(json['averageR']),
      profitFactor: _asDouble(json['profitFactor']),
      maxDrawdownR: _asDouble(json['maxDrawdownR']),
      averageMovePercent: _asDouble(json['averageMovePercent']),
      averageTradeMinutes: _asDouble(json['averageTradeMinutes']),
      rawAverageR: json.containsKey('rawAverageR')
          ? _asDouble(json['rawAverageR'])
          : _asDouble(json['averageR']),
      netAverageR: json.containsKey('netAverageR')
          ? _asDouble(json['netAverageR'])
          : _asDouble(json['averageR']),
      rawProfitFactor: json.containsKey('rawProfitFactor')
          ? _asDouble(json['rawProfitFactor'])
          : _asDouble(json['profitFactor']),
      netProfitFactor: json.containsKey('netProfitFactor')
          ? _asDouble(json['netProfitFactor'])
          : _asDouble(json['profitFactor']),
      rawMaxDrawdownR: json.containsKey('rawMaxDrawdownR')
          ? _asDouble(json['rawMaxDrawdownR'])
          : _asDouble(json['maxDrawdownR']),
      netMaxDrawdownR: json.containsKey('netMaxDrawdownR')
          ? _asDouble(json['netMaxDrawdownR'])
          : _asDouble(json['maxDrawdownR']),
      totalExecutionCosts: _asDouble(json['totalExecutionCosts']),
      costToGrossPercent: _asDouble(json['costToGrossPercent']),
      stopThenTp1Percent: _asDouble(json['stopThenTp1Percent']),
      stopThenTp2Percent: _asDouble(json['stopThenTp2Percent']),
      averageStopOvershootAtr: _asDouble(json['averageStopOvershootAtr']),
      factors: rawFactors is List<dynamic>
          ? rawFactors
                .whereType<Map<String, dynamic>>()
                .map<FactorPerformance>(FactorPerformance.fromJson)
                .toList(growable: false)
          : const <FactorPerformance>[],
      strategies: rawStrategies is List<dynamic>
          ? rawStrategies
                .whereType<Map<String, dynamic>>()
                .map<StrategyPerformance>(StrategyPerformance.fromJson)
                .toList(growable: false)
          : const <StrategyPerformance>[],
      reasonCodes: rawReasonCodes is List<dynamic>
          ? rawReasonCodes
                .whereType<Map<String, dynamic>>()
                .map<FactorPerformance>(FactorPerformance.fromJson)
                .toList(growable: false)
          : const <FactorPerformance>[],
      executionComparisons: rawExecutionComparisons is List<dynamic>
          ? rawExecutionComparisons
                .whereType<Map<String, dynamic>>()
                .map<ExecutionPerformance>(ExecutionPerformance.fromJson)
                .toList(growable: false)
          : const <ExecutionPerformance>[],
      firstMoveBuckets: rawFirstMoveBuckets is List<dynamic>
          ? rawFirstMoveBuckets
                .whereType<Map<String, dynamic>>()
                .map<FirstMoveHistoricalBucket>(
                  FirstMoveHistoricalBucket.fromJson,
                )
                .toList(growable: false)
          : const <FirstMoveHistoricalBucket>[],
      calibrationBuckets: rawCalibrationBuckets is List<dynamic>
          ? rawCalibrationBuckets
                .whereType<Map<String, dynamic>>()
                .map<ProbabilityCalibrationBucket>(
                  ProbabilityCalibrationBucket.fromJson,
                )
                .toList(growable: false)
          : const <ProbabilityCalibrationBucket>[],
    );
  }
}

class JournalStatistics {
  const JournalStatistics({
    required this.signals,
    required this.trades,
    required this.active,
    required this.winRate,
    required this.averageR,
    required this.tp1Percent,
    required this.tp2Percent,
    required this.stopPercent,
    required this.stopThenTargetPercent,
    required this.averageStopOvershootAtr,
  });

  final int signals;
  final int trades;
  final int active;
  final double winRate;
  final double averageR;
  final double tp1Percent;
  final double tp2Percent;
  final double stopPercent;
  final double stopThenTargetPercent;
  final double averageStopOvershootAtr;

  factory JournalStatistics.fromSignals(List<RadarSignal> source) {
    final List<RadarSignal> trades = source
        .where((RadarSignal signal) => signal.entryTime != null)
        .toList(growable: false);
    final List<RadarSignal> finished = trades
        .where((RadarSignal signal) => !signal.status.isActive)
        .toList(growable: false);
    final List<RadarSignal> stopped = trades
        .where((RadarSignal signal) => signal.status == SignalStatus.stopped)
        .toList(growable: false);
    return JournalStatistics(
      signals: source.length,
      trades: trades.length,
      active: source
          .where((RadarSignal signal) => signal.status.isActive)
          .length,
      winRate: _percent(
        finished.where((RadarSignal signal) => signal.resultR > 0.0).length,
        finished.length,
      ),
      averageR: _average(
        finished.map<double>((RadarSignal signal) => signal.resultR),
      ),
      tp1Percent: _percent(
        trades.where((RadarSignal signal) => signal.tp1Time != null).length,
        trades.length,
      ),
      tp2Percent: _percent(
        trades.where((RadarSignal signal) => signal.tp2Time != null).length,
        trades.length,
      ),
      stopPercent: _percent(
        trades
            .where(
              (RadarSignal signal) => signal.status == SignalStatus.stopped,
            )
            .length,
        trades.length,
      ),
      stopThenTargetPercent: _percent(
        stopped.where((RadarSignal signal) => signal.stopThenTarget).length,
        stopped.length,
      ),
      averageStopOvershootAtr: _average(
        stopped.map<double>((RadarSignal signal) => signal.overshootAtr),
      ),
    );
  }
}

List<FactorPerformance> _factorPerformance(List<RadarSignal> signals) {
  final Map<String, Bias Function(RadarSignal)> selectors =
      <String, Bias Function(RadarSignal)>{
        'RSI': (RadarSignal signal) => signal.rsi >= 55.0
            ? Bias.bullish
            : signal.rsi <= 45.0
            ? Bias.bearish
            : Bias.neutral,
        'MACD': (RadarSignal signal) => signal.macd > 0.0
            ? Bias.bullish
            : signal.macd < 0.0
            ? Bias.bearish
            : Bias.neutral,
        'EMA': (RadarSignal signal) {
          if (signal.ema20 > signal.ema50 && signal.ema50 > signal.ema200) {
            return Bias.bullish;
          }
          if (signal.ema20 < signal.ema50 && signal.ema50 < signal.ema200) {
            return Bias.bearish;
          }
          return Bias.neutral;
        },
        'RVOL': (RadarSignal signal) => signal.rvolBias,
        'BOS/CHOCH': (RadarSignal signal) =>
            signal.choch == Bias.neutral ? signal.bos : signal.choch,
        'FVG': (RadarSignal signal) => signal.fvgBias,
        'Order Block': (RadarSignal signal) => signal.orderBlockBias,
        'Liquidity Sweep': (RadarSignal signal) => signal.liquidityBias,
      };

  return selectors.entries
      .map<FactorPerformance>((
        MapEntry<String, Bias Function(RadarSignal)> entry,
      ) {
        final List<RadarSignal> aligned = signals
            .where((RadarSignal signal) {
              final Bias factorBias = entry.value(signal);
              return factorBias != Bias.neutral &&
                  factorBias == signal.direction.bias;
            })
            .toList(growable: false);
        return FactorPerformance(
          name: entry.key,
          trades: aligned.length,
          winRate: _percent(
            aligned.where((RadarSignal signal) => signal.resultR > 0.0).length,
            aligned.length,
          ),
          averageR: _average(
            aligned.map<double>((RadarSignal signal) => signal.resultR),
          ),
        );
      })
      .toList(growable: false);
}

List<StrategyPerformance> _strategyPerformance(List<RadarSignal> source) {
  return SignalStyle.values
      .map<StrategyPerformance>((SignalStyle style) {
        final List<RadarSignal> signals = source
            .where((RadarSignal signal) => signal.style == style)
            .toList(growable: false);
        final List<RadarSignal> trades = signals
            .where((RadarSignal signal) => signal.entryTime != null)
            .toList(growable: false);
        final List<RadarSignal> finished = trades
            .where((RadarSignal signal) => !signal.status.isActive)
            .toList(growable: false);
        final double grossProfit = finished
            .where((RadarSignal signal) => signal.resultR > 0.0)
            .fold<double>(
              0.0,
              (double sum, RadarSignal signal) => sum + signal.resultR,
            );
        final double grossLoss = finished
            .where((RadarSignal signal) => signal.resultR < 0.0)
            .fold<double>(
              0.0,
              (double sum, RadarSignal signal) => sum + signal.resultR.abs(),
            );
        return StrategyPerformance(
          style: style,
          signals: signals.length,
          trades: trades.length,
          winRate: _percent(
            finished.where((RadarSignal signal) => signal.resultR > 0.0).length,
            finished.length,
          ),
          averageR: _average(
            finished.map<double>((RadarSignal signal) => signal.resultR),
          ),
          profitFactor: grossLoss == 0.0
              ? grossProfit
              : grossProfit / grossLoss,
        );
      })
      .toList(growable: false);
}

List<RadarSignal> _primarySignals(List<RadarSignal> source) {
  final String primaryId = ExecutionProfile.backtestProfiles
      .firstWhere((ExecutionProfile profile) => profile.isPrimary)
      .id;
  final List<RadarSignal> primary = source
      .where((RadarSignal signal) => signal.executionProfileId == primaryId)
      .toList(growable: false);
  if (primary.isNotEmpty) {
    return primary;
  }
  final List<RadarSignal> live = source
      .where(
        (RadarSignal signal) => signal.executionProfileId == 'live_confirmed',
      )
      .toList(growable: false);
  return live.isNotEmpty ? live : source;
}

List<ExecutionPerformance> _executionPerformance(List<RadarSignal> source) {
  return ExecutionProfile.backtestProfiles
      .map<ExecutionPerformance>((ExecutionProfile profile) {
        final List<RadarSignal> signals = source
            .where(
              (RadarSignal signal) => signal.executionProfileId == profile.id,
            )
            .toList(growable: false);
        final List<RadarSignal> trades = signals
            .where((RadarSignal signal) => signal.entryTime != null)
            .toList(growable: false);
        final List<RadarSignal> finished = trades
            .where((RadarSignal signal) => !signal.status.isActive)
            .toList(growable: false);
        final List<RadarSignal> stopped = trades
            .where(
              (RadarSignal signal) => signal.status == SignalStatus.stopped,
            )
            .toList(growable: false);
        final List<RadarSignal> chronological = List<RadarSignal>.of(finished)
          ..sort(
            (RadarSignal first, RadarSignal second) =>
                first.time.compareTo(second.time),
          );
        final int trainEnd = (chronological.length * 0.60).floor();
        final int validationEnd = (chronological.length * 0.80).floor();
        final List<RadarSignal> train = chronological.sublist(0, trainEnd);
        final List<RadarSignal> validation = chronological.sublist(
          trainEnd,
          validationEnd,
        );
        final List<RadarSignal> outOfSample = chronological.sublist(
          validationEnd,
        );
        final double grossProfit = finished
            .where((RadarSignal signal) => signal.resultR > 0.0)
            .fold<double>(
              0.0,
              (double total, RadarSignal signal) => total + signal.resultR,
            );
        final double grossLoss = finished
            .where((RadarSignal signal) => signal.resultR < 0.0)
            .fold<double>(
              0.0,
              (double total, RadarSignal signal) =>
                  total + signal.resultR.abs(),
            );
        double equity = 0.0;
        double peak = 0.0;
        double maximumDrawdown = 0.0;
        for (final RadarSignal signal in finished) {
          equity += signal.resultR;
          if (equity > peak) {
            peak = equity;
          }
          final double drawdown = peak - equity;
          if (drawdown > maximumDrawdown) {
            maximumDrawdown = drawdown;
          }
        }
        return ExecutionPerformance(
          profileId: profile.id,
          label: profile.label,
          entryVariant: profile.entryVariant,
          stopVariant: profile.stopVariant,
          signals: signals.length,
          trades: trades.length,
          winRate: _percent(
            finished.where((RadarSignal signal) => signal.resultR > 0.0).length,
            finished.length,
          ),
          averageR: _average(
            finished.map<double>((RadarSignal signal) => signal.resultR),
          ),
          profitFactor: grossLoss == 0.0
              ? grossProfit
              : grossProfit / grossLoss,
          maxDrawdownR: maximumDrawdown,
          stopThenTargetPercent: _percent(
            stopped.where((RadarSignal signal) => signal.stopThenTarget).length,
            stopped.length,
          ),
          trainTrades: train.length,
          trainAverageR: _average(
            train.map<double>((RadarSignal signal) => signal.resultR),
          ),
          validationTrades: validation.length,
          validationAverageR: _average(
            validation.map<double>((RadarSignal signal) => signal.resultR),
          ),
          outOfSampleTrades: outOfSample.length,
          outOfSampleAverageR: _average(
            outOfSample.map<double>((RadarSignal signal) => signal.resultR),
          ),
        );
      })
      .toList(growable: false);
}

List<FactorPerformance> _reasonCodePerformance(List<RadarSignal> signals) {
  final Set<String> allCodes = <String>{};
  for (final RadarSignal signal in signals) {
    allCodes.addAll(signal.reasonCodes);
  }
  final List<String> sortedCodes = allCodes.toList(growable: false)..sort();
  return sortedCodes
      .map<FactorPerformance>((String code) {
        final List<RadarSignal> matching = signals
            .where((RadarSignal signal) => signal.reasonCodes.contains(code))
            .toList(growable: false);
        return FactorPerformance(
          name: code,
          trades: matching.length,
          winRate: _percent(
            matching.where((RadarSignal signal) => signal.resultR > 0.0).length,
            matching.length,
          ),
          averageR: _average(
            matching.map<double>((RadarSignal signal) => signal.resultR),
          ),
        );
      })
      .toList(growable: false);
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  final String name = raw?.toString() ?? '';
  for (final T value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return fallback;
}

double _average(Iterable<double> values) {
  double sum = 0.0;
  int count = 0;
  for (final double value in values) {
    sum += value;
    count++;
  }
  return count == 0 ? 0.0 : sum / count;
}

double _maxDrawdown(Iterable<double> chronologicalResults) {
  double equity = 0.0;
  double peak = 0.0;
  double maximum = 0.0;
  for (final double result in chronologicalResults) {
    equity += result;
    if (equity > peak) peak = equity;
    final double drawdown = peak - equity;
    if (drawdown > maximum) maximum = drawdown;
  }
  return maximum;
}

double _percent(int part, int total) {
  return total == 0 ? 0.0 : part / total * 100.0;
}

double _asDouble(Object? value) {
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

int _asInt(Object? value) {
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
