import '../models/backtest_models.dart';
import '../models/execution_models.dart';
import '../models/execution_simulation_models.dart';
import '../models/historical_data_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import '../services/bybit_service.dart';
import '../services/historical_data_store.dart';
import '../utils/exchange_decimal.dart';
import 'decision_engine.dart';
import 'execution_simulator.dart';
import 'first_move_probability_engine.dart';
import 'phase_a_engine.dart';
import 'signal_engine.dart';
import 'trade_outcome_classifier.dart';
import 'trade_tracker.dart';

class BacktestEngine {
  BacktestEngine({
    required this.bybitService,
    this.tradeTracker = const TradeTracker(),
    HistoricalDataStore? historicalDataStore,
  }) : historicalDataStore =
           historicalDataStore ?? HistoricalDataStore(provider: bybitService);

  final BybitService bybitService;
  final TradeTracker tradeTracker;
  final HistoricalDataStore historicalDataStore;
  static const FeeModel _feeModel = FeeModel();

  Future<BacktestReport> run(String symbol) async {
    final DateTime asOf = DateTime.now().toUtc();
    final Future<InstrumentTradingRules?> rulesFuture = bybitService
        .loadTradingRules(symbol);
    final Future<HistoricalDataSet> oneFuture = historicalDataStore.loadRange(
      symbol,
      '1',
      start: asOf.subtract(const Duration(minutes: 5000)),
      end: asOf,
      asOf: asOf,
    );
    final Future<HistoricalDataSet> fiveFuture = historicalDataStore.loadRange(
      symbol,
      '5',
      start: asOf.subtract(const Duration(minutes: 5000)),
      end: asOf,
      asOf: asOf,
    );
    final Future<HistoricalDataSet> fifteenFuture = historicalDataStore
        .loadRange(
          symbol,
          '15',
          start: asOf.subtract(const Duration(minutes: 15000)),
          end: asOf,
          asOf: asOf,
        );
    final Future<HistoricalDataSet> hourFuture = historicalDataStore.loadRange(
      symbol,
      '60',
      start: asOf.subtract(const Duration(hours: 1000)),
      end: asOf,
      asOf: asOf,
    );
    final List<Candle> one = (await oneFuture).candles;
    final List<Candle> five = (await fiveFuture).candles;
    final List<Candle> fifteen = (await fifteenFuture).candles;
    final List<Candle> hour = (await hourFuture).candles;
    final InstrumentTradingRules? tradingRules = await rulesFuture;
    if (one.length < 1000 ||
        five.length < 240 ||
        fifteen.length < 240 ||
        hour.length < 240) {
      throw Exception('Недостаточно истории $symbol для backtest');
    }

    final List<RadarSignal> signals = <RadarSignal>[];
    final Map<String, DateTime> previousSetups = <String, DateTime>{};
    final int firstIndex = one.length > 4000 ? one.length - 4000 : 200;

    for (int index = firstIndex; index < one.length; index++) {
      final Candle currentCandle = one[index];

      // Signals are tracked using only the candle that has just closed.
      for (int signalIndex = 0; signalIndex < signals.length; signalIndex++) {
        if (signals[signalIndex].status.isActive ||
            signals[signalIndex].needsPostStopTracking) {
          signals[signalIndex] = tradeTracker.consume(
            signals[signalIndex],
            currentCandle,
          );
        }
      }

      final DateTime baseClose = currentCandle.time.add(
        const Duration(minutes: 1),
      );
      final List<Candle> oneWindow = _takeLast(one.sublist(0, index + 1), 240);
      final List<Candle> fiveWindow = _closedWindow(
        five,
        baseClose,
        const Duration(minutes: 5),
      );
      final List<Candle> fifteenWindow = _closedWindow(
        fifteen,
        baseClose,
        const Duration(minutes: 15),
      );
      final List<Candle> hourWindow = _closedWindow(
        hour,
        baseClose,
        const Duration(hours: 1),
      );
      if (oneWindow.length < 200 ||
          fiveWindow.length < 200 ||
          fifteenWindow.length < 200 ||
          hourWindow.length < 200) {
        continue;
      }

      final double price = currentCandle.close;
      final double firstPrice = fiveWindow.first.close;
      final double change = firstPrice == 0.0
          ? 0.0
          : (price - firstPrice) / firstPrice * 100.0;
      final double turnover = fiveWindow.fold<double>(
        0.0,
        (double sum, Candle candle) => sum + candle.volume * candle.close,
      );
      final MarketSnapshot snapshot = SignalEngine.buildSnapshot(
        symbol: symbol,
        ticker: TickerStats(
          price: price,
          change24hPercent: change,
          turnover24h: turnover,
          sourceUpdatedAt: baseClose,
        ),
        oneCandles: oneWindow,
        fiveCandles: fiveWindow,
        fifteenCandles: fifteenWindow,
        hourCandles: hourWindow,
        tradingRules: tradingRules,
        observedAt: baseClose,
        requireFreshBidAsk: false,
      );
      final bool standardBoundary = baseClose.minute % 15 == 0;
      for (int signalIndex = 0; signalIndex < signals.length; signalIndex++) {
        if (signals[signalIndex].status == SignalStatus.waitingEntry) {
          signals[signalIndex] = PhaseAEngine.update(
            market: snapshot,
            signal: signals[signalIndex],
            feeModel: _feeModel,
          );
          signals[signalIndex] =
              FirstMoveProbabilityEngine.attachHistoricalProfile(
                signal: signals[signalIndex],
                historicalSignals: _profileHistory(
                  signals,
                  signals[signalIndex].executionProfileId,
                ),
                asOf: baseClose,
              );
        }
      }
      final List<RadarSignal?> candidates = <RadarSignal?>[
        if (standardBoundary)
          SignalEngine.createSignal(snapshot, signalTime: baseClose),
        SignalEngine.createScalpSignal(snapshot, signalTime: baseClose),
      ];
      for (final RadarSignal? baseCandidate in candidates) {
        if (baseCandidate == null) {
          continue;
        }
        for (final ExecutionProfile profile
            in ExecutionProfile.backtestProfiles) {
          final bool profileActive = signals.any(
            (RadarSignal signal) =>
                signal.style == baseCandidate.style &&
                signal.executionProfileId == profile.id &&
                signal.status.isActive,
          );
          if (profileActive) {
            continue;
          }
          final RadarSignal enrichedCandidate = baseCandidate.copyWith(
            reasonCodes: DecisionEngine.persistedReasonCodesForSignal(
              baseCandidate,
            ),
          );
          RadarSignal candidate = PhaseAEngine.prepare(
            market: snapshot,
            signal: enrichedCandidate,
            entryVariant: profile.entryVariant,
            stopVariant: profile.stopVariant,
            profileId: profile.id,
            feeModel: _feeModel,
          );
          candidate = FirstMoveProbabilityEngine.attachHistoricalProfile(
            signal: candidate,
            historicalSignals: _profileHistory(signals, profile.id),
            asOf: baseClose,
          );
          final String setupKey =
              '${profile.id}:${candidate.style.name}:'
              '${candidate.direction.name}';
          final DateTime? previousSetupTime = previousSetups[setupKey];
          final Duration cooldown = candidate.style == SignalStyle.scalp
              ? const Duration(minutes: 10)
              : const Duration(hours: 1);
          final bool repeatedSetup =
              previousSetupTime != null &&
              baseClose.difference(previousSetupTime) < cooldown;
          if (!repeatedSetup) {
            signals.add(candidate);
            previousSetups[setupKey] = baseClose;
          }
        }
      }
    }

    final Candle finalCandle = one.last;
    for (int index = 0; index < signals.length; index++) {
      if (signals[index].status.isActive) {
        signals[index] = tradeTracker.closeAtEnd(signals[index], finalCandle);
      }
    }
    if (tradingRules != null && tradingRules.isComplete) {
      for (int index = 0; index < signals.length; index++) {
        final RadarSignal signal = signals[index];
        if (signal.entryTime == null) continue;
        signals[index] = _applyCostAwareResult(
          signal: signal,
          candles: _candlesFrom(one, signal.entryTime!),
          tradingRules: tradingRules,
        );
      }
    }

    final DateTime startedAt = one[firstIndex].time;
    final DateTime finishedAt = finalCandle.time.add(
      const Duration(minutes: 1),
    );
    return BacktestReport.fromSignals(
      symbol: symbol,
      startedAt: startedAt,
      finishedAt: finishedAt,
      source: signals,
    );
  }

