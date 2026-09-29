import '../models/historical_data_models.dart';
import '../models/market_data_models.dart';
import '../models/market_models.dart';
import 'market_data_provider.dart';
import 'storage/historical_candle_cache.dart';

/// Paginated, validated and reproducible local history for research/backtests.
class HistoricalDataStore {
  HistoricalDataStore({required this.provider, HistoricalCandleCache? cache})
    : cache = cache ?? createHistoricalCandleCache();

  final MarketDataProvider provider;
  final HistoricalCandleCache cache;

  Future<HistoricalDataSet> loadMonths(
    String symbol,
    String interval, {
    int months = 12,
    DateTime? asOf,
  }) {
    final DateTime end = (asOf ?? DateTime.now()).toUtc();
    final DateTime start = DateTime.utc(
      end.year,
      end.month - months,
      end.day,
      end.hour,
      end.minute,
    );
    return loadRange(symbol, interval, start: start, end: end, asOf: end);
  }

  Future<HistoricalDataSet> loadRange(
    String symbol,
    String interval, {
    required DateTime start,
    required DateTime end,
    DateTime? asOf,
  }) async {
    final Duration timeframe = intervalDuration(interval);
    final DateTime evaluationTime = (asOf ?? DateTime.now()).toUtc();
    final DateTime requestedStart = _floorToTimeframe(start.toUtc(), timeframe);
    final DateTime requestedEnd = end.toUtc().isBefore(evaluationTime)
        ? end.toUtc()
        : evaluationTime;
    final DateTime closedEnd = _floorToTimeframe(requestedEnd, timeframe);
    if (!requestedStart.isBefore(closedEnd)) {
      throw ArgumentError('Historical range must contain a closed candle');
    }

    final String normalizedSymbol = symbol.trim().toUpperCase();
    final String cacheKey =
        '${provider.venue.label}:$normalizedSymbol:$interval:v1';
    final List<String> issues = <String>[];
    Map<String, dynamic>? cached;
    try {
      cached = await cache.read(cacheKey);
    } on Object {
      issues.add('CACHE_READ_FAILED');
    }
    final List<Candle> existing = HistoricalDataSet.candlesFromCache(
      cached?['candles'],
    );
    final Map<int, Candle> merged = <int, Candle>{};
    for (final Candle candle in existing) {
      if (_isValidClosedCandle(candle, timeframe, evaluationTime)) {
        merged[candle.time.toUtc().millisecondsSinceEpoch] = candle;
      }
    }

    final List<_TimeRange> missing = _missingRanges(
      merged.values.toList(growable: false),
      requestedStart,
      closedEnd,
      timeframe,
    );
    bool providerFailed = false;
    for (final _TimeRange range in missing) {
      try {
        final List<Candle> downloaded = await _downloadRange(
          normalizedSymbol,
          interval,
          range,
        );
        for (final Candle candle in downloaded) {
          if (_isValidClosedCandle(candle, timeframe, evaluationTime)) {
            merged[candle.time.toUtc().millisecondsSinceEpoch] = candle;
          }
        }
      } on Object {
        providerFailed = true;
        if (!issues.contains('PROVIDER_FAILURE')) {
          issues.add('PROVIDER_FAILURE');
        }
      }
    }

    final List<Candle> allCandles = merged.values.toList()
      ..sort(
        (Candle first, Candle second) => first.time.compareTo(second.time),
      );
    if (allCandles.length != merged.length) {
      issues.add('DUPLICATE_CANDLES_REMOVED');
    }
    final List<Candle> requestedCandles = allCandles
        .where(
          (Candle candle) =>
              !candle.time.isBefore(requestedStart) &&
              candle.time.isBefore(closedEnd),
        )
        .toList(growable: false);
    final List<_TimeRange> remaining = _missingRanges(
      requestedCandles,
      requestedStart,
      closedEnd,
      timeframe,
    );
    if (remaining.isNotEmpty) issues.add('MISSING_CANDLES');
    if (requestedCandles.length < 200) issues.add('INSUFFICIENT_HISTORY');

    final HistoricalDataSet result = HistoricalDataSet(
      symbol: normalizedSymbol,
      interval: interval,
      source: provider.venue.label,
      requestedStart: requestedStart,
      requestedEnd: closedEnd,
      candles: List<Candle>.unmodifiable(requestedCandles),
      issues: List<String>.unmodifiable(issues),
      isComplete: remaining.isEmpty && !providerFailed,
      updatedAt: evaluationTime,
    );
    if (allCandles.isNotEmpty) {
      final HistoricalDataSet cacheData = HistoricalDataSet(
        symbol: normalizedSymbol,
        interval: interval,
        source: provider.venue.label,
        requestedStart: allCandles.first.time,
        requestedEnd: allCandles.last.time.add(timeframe),
        candles: List<Candle>.unmodifiable(allCandles),
        issues: const <String>[],
        isComplete: true,
        updatedAt: evaluationTime,
      );
      try {
        await cache.write(cacheKey, cacheData.toCacheJson());
      } on Object {
        // A cache write failure must not discard valid downloaded data.
      }
    }
    return result;
  }

