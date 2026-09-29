import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/exchange_confirmation_models.dart';
import '../models/market_models.dart';
import 'exchange_confirmation_provider.dart';

/// Public Binance USD-M futures context used only to confirm or contradict the
/// Bybit setup. It never places orders and never supplies Bybit position data.
class BinanceConfirmationService implements ExchangeConfirmationProvider {
  BinanceConfirmationService(this._client, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _clock;

  static const String _baseUrl = 'https://fapi.binance.com';

  @override
  Future<ExchangeConfirmationSnapshot> load(String rawSymbol) async {
    final String symbol = rawSymbol.trim().toUpperCase().replaceAll('/', '');
    if (symbol.isEmpty || !symbol.endsWith('USDT')) {
      throw ArgumentError('Неверный Binance Futures символ: $rawSymbol');
    }
    final DateTime cutoff = _clock().toUtc();
    final List<List<_BinanceCandle>> frames = await Future.wait(
      <String>['5m', '15m', '1h'].map(
        (String interval) => _loadClosedCandles(
          symbol: symbol,
          interval: interval,
          cutoff: cutoff,
        ),
      ),
    );
    final List<_BinanceCandle> five = frames[0];
    final List<_BinanceCandle> fifteen = frames[1];
    final List<_BinanceCandle> hour = frames[2];
    final _BinanceCandle latest = five.last;
    return ExchangeConfirmationSnapshot(
      venue: 'BINANCE',
      symbol: symbol,
      updatedAt: cutoff,
      price: latest.close,
      change5mPercent: _changePercent(five, 4),
      change15mPercent: _changePercent(fifteen, 4),
      change1hPercent: _changePercent(hour, 4),
      trend5m: _trend(five, thresholdPercent: 0.10),
      trend15m: _trend(fifteen, thresholdPercent: 0.18),
      trend1h: _trend(hour, thresholdPercent: 0.30),
      relativeVolume5m: _relativeVolume(five),
    );
  }

  Future<List<_BinanceCandle>> _loadClosedCandles({
    required String symbol,
    required String interval,
    required DateTime cutoff,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/fapi/v1/klines').replace(
      queryParameters: <String, String>{
        'symbol': symbol,
        'interval': interval,
        'limit': '12',
      },
    );
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Binance Futures HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! List<dynamic>) {
      throw Exception('Неожиданный ответ Binance Futures');
    }
    final List<_BinanceCandle> candles = <_BinanceCandle>[];
    for (final Object? raw in decoded) {
      if (raw is! List<dynamic> || raw.length < 7) continue;
      final DateTime closeTime = DateTime.fromMillisecondsSinceEpoch(
        _asInt(raw[6]),
        isUtc: true,
      );
      if (closeTime.isAfter(cutoff)) continue;
      final double open = _asDouble(raw[1]);
      final double high = _asDouble(raw[2]);
      final double low = _asDouble(raw[3]);
      final double close = _asDouble(raw[4]);
      final double volume = _asDouble(raw[5]);
      if (<double>[open, high, low, close].any((double v) => v <= 0)) continue;
      candles.add(
        _BinanceCandle(
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          closeTime: closeTime,
        ),
      );
    }
    if (candles.length < 4) {
      throw Exception('Binance Futures: недостаточно закрытых свечей $interval');
    }
    return candles;
  }

  static double _changePercent(List<_BinanceCandle> candles, int lookback) {
    if (candles.length < 2) return 0;
    final int start = (candles.length - lookback).clamp(0, candles.length - 1).toInt();
    final double base = candles[start].close;
    return base <= 0 ? 0 : (candles.last.close / base - 1) * 100;
  }

  static Bias _trend(
    List<_BinanceCandle> candles, {
    required double thresholdPercent,
  }) {
    final double change = _changePercent(candles, 4);
    final _BinanceCandle last = candles.last;
    final double midpoint = (last.high + last.low) / 2;
    if (change >= thresholdPercent && last.close >= midpoint) {
      return Bias.bullish;
    }
    if (change <= -thresholdPercent && last.close <= midpoint) {
      return Bias.bearish;
    }
    return Bias.neutral;
  }

  static double _relativeVolume(List<_BinanceCandle> candles) {
    if (candles.length < 3) return 1;
    final List<_BinanceCandle> previous = candles.sublist(0, candles.length - 1);
    final int start = (previous.length - 5).clamp(0, previous.length).toInt();
    final List<_BinanceCandle> sample = previous.sublist(start);
    if (sample.isEmpty) return 1;
    final double average =
        sample.fold<double>(
          0,
          (double sum, _BinanceCandle c) => sum + c.volume,
        ) /
        sample.length;
    return average <= 0 ? 1 : candles.last.volume / average;
  }

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  static int _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}

class _BinanceCandle {
  const _BinanceCandle({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.closeTime,
  });

  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime closeTime;
}