  List<Candle> _closedWindow(
    List<Candle> candles,
    DateTime evaluationTime,
    Duration timeframe,
  ) {
    final List<Candle> closed = <Candle>[];
    for (final Candle candle in candles) {
      if (!candle.time.add(timeframe).isAfter(evaluationTime)) {
        closed.add(candle);
      }
    }
    return _takeLast(closed, 240);
  }

  List<Candle> _takeLast(List<Candle> candles, int count) {
    if (candles.length <= count) {
      return List<Candle>.of(candles, growable: false);
    }
    return candles.sublist(candles.length - count, candles.length);
  }

  RadarSignal _applyCostAwareResult({
    required RadarSignal signal,
    required List<Candle> candles,
    required InstrumentTradingRules tradingRules,
  }) {
    final double quantity = _standardizedQuantity(signal, tradingRules);
    final ExecutionSimulationResult result = ExecutionSimulator.simulate(
      ExecutionSimulationInput(
        signal: signal,
        candles: candles,
        quantity: quantity,
        instrumentRules: tradingRules,
        feeModel: _feeModel,
        entryOrderType: SimulationOrderType.market,
        targetOrderType: SimulationOrderType.market,
        stopOrderType: SimulationOrderType.market,
        eligibleFrom: signal.entryTime,
      ),
    );
    if (result.status == SimulatedExecutionStatus.invalid ||
        result.status == SimulatedExecutionStatus.noEntry) {
      final List<String> reasons = <String>[
        ...signal.reasonCodes,
        'EXECUTION_SIMULATION_${result.status.name.toUpperCase()}',
        ...result.validationIssues,
      ];
      return signal.copyWith(reasonCodes: reasons);
    }
    final SignalStatus status = switch (result.status) {
      SimulatedExecutionStatus.completed =>
        result.tp2Time != null ? SignalStatus.tp2Hit : SignalStatus.tp1Hit,
      SimulatedExecutionStatus.stopped => SignalStatus.stopped,
      SimulatedExecutionStatus.timeout => SignalStatus.expired,
      SimulatedExecutionStatus.noEntry => SignalStatus.cancelled,
      SimulatedExecutionStatus.invalid => SignalStatus.cancelled,
    };
    final SignalStage stage = switch (status) {
      SignalStatus.tp2Hit => SignalStage.tp2Hit,
      SignalStatus.tp1Hit => SignalStage.tp1Hit,
      SignalStatus.stopped => SignalStage.stopped,
      SignalStatus.expired => SignalStage.expired,
      SignalStatus.cancelled => SignalStage.cancelled,
      SignalStatus.inPosition => SignalStage.inPosition,
      SignalStatus.waitingEntry => SignalStage.waitForTrigger,
    };
    final double riskPercent = signal.entryPrice <= 0.0
        ? 0.0
        : signal.risk / signal.entryPrice * 100.0;
    final RadarSignal costAware = signal.copyWith(
      status: status,
      stage: stage,
      entryTime: result.entryTime,
      tp1Time: result.tp1Time,
      tp2Time: result.tp2Time,
      exitTime: result.exitTime,
      stopTime: status == SignalStatus.stopped ? result.exitTime : null,
      mfeR: result.mfeR,
      maeR: result.maeR,
      mfePercent: result.mfeR * riskPercent,
      maePercent: result.maeR * riskPercent,
      resultR: result.netR,
      hasCostAwareResult: true,
      rawResultR: result.rawR,
      netResultR: result.netR,
      grossPnl: result.grossPnl,
      netPnl: result.netPnl,
      entryFee: result.entryFee,
      exitFees: result.exitFees,
      spreadCost: result.spreadCost,
      slippageCost: result.slippageCost,
      fundingCost: result.fundingCost,
      simulatedQuantity: result.quantity,
      executionModelVersion: 'EXECUTION_MODEL_V2',
    );
    return TradeOutcomeClassifier.classify(costAware);
  }

