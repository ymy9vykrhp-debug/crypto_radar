import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engines/signal_engine.dart';
import '../models/market_models.dart';

class BybitService {
  BybitService(this._client);

  final http.Client _client;
  static const String _baseUrl = 'https://api.bybit.com';

  Future<MarketSnapshot> load(String symbol) async {
    final Future<List<Candle>> oneFuture = loadCandles(symbol, '1');
    final Future<List<Candle>> fiveFuture = loadCandles(symbol, '5');
    final Future<List<Candle>> fifteenFuture = loadCandles(symbol, '15');
    final Future<List<Candle>> hourFuture = loadCandles(symbol, '60');
    final Future<TickerStats> tickerFuture = _loadTicker(symbol);

    final List<Candle> oneCandles = await oneFuture;
    final List<Candle> fiveCandles = await fiveFuture;
    final List<Candle> fifteenCandles = await fifteenFuture;
    final List<Candle> hourCandles = await hourFuture;
    TickerStats ticker;
    try {
      ticker = await tickerFuture;
    } on Object {
      final double current = fiveCandles.last.close;
      final double first = fiveCandles.first.close;
      final double change = first == 0.0
          ? 0.0
          : (current - first) / first * 100.0;
      final double turnover = fiveCandles.fold<double>(
        0.0,
        (double sum, Candle candle) => sum + candle.volume * candle.close,
      );
      ticker = TickerStats(
        price: current,
        change24hPercent: change,
        turnover24h: turnover,
      );
    }

    return SignalEngine.buildSnapshot(
      symbol: symbol,
      ticker: ticker,
      oneCandles: oneCandles,
      fiveCandles: fiveCandles,
      fifteenCandles: fifteenCandles,
      hourCandles: hourCandles,
    );
  }

  Future<List<Candle>> loadCandles(
    String symbol,
    String interval, {
    int limit = 240,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final Map<String, String> query = <String, String>{
      'category': 'linear',
      'symbol': symbol,
      'interval': interval,
      'limit': _clampInt(limit, 1, 1000).toString(),
    };
    if (startTime != null) {
      query['start'] = startTime.toUtc().millisecondsSinceEpoch.toString();
    }
    if (endTime != null) {
      query['end'] = endTime.toUtc().millisecondsSinceEpoch.toString();
    }
    final Uri uri = Uri.parse('$_baseUrl/v5/market/kline')
        .replace(queryParameters: query);
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Bybit вернул HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неожиданный ответ Bybit');
    }
    if (decoded['retCode'] != 0) {
      throw Exception(decoded['retMsg']?.toString() ?? 'Ошибка Bybit');
    }
    final Object? result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('В ответе Bybit нет свечей');
    }
    final Object? rawList = result['list'];
    if (rawList is! List<dynamic> || rawList.isEmpty) {
      throw Exception('Bybit не вернул свечи $interval м');
    }
    final List<Candle> candles = rawList.map<Candle>((dynamic raw) {
      if (raw is! List<dynamic> || raw.length < 6) {
        throw const FormatException('Повреждённая свеча');
      }
      return Candle(
        time: DateTime.fromMillisecondsSinceEpoch(_toInt(raw[0])),
        open: _toDouble(raw[1]),
        high: _toDouble(raw[2]),
        low: _toDouble(raw[3]),
        close: _toDouble(raw[4]),
        volume: _toDouble(raw[5]),
      );
    }).toList();
    return candles.reversed.toList(growable: false);
  }

  Future<List<Candle>> loadHistoricalCandles(
    String symbol,
    String interval, {
    int count = 5000,
  }) async {
    final Map<int, Candle> unique = <int, Candle>{};
    DateTime? endTime;
    while (unique.length < count) {
      final int remaining = count - unique.length;
      final int pageSize = _clampInt(remaining, 1, 1000);
      final List<Candle> page = await loadCandles(
        symbol,
        interval,
        limit: pageSize,
        endTime: endTime,
      );
      for (final Candle candle in page) {
        unique[candle.time.millisecondsSinceEpoch] = candle;
      }
      if (page.length < pageSize) {
        break;
      }
      final DateTime nextEnd = DateTime.fromMillisecondsSinceEpoch(
        page.first.time.millisecondsSinceEpoch - 1,
      );
      if (endTime != null && !nextEnd.isBefore(endTime)) {
        break;
      }
      endTime = nextEnd;
    }
    final List<Candle> result = unique.values.toList()
      ..sort(
        (Candle first, Candle second) => first.time.compareTo(second.time),
      );
    return result.length <= count
        ? List<Candle>.unmodifiable(result)
        : List<Candle>.unmodifiable(
            result.sublist(result.length - count, result.length),
          );
  }

  Future<TickerStats> _loadTicker(String symbol) async {
    final Uri uri = Uri.parse('$_baseUrl/v5/market/tickers').replace(
      queryParameters: <String, String>{'category': 'linear', 'symbol': symbol},
    );
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Bybit ticker HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неожиданный ticker');
    }
    final Object? result = decoded['result'];
    final Object? rawList = result is Map<String, dynamic>
        ? result['list']
        : null;
    if (rawList is! List<dynamic> || rawList.isEmpty) {
      throw Exception('Пустой ticker');
    }
    final Object? first = rawList.first;
    if (first is! Map<String, dynamic>) {
      throw Exception('Повреждённый ticker');
    }
    return TickerStats(
      price: _toDouble(first['lastPrice']),
      change24hPercent: _toDouble(first['price24hPcnt']) * 100.0,
      turnover24h: _toDouble(first['turnover24h']),
    );
  }

  static double _toDouble(Object? value) {
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _toInt(Object? value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _clampInt(int value, int minimum, int maximum) {
    if (value < minimum) {
      return minimum;
    }
    if (value > maximum) {
      return maximum;
    }
    return value;
  }
}
