import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engines/signal_engine.dart';
import '../models/crypto_universe_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';
import 'market_data_provider.dart';

class BybitService implements MarketDataProvider {
  BybitService(this._client);

  final http.Client _client;
  static const String _baseUrl = 'https://api.bybit.com';

  @override
  ExchangeVenue get venue => ExchangeVenue.bybit;

  @override
  Future<List<CryptoAsset>> loadCryptoUniverse() async {
    final List<_InstrumentSpec> instruments = await _loadLinearInstruments();
    final Map<String, Map<String, dynamic>> tickers =
        await _loadLinearTickers();
    final List<CryptoAsset> assets =
        instruments
            .where(
              (_InstrumentSpec instrument) =>
                  instrument.status == 'Trading' &&
                  instrument.quoteCoin == 'USDT' &&
                  instrument.contractType == 'LinearPerpetual',
            )
            .map<CryptoAsset>((_InstrumentSpec instrument) {
              final Map<String, dynamic> ticker =
                  tickers[instrument.symbol] ?? <String, dynamic>{};
              return CryptoAsset(
                symbol: instrument.symbol,
                baseCoin: instrument.baseCoin,
                quoteCoin: instrument.quoteCoin,
                contractType: instrument.contractType,
                status: instrument.status,
                lastPrice: _toDouble(ticker['lastPrice']),
                change24hPercent: _toDouble(ticker['price24hPcnt']) * 100,
                turnover24h: _toDouble(ticker['turnover24h']),
                volume24h: _toDouble(ticker['volume24h']),
                high24h: _toDouble(ticker['highPrice24h']),
                low24h: _toDouble(ticker['lowPrice24h']),
                launchTime: instrument.launchTime,
                maxLeverage: instrument.maxLeverage,
                bidPrice: _toDouble(ticker['bid1Price']),
                askPrice: _toDouble(ticker['ask1Price']),
                markPrice: _toDouble(ticker['markPrice']),
                indexPrice: _toDouble(ticker['indexPrice']),
                fundingRatePercent: _toDouble(ticker['fundingRate']) * 100.0,
                openInterest: _toDouble(ticker['openInterest']),
                tickSize: instrument.tickSize,
                quantityStep: instrument.quantityStep,
                minOrderQuantity: instrument.minOrderQuantity,
                minNotional: instrument.minNotional,
              );
            })
            .where((CryptoAsset asset) => asset.lastPrice > 0)
            .toList(growable: false)
          ..sort(
            (CryptoAsset a, CryptoAsset b) =>
                b.turnover24h.compareTo(a.turnover24h),
          );
    if (assets.isEmpty) {
      throw Exception('Bybit не вернул торгуемые USDT Perpetual инструменты');
    }
    return List<CryptoAsset>.unmodifiable(assets);
  }

  @override
  Future<MarketSnapshot> load(String symbol) async {
    final Future<List<Candle>> oneFuture = loadCandles(symbol, '1');
    final Future<List<Candle>> fiveFuture = loadCandles(symbol, '5');
    final Future<List<Candle>> fifteenFuture = loadCandles(symbol, '15');
    final Future<List<Candle>> hourFuture = loadCandles(symbol, '60');
    // Attach error handlers immediately. These requests run in parallel with
    // candles and may fail before they are awaited; a late try/catch would let
    // the Future report an unhandled asynchronous error in that interval.
    final Future<TickerStats?> tickerFuture = loadTicker(symbol)
        .then<TickerStats?>(
          (TickerStats value) => value,
          onError: (Object _, StackTrace _) => null,
        );
    final Future<InstrumentTradingRules?> rulesFuture = loadTradingRules(symbol)
        .then<InstrumentTradingRules?>(
          (InstrumentTradingRules? value) => value,
          onError: (Object _, StackTrace _) => null,
        );

    final List<Candle> oneCandles = await oneFuture;
    final List<Candle> fiveCandles = await fiveFuture;
    final List<Candle> fifteenCandles = await fifteenFuture;
    final List<Candle> hourCandles = await hourFuture;
    TickerStats? ticker = await tickerFuture;
    if (ticker == null) {
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
        sourceUpdatedAt: DateTime.now().toUtc(),
      );
    }
    final InstrumentTradingRules? tradingRules = await rulesFuture;

