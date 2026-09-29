import 'package:crypto_radar/engines/execution_simulator.dart';
import 'package:crypto_radar/models/execution_simulation_models.dart';
import 'package:crypto_radar/models/market_data_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/position_calculator_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LONG partial targets use separate exit notionals and net costs', () {
    final DateTime time = DateTime.utc(2026, 8, 28, 12);
    final ExecutionSimulationResult result = ExecutionSimulator.simulate(
      ExecutionSimulationInput(
        signal: _signal(time, SignalDirection.long),
        candles: <Candle>[
          _candle(time, 100.0, 100.2, 99.9, 100.1),
          _candle(
            time.add(const Duration(minutes: 1)),
            100.1,
            101.2,
            100.0,
            101.0,
          ),
          _candle(
            time.add(const Duration(minutes: 2)),
            101.0,
            103.2,
            100.5,
            103.0,
          ),
        ],
        quantity: 10.0,
        instrumentRules: _rules,
        feeModel: const FeeModel(
          makerFeePercent: 0.02,
          takerFeePercent: 0.05,
          entryOrderType: FeeOrderType.maker,
          targetExitOrderType: FeeOrderType.maker,
        ),
        slippageModel: const SlippageModel(
          entryPercent: 0.0,
          targetPercent: 0.0,
          stopPercent: 0.0,
        ),
        spreadModel: const HistoricalSpreadModel(percent: 0.0),
      ),
    );

    expect(result.status, SimulatedExecutionStatus.completed);
    expect(result.exits, hasLength(2));
    expect(result.exits[0].notional, 505.0);
    expect(result.exits[1].notional, 515.0);
    expect(result.grossPnl, 20.0);
    expect(result.rawR, 2.0);
    expect(result.netPnl, lessThan(result.grossPnl));
    expect(result.netR, lessThan(result.rawR));
    expect(result.tp1Time, time.add(const Duration(minutes: 1)));
    expect(result.tp2Time, time.add(const Duration(minutes: 2)));
  });

  test('SHORT stop applies adverse slippage and produces a loss', () {
    final DateTime time = DateTime.utc(2026, 8, 28, 12);
    final ExecutionSimulationResult result = ExecutionSimulator.simulate(
      ExecutionSimulationInput(
        signal: _signal(time, SignalDirection.short),
        candles: <Candle>[
          _candle(time, 100.0, 100.1, 99.9, 100.0),
          _candle(
            time.add(const Duration(minutes: 1)),
            100.0,
            101.2,
            99.8,
            101.0,
          ),
        ],
        quantity: 10.0,
        instrumentRules: _rules,
        feeModel: const FeeModel(),
        slippageModel: const SlippageModel(
          entryPercent: 0.0,
          targetPercent: 0.0,
          stopPercent: 0.1,
        ),
      ),
    );

    expect(result.status, SimulatedExecutionStatus.stopped);
    expect(result.exits.single.actualPrice, greaterThan(101.0));
    expect(result.netPnl, lessThan(-10.0));
    expect(result.netR, lessThan(0.0));
  });

  test('same candle Stop and TP resolves conservatively to Stop', () {
    final DateTime time = DateTime.utc(2026, 8, 28, 12);
    final ExecutionSimulationResult result = ExecutionSimulator.simulate(
      ExecutionSimulationInput(
        signal: _signal(time, SignalDirection.long),
        candles: <Candle>[_candle(time, 100.0, 103.2, 98.8, 100.0)],
        quantity: 10.0,
        instrumentRules: _rules,
        feeModel: const FeeModel(),
        slippageModel: const SlippageModel(
          entryPercent: 0.0,
          targetPercent: 0.0,
          stopPercent: 0.0,
        ),
      ),
    );

    expect(result.status, SimulatedExecutionStatus.stopped);
    expect(result.exits.single.label, 'STOP');
    expect(
      result.terminationReason,
      'STOP_AND_TARGET_SAME_CANDLE_CONSERVATIVE_STOP',
    );
  });

  test('historical funding is charged only inside the open trade', () {
    final DateTime time = DateTime.utc(2026, 8, 28, 12);
    final ExecutionSimulationResult result = ExecutionSimulator.simulate(
      ExecutionSimulationInput(
        signal: _signal(time, SignalDirection.long),
        candles: <Candle>[
          _candle(time, 100.0, 100.2, 99.9, 100.0),
          _candle(
            time.add(const Duration(hours: 1)),
            100.0,
            103.2,
            100.0,
            103.0,
          ),
        ],
        quantity: 10.0,
        instrumentRules: _rules,
        feeModel: const FeeModel(makerFeePercent: 0.0, takerFeePercent: 0.0),
        slippageModel: const SlippageModel(
          entryPercent: 0.0,
          targetPercent: 0.0,
          stopPercent: 0.0,
        ),
        funding: <HistoricalFundingPayment>[
          HistoricalFundingPayment(
            timestamp: time.subtract(const Duration(hours: 1)),
            ratePercent: 0.1,
          ),
          HistoricalFundingPayment(
            timestamp: time.add(const Duration(minutes: 30)),
            ratePercent: 0.1,
          ),
        ],
      ),
    );

    expect(result.fundingCost, 1.0);
    expect(result.netPnl, result.grossPnl - 1.0);
  });
}

RadarSignal _signal(DateTime time, SignalDirection direction) {
  final bool long = direction == SignalDirection.long;
  return RadarSignal(
    id: 'test-${direction.name}',
    symbol: 'BTCUSDT',
    time: time,
    direction: direction,
    referencePrice: 100.0,
    entryLow: 99.9,
    entryHigh: 100.1,
    stop: long ? 99.0 : 101.0,
    tp1: long ? 101.0 : 99.0,
    tp2: long ? 103.0 : 97.0,
    score: 80,
    trend5m: long ? Bias.bullish : Bias.bearish,
    trend15m: long ? Bias.bullish : Bias.bearish,
    trend1h: long ? Bias.bullish : Bias.bearish,
    rsi: 50.0,
    macd: 0.0,
    ema20: 100.0,
    ema50: 100.0,
    ema200: 100.0,
    relativeVolume: 1.0,
    rvolBias: Bias.neutral,
    fvgBias: Bias.neutral,
    orderBlockBias: Bias.neutral,
    liquidityBias: Bias.neutral,
    bos: Bias.neutral,
    choch: Bias.neutral,
  );
}

Candle _candle(
  DateTime time,
  double open,
  double high,
  double low,
  double close,
) => Candle(
  time: time,
  open: open,
  high: high,
  low: low,
  close: close,
  volume: 1000.0,
);

const InstrumentTradingRules _rules = InstrumentTradingRules(
  symbol: 'BTCUSDT',
  venue: ExchangeVenue.bybit,
  tickSize: 0.1,
  quantityStep: 0.1,
  minOrderQuantity: 0.1,
  minNotional: 5.0,
  maxLeverage: 100.0,
  leverageStep: 0.01,
);
