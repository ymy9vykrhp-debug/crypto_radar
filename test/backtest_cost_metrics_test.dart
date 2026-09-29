import 'package:crypto_radar/models/backtest_models.dart';
import 'package:crypto_radar/models/market_models.dart';
import 'package:crypto_radar/models/signal_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backtest keeps raw and cost-aware net metrics separate', () {
    final BacktestReport report = BacktestReport.fromSignals(
      symbol: 'BTCUSDT',
      startedAt: DateTime.utc(2026, 8, 1),
      finishedAt: DateTime.utc(2026, 8, 2),
      source: <RadarSignal>[
        _closedSignal(
          id: 'win',
          status: SignalStatus.tp2Hit,
          rawR: 1.0,
          netR: 0.8,
          grossPnl: 10.0,
          costs: 2.0,
        ),
        _closedSignal(
          id: 'loss',
          status: SignalStatus.stopped,
          rawR: -1.0,
          netR: -1.2,
          grossPnl: -10.0,
          costs: 2.0,
        ),
      ],
    );

    expect(report.rawAverageR, closeTo(0.0, 1e-9));
    expect(report.netAverageR, closeTo(-0.2, 1e-9));
    expect(report.averageR, report.netAverageR);
    expect(report.rawProfitFactor, closeTo(1.0, 1e-9));
    expect(report.netProfitFactor, closeTo(2 / 3, 1e-9));
    expect(report.profitFactor, report.netProfitFactor);
    expect(report.totalExecutionCosts, closeTo(4.0, 1e-9));
    expect(report.costToGrossPercent, closeTo(40.0, 1e-9));

    final BacktestReport restored = BacktestReport.fromJson(report.toJson());
    expect(restored.rawAverageR, report.rawAverageR);
    expect(restored.netAverageR, report.netAverageR);
    expect(restored.totalExecutionCosts, report.totalExecutionCosts);
  });

  test('old reports treat legacy metrics as both raw and net', () {
    final BacktestReport restored = BacktestReport.fromJson(<String, dynamic>{
      'symbol': 'BTCUSDT',
      'startedAt': '2026-08-01T00:00:00.000Z',
      'finishedAt': '2026-08-02T00:00:00.000Z',
      'averageR': 0.25,
      'profitFactor': 1.4,
      'maxDrawdownR': 3.0,
    });

    expect(restored.rawAverageR, 0.25);
    expect(restored.netAverageR, 0.25);
    expect(restored.rawProfitFactor, 1.4);
    expect(restored.netProfitFactor, 1.4);
    expect(restored.rawMaxDrawdownR, 3.0);
    expect(restored.netMaxDrawdownR, 3.0);
  });
}

RadarSignal _closedSignal({
  required String id,
  required SignalStatus status,
  required double rawR,
  required double netR,
  required double grossPnl,
  required double costs,
}) {
  final DateTime time = DateTime.utc(2026, 8, 1, id == 'win' ? 1 : 2);
  return RadarSignal(
    id: id,
    symbol: 'BTCUSDT',
    time: time,
    direction: SignalDirection.long,
    referencePrice: 100.0,
    entryLow: 100.0,
    entryHigh: 100.0,
    stop: 99.0,
    tp1: 101.0,
    tp2: 102.0,
    score: 80,
    trend5m: Bias.bullish,
    trend15m: Bias.bullish,
    trend1h: Bias.bullish,
    rsi: 55.0,
    macd: 0.1,
    ema20: 101.0,
    ema50: 100.0,
    ema200: 99.0,
    relativeVolume: 1.2,
    rvolBias: Bias.bullish,
    fvgBias: Bias.neutral,
    orderBlockBias: Bias.neutral,
    liquidityBias: Bias.bullish,
    bos: Bias.bullish,
    choch: Bias.neutral,
    status: status,
    entryTime: time.add(const Duration(minutes: 1)),
    exitTime: time.add(const Duration(minutes: 10)),
    resultR: netR,
    hasCostAwareResult: true,
    rawResultR: rawR,
    netResultR: netR,
    grossPnl: grossPnl,
    netPnl: grossPnl > 0 ? grossPnl - costs : grossPnl - costs,
    entryFee: costs / 2,
    exitFees: costs / 2,
    executionModelVersion: 'EXECUTION_MODEL_V2',
  );
}