  Future<List<Candle>> _downloadRange(
    String symbol,
    String interval,
    _TimeRange range,
  ) async {
    final Map<int, Candle> result = <int, Candle>{};
    DateTime cursorEnd = range.end.subtract(const Duration(milliseconds: 1));
    while (!cursorEnd.isBefore(range.start)) {
      final List<Candle> page = await provider.loadCandles(
        symbol,
        interval,
        limit: 1000,
        startTime: range.start,
        endTime: cursorEnd,
      );
      if (page.isEmpty) break;
      DateTime? oldest;
      for (final Candle candle in page) {
        final DateTime time = candle.time.toUtc();
        if (!time.isBefore(range.start) && time.isBefore(range.end)) {
          result[time.millisecondsSinceEpoch] = candle;
        }
        if (oldest == null || time.isBefore(oldest)) oldest = time;
      }
      if (page.length < 1000 ||
          oldest == null ||
          !oldest.isAfter(range.start)) {
        break;
      }
      final DateTime next = oldest.subtract(const Duration(milliseconds: 1));
      if (!next.isBefore(cursorEnd)) break;
      cursorEnd = next;
    }
    final List<Candle> candles = result.values.toList()
      ..sort(
        (Candle first, Candle second) => first.time.compareTo(second.time),
      );
    return candles;
  }

  static List<_TimeRange> _missingRanges(
    List<Candle> source,
    DateTime start,
    DateTime end,
    Duration timeframe,
  ) {
    final List<Candle> candles = List<Candle>.of(
      source,
    )..sort((Candle first, Candle second) => first.time.compareTo(second.time));
    final List<_TimeRange> result = <_TimeRange>[];
    DateTime cursor = start;
    for (final Candle candle in candles) {
      final DateTime time = candle.time.toUtc();
      if (time.isBefore(start)) continue;
      if (!time.isBefore(end)) break;
      if (time.isAfter(cursor)) result.add(_TimeRange(cursor, time));
      final DateTime next = time.add(timeframe);
      if (next.isAfter(cursor)) cursor = next;
    }
    if (cursor.isBefore(end)) result.add(_TimeRange(cursor, end));
    return result;
  }

  static bool _isValidClosedCandle(
    Candle candle,
    Duration timeframe,
    DateTime asOf,
  ) {
    if (candle.time.toUtc().add(timeframe).isAfter(asOf)) return false;
    final List<double> values = <double>[
      candle.open,
      candle.high,
      candle.low,
      candle.close,
      candle.volume,
    ];
    if (values.any((double value) => !value.isFinite)) return false;
    if (candle.open <= 0.0 ||
        candle.high <= 0.0 ||
        candle.low <= 0.0 ||
        candle.close <= 0.0 ||
        candle.volume < 0.0) {
      return false;
    }
    final double bodyHigh = candle.open >= candle.close
        ? candle.open
        : candle.close;
    final double bodyLow = candle.open <= candle.close
        ? candle.open
        : candle.close;
    return candle.high >= bodyHigh && candle.low <= bodyLow;
  }

  static DateTime _floorToTimeframe(DateTime value, Duration timeframe) {
    final int milliseconds = value.toUtc().millisecondsSinceEpoch;
    final int step = timeframe.inMilliseconds;
    return DateTime.fromMillisecondsSinceEpoch(
      milliseconds - milliseconds % step,
      isUtc: true,
    );
  }

  static Duration intervalDuration(String interval) {
    return switch (interval) {
      '1' || '1m' => const Duration(minutes: 1),
      '5' || '5m' => const Duration(minutes: 5),
      '15' || '15m' => const Duration(minutes: 15),
      '60' || '1h' => const Duration(hours: 1),
      _ => throw ArgumentError.value(interval, 'interval', 'unsupported'),
    };
  }
}

class _TimeRange {
  const _TimeRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