  double _standardizedQuantity(
    RadarSignal signal,
    InstrumentTradingRules rules,
  ) {
    if (signal.entryPrice <= 0.0) return 0.0;
    double quantity = ExchangeDecimal.floorToStep(
      ExchangeDecimal.divide(1000.0, signal.entryPrice),
      rules.quantityStep,
    );
    if (quantity < rules.minOrderQuantity) {
      quantity = ExchangeDecimal.ceilToStep(
        rules.minOrderQuantity,
        rules.quantityStep,
      );
    }
    if (ExchangeDecimal.multiply(quantity, signal.entryPrice) <
        rules.minNotional) {
      quantity = ExchangeDecimal.ceilToStep(
        ExchangeDecimal.divide(rules.minNotional, signal.entryPrice),
        rules.quantityStep,
      );
    }
    return quantity;
  }

  List<Candle> _candlesFrom(List<Candle> candles, DateTime start) {
    int low = 0;
    int high = candles.length;
    while (low < high) {
      final int middle = low + ((high - low) >> 1);
      if (candles[middle].time.isBefore(start)) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low >= candles.length ? const <Candle>[] : candles.sublist(low);
  }

  Iterable<RadarSignal> _profileHistory(
    Iterable<RadarSignal> signals,
    String profileId,
  ) => signals.where(
    (RadarSignal signal) => signal.executionProfileId == profileId,
  );
}
