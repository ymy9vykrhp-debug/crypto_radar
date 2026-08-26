import '../models/market_models.dart';

class ChartIndicatorData {
  const ChartIndicatorData({
    required this.ema20,
    required this.ema50,
    required this.ema200,
    required this.rsi,
    required this.macd,
    required this.macdSignal,
    required this.macdHistogram,
    required this.atr,
    required this.vwap,
  });

  final List<double?> ema20;
  final List<double?> ema50;
  final List<double?> ema200;
  final List<double?> rsi;
  final List<double?> macd;
  final List<double?> macdSignal;
  final List<double?> macdHistogram;
  final List<double?> atr;
  final List<double?> vwap;
}

class ChartIndicatorEngine {
  const ChartIndicatorEngine._();

  static ChartIndicatorData calculate(List<Candle> candles) {
    final List<double> closes = candles
        .map<double>((Candle candle) => candle.close)
        .toList(growable: false);
    final List<double?> ema20 = _ema(closes, 20);
    final List<double?> ema50 = _ema(closes, 50);
    final List<double?> ema200 = _ema(closes, 200);
    final List<double?> ema12 = _ema(closes, 12);
    final List<double?> ema26 = _ema(closes, 26);
    final List<double> macdRaw = List<double>.generate(candles.length, (
      int index,
    ) {
      return (ema12[index] ?? closes[index]) - (ema26[index] ?? closes[index]);
    });
    final List<double?> macdSignal = _ema(macdRaw, 9);
    final List<double?> macd = macdRaw
        .map<double?>((double value) => value)
        .toList(growable: false);
    final List<double?> histogram = List<double?>.generate(
      candles.length,
      (int index) => macdRaw[index] - (macdSignal[index] ?? macdRaw[index]),
      growable: false,
    );
    return ChartIndicatorData(
      ema20: ema20,
      ema50: ema50,
      ema200: ema200,
      rsi: _rsi(closes, 14),
      macd: macd,
      macdSignal: macdSignal,
      macdHistogram: histogram,
      atr: _atr(candles, 14),
      vwap: _vwap(candles),
    );
  }

  static List<double?> _ema(List<double> values, int period) {
    if (values.isEmpty) return <double?>[];
    final double multiplier = 2 / (period + 1);
    double current = values.first;
    return List<double?>.generate(values.length, (int index) {
      if (index > 0) {
        current += (values[index] - current) * multiplier;
      }
      return index + 1 < period ? null : current;
    }, growable: false);
  }

  static List<double?> _rsi(List<double> closes, int period) {
    if (closes.isEmpty) return <double?>[];
    final List<double?> result = List<double?>.filled(closes.length, null);
    for (int index = period; index < closes.length; index++) {
      double gains = 0;
      double losses = 0;
      for (int item = index - period + 1; item <= index; item++) {
        final double change = closes[item] - closes[item - 1];
        change >= 0 ? gains += change : losses += change.abs();
      }
      result[index] = losses == 0 ? 100 : 100 - 100 / (1 + gains / losses);
    }
    return result;
  }

  static List<double?> _atr(List<Candle> candles, int period) {
    final List<double?> result = List<double?>.filled(candles.length, null);
    if (candles.length < 2) return result;
    final List<double> ranges = <double>[candles.first.range];
    for (int index = 1; index < candles.length; index++) {
      final Candle candle = candles[index];
      final double previousClose = candles[index - 1].close;
      final double highClose = (candle.high - previousClose).abs();
      final double lowClose = (candle.low - previousClose).abs();
      ranges.add(
        candle.range > highClose
            ? candle.range > lowClose
                  ? candle.range
                  : lowClose
            : highClose > lowClose
            ? highClose
            : lowClose,
      );
    }
    for (int index = period - 1; index < ranges.length; index++) {
      double total = 0;
      for (int item = index - period + 1; item <= index; item++) {
        total += ranges[item];
      }
      result[index] = total / period;
    }
    return result;
  }

  static List<double?> _vwap(List<Candle> candles) {
    double cumulativePriceVolume = 0;
    double cumulativeVolume = 0;
    return candles
        .map<double?>((Candle candle) {
          final double typical = (candle.high + candle.low + candle.close) / 3;
          cumulativePriceVolume += typical * candle.volume;
          cumulativeVolume += candle.volume;
          return cumulativeVolume == 0
              ? candle.close
              : cumulativePriceVolume / cumulativeVolume;
        })
        .toList(growable: false);
  }
}
