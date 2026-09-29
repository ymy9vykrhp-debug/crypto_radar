import '../utils/exchange_decimal.dart';
import 'market_models.dart';

class HistoricalDataSet {
  const HistoricalDataSet({
    required this.symbol,
    required this.interval,
    required this.source,
    required this.requestedStart,
    required this.requestedEnd,
    required this.candles,
    required this.issues,
    required this.isComplete,
    required this.updatedAt,
  });

  final String symbol;
  final String interval;
  final String source;
  final DateTime requestedStart;
  final DateTime requestedEnd;
  final List<Candle> candles;
  final List<String> issues;
  final bool isComplete;
  final DateTime updatedAt;

  DateTime? get actualStart => candles.isEmpty ? null : candles.first.time;

  DateTime? get actualEnd => candles.isEmpty ? null : candles.last.time;

  Map<String, Object?> toCacheJson() => <String, Object?>{
    'schemaVersion': 1,
    'symbol': symbol,
    'interval': interval,
    'source': source,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
    'candles': candles
        .map<Map<String, Object?>>(_candleToJson)
        .toList(growable: false),
  };

  static List<Candle> candlesFromCache(Object? raw) {
    if (raw is! List) return const <Candle>[];
    final List<Candle> candles = <Candle>[];
    for (final Object? item in raw) {
      if (item is! Map) continue;
      final Map<String, dynamic> json = item.map<String, dynamic>(
        (Object? key, Object? value) =>
            MapEntry<String, dynamic>(key.toString(), value),
      );
      final int milliseconds = int.tryParse(json['t']?.toString() ?? '') ?? 0;
      final double open = double.tryParse(json['o']?.toString() ?? '') ?? 0.0;
      final double high = double.tryParse(json['h']?.toString() ?? '') ?? 0.0;
      final double low = double.tryParse(json['l']?.toString() ?? '') ?? 0.0;
      final double close = double.tryParse(json['c']?.toString() ?? '') ?? 0.0;
      final double volume = double.tryParse(json['v']?.toString() ?? '') ?? 0.0;
      if (milliseconds <= 0) continue;
      candles.add(
        Candle(
          time: DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true),
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );
    }
    return candles;
  }

  static Map<String, Object?> _candleToJson(Candle candle) => <String, Object?>{
    't': candle.time.toUtc().millisecondsSinceEpoch,
    'o': ExchangeDecimal.canonical(candle.open),
    'h': ExchangeDecimal.canonical(candle.high),
    'l': ExchangeDecimal.canonical(candle.low),
    'c': ExchangeDecimal.canonical(candle.close),
    'v': ExchangeDecimal.canonical(candle.volume),
  };
}