    return SignalEngine.buildSnapshot(
      symbol: symbol,
      ticker: ticker,
      oneCandles: oneCandles,
      fiveCandles: fiveCandles,
      fifteenCandles: fifteenCandles,
      hourCandles: hourCandles,
      tradingRules: tradingRules,
      observedAt: DateTime.now().toUtc(),
    );
  }

  @override
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
        time: DateTime.fromMillisecondsSinceEpoch(_toInt(raw[0]), isUtc: true),
        open: _toDouble(raw[1]),
        high: _toDouble(raw[2]),
        low: _toDouble(raw[3]),
        close: _toDouble(raw[4]),
        volume: _toDouble(raw[5]),
      );
    }).toList();
    return candles.reversed.toList(growable: false);
  }

  @override
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

  @override
  Future<InstrumentTradingRules?> loadTradingRules(String symbol) async {
    final String normalized = normalizeCryptoSymbol(symbol);
    final List<_InstrumentSpec> instruments = await _loadLinearInstruments(
      symbol: normalized,
    );
    for (final _InstrumentSpec instrument in instruments) {
      if (instrument.symbol == normalized) {
        return InstrumentTradingRules(
          symbol: instrument.symbol,
          venue: venue,
          tickSize: instrument.tickSize,
          quantityStep: instrument.quantityStep,
          minOrderQuantity: instrument.minOrderQuantity,
          minNotional: instrument.minNotional,
          maxLeverage: instrument.maxLeverage,
          leverageStep: instrument.leverageStep,
        );
      }
    }
    return null;
  }

  @override
  Future<TickerStats> loadTicker(String symbol) async {
    final Uri tickerUri = Uri.parse('$_baseUrl/v5/market/tickers').replace(
      queryParameters: <String, String>{'category': 'linear', 'symbol': symbol},
    );
    final Uri orderBookUri = Uri.parse('$_baseUrl/v5/market/orderbook').replace(
      queryParameters: <String, String>{
        'category': 'linear',
        'symbol': symbol,
        'limit': '1',
      },
    );
    final http.Response response = await _client
        .get(tickerUri)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Bybit ticker HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неожиданный ticker');
    }
    if (_toInt(decoded['retCode']) != 0) {
      throw Exception(decoded['retMsg']?.toString() ?? 'Ошибка Bybit ticker');
    }
    final int sourceMilliseconds = _toInt(decoded['time']);
    final DateTime? sourceUpdatedAt = sourceMilliseconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(sourceMilliseconds, isUtc: true);
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
    double bid = _toDouble(first['bid1Price']);
    double ask = _toDouble(first['ask1Price']);
    DateTime? orderBookUpdatedAt;
    try {
      final http.Response orderBookResponse = await _client
          .get(orderBookUri)
          .timeout(const Duration(seconds: 6));
      final Map<String, dynamic> book = _decodeResult(
        orderBookResponse,
        context: 'Bybit orderbook',
      );
      bid = _firstBookPrice(book['b']) ?? bid;
      ask = _firstBookPrice(book['a']) ?? ask;
      final int updateMilliseconds = _toInt(book['ts']);
      if (updateMilliseconds > 0) {
        orderBookUpdatedAt = DateTime.fromMillisecondsSinceEpoch(
          updateMilliseconds,
          isUtc: true,
        );
      }
    } on Object {
      // Ticker bid/ask remains a safe public fallback when orderbook is absent.
    }
    return TickerStats(
      price: _toDouble(first['lastPrice']),
      change24hPercent: _toDouble(first['price24hPcnt']) * 100.0,
      turnover24h: _toDouble(first['turnover24h']),
      bidPrice: bid,
      askPrice: ask,
      markPrice: _toDouble(first['markPrice']),
      indexPrice: _toDouble(first['indexPrice']),
      fundingRatePercent: _toDouble(first['fundingRate']) * 100.0,
      openInterest: _toDouble(first['openInterest']),
      openInterestValue: _toDouble(first['openInterestValue']),
      orderBookUpdatedAt: orderBookUpdatedAt,
      sourceUpdatedAt: sourceUpdatedAt,
      fundingUpdatedAt: sourceUpdatedAt,
    );
  }

  Future<List<_InstrumentSpec>> _loadLinearInstruments({String? symbol}) async {
    final List<_InstrumentSpec> instruments = <_InstrumentSpec>[];
    final Set<String> seenCursors = <String>{};
    String cursor = '';
    for (int page = 0; page < 10; page++) {
      final Map<String, String> query = <String, String>{
        'category': 'linear',
        'status': 'Trading',
        'limit': '1000',
      };
      if (symbol != null && symbol.isNotEmpty) query['symbol'] = symbol;
      if (cursor.isNotEmpty) query['cursor'] = cursor;
      final Uri uri = Uri.parse('$_baseUrl/v5/market/instruments-info')
          .replace(queryParameters: query);
      final http.Response response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      final Map<String, dynamic> result = _decodeResult(
        response,
        context: 'Bybit instruments',
      );
      final Object? rawList = result['list'];
      if (rawList is! List<dynamic>) {
        throw Exception('Bybit instruments: список отсутствует');
      }
      for (final Object? raw in rawList) {
        if (raw is Map<String, dynamic>) {
          final String symbol = normalizeCryptoSymbol(
            raw['symbol']?.toString() ?? '',
          );
          if (symbol.isEmpty) continue;
          final Object? leverageRaw = raw['leverageFilter'];
          final Map<String, dynamic> leverage =
              leverageRaw is Map<String, dynamic>
              ? leverageRaw
              : <String, dynamic>{};
          final Object? priceFilterRaw = raw['priceFilter'];
          final Map<String, dynamic> priceFilter =
              priceFilterRaw is Map<String, dynamic>
              ? priceFilterRaw
              : <String, dynamic>{};
          final Object? lotSizeRaw = raw['lotSizeFilter'];
          final Map<String, dynamic> lotSize =
              lotSizeRaw is Map<String, dynamic>
              ? lotSizeRaw
              : <String, dynamic>{};
          final int launchMilliseconds = _toInt(raw['launchTime']);
          instruments.add(
            _InstrumentSpec(
              symbol: symbol,
              baseCoin: raw['baseCoin']?.toString().toUpperCase() ?? '',
              quoteCoin: raw['quoteCoin']?.toString().toUpperCase() ?? '',
              contractType: raw['contractType']?.toString() ?? '',
              status: raw['status']?.toString() ?? '',
              launchTime: launchMilliseconds <= 0
                  ? null
                  : DateTime.fromMillisecondsSinceEpoch(
                      launchMilliseconds,
                      isUtc: true,
                    ),
              maxLeverage: _toDouble(leverage['maxLeverage']),
              tickSize: _toDouble(priceFilter['tickSize']),
              quantityStep: _toDouble(lotSize['qtyStep']),
              minOrderQuantity: _toDouble(lotSize['minOrderQty']),
              minNotional: _toDouble(lotSize['minNotionalValue']),
              leverageStep: _toDouble(leverage['leverageStep']),
            ),
          );
        }
      }
      final String next = result['nextPageCursor']?.toString() ?? '';
      if (next.isEmpty || !seenCursors.add(next)) break;
      cursor = next;
    }
    final Map<String, _InstrumentSpec> unique = <String, _InstrumentSpec>{
      for (final _InstrumentSpec instrument in instruments)
        instrument.symbol: instrument,
    };
    return unique.values.toList(growable: false);
  }

  Future<Map<String, Map<String, dynamic>>> _loadLinearTickers() async {
    final Uri uri = Uri.parse('$_baseUrl/v5/market/tickers')
        .replace(queryParameters: <String, String>{'category': 'linear'});
    final http.Response response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    final Map<String, dynamic> result = _decodeResult(
      response,
      context: 'Bybit tickers',
    );
    final Object? rawList = result['list'];
    if (rawList is! List<dynamic>) {
      throw Exception('Bybit tickers: список отсутствует');
    }
    final Map<String, Map<String, dynamic>> tickers =
        <String, Map<String, dynamic>>{};
    for (final Object? raw in rawList) {
      if (raw is! Map<String, dynamic>) continue;
      final String symbol = normalizeCryptoSymbol(
        raw['symbol']?.toString() ?? '',
      );
      if (symbol.isNotEmpty) tickers[symbol] = raw;
    }
    return tickers;
  }

  static Map<String, dynamic> _decodeResult(
    http.Response response, {
    required String context,
  }) {
    if (response.statusCode != 200) {
      throw Exception('$context HTTP ${response.statusCode}');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('$context: неожиданный ответ');
    }
    if (_toInt(decoded['retCode']) != 0) {
      throw Exception(decoded['retMsg']?.toString() ?? '$context: ошибка');
    }
    final Object? result = decoded['result'];
    if (result is! Map<String, dynamic>) {
      throw Exception('$context: result отсутствует');
    }
    return result;
  }

  static double _toDouble(Object? value) {
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  static int _toInt(Object? value) {
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _firstBookPrice(Object? rawLevels) {
    if (rawLevels is! List<dynamic> || rawLevels.isEmpty) return null;
    final Object? first = rawLevels.first;
    if (first is! List<dynamic> || first.isEmpty) return null;
    final double price = _toDouble(first.first);
    return price > 0 ? price : null;
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

class _InstrumentSpec {
  const _InstrumentSpec({
    required this.symbol,
    required this.baseCoin,
    required this.quoteCoin,
    required this.contractType,
    required this.status,
    required this.launchTime,
    required this.maxLeverage,
    required this.tickSize,
    required this.quantityStep,
    required this.minOrderQuantity,
    required this.minNotional,
    required this.leverageStep,
  });

  final String symbol;
  final String baseCoin;
  final String quoteCoin;
  final String contractType;
  final String status;
  final DateTime? launchTime;
  final double maxLeverage;
  final double tickSize;
  final double quantityStep;
  final double minOrderQuantity;
  final double minNotional;
  final double leverageStep;
}
