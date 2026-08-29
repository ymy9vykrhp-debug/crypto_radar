import '../models/market_data_models.dart';
import '../models/market_models.dart';

/// Validates normalized exchange data before it reaches a trading decision.
class MarketDataIntegrityEngine {
  const MarketDataIntegrityEngine._();

  static MarketDataIntegrity assess({
    required TickerStats ticker,
    required Map<Duration, List<Candle>> candlesByTimeframe,
    required InstrumentTradingRules? tradingRules,
    DateTime? checkedAt,
    bool requireFreshBidAsk = true,
  }) {
    final DateTime now = (checkedAt ?? DateTime.now()).toUtc();
    final List<String> issues = <String>[];
    bool critical = false;
    int minimumCandleCount = 1 << 30;

    if (!ticker.price.isFinite || ticker.price <= 0.0) {
      issues.add('TICKER_PRICE_UNAVAILABLE');
      critical = true;
    }
    if (ticker.sourceUpdatedAt == null) {
      issues.add('TICKER_TIMESTAMP_UNAVAILABLE');
      critical = true;
    } else if (_isStale(
      ticker.sourceUpdatedAt!,
      now,
      const Duration(minutes: 1),
    )) {
      issues.add('TICKER_STALE');
      critical = true;
    }

    final bool freshBidAsk = ticker.hasFreshBidAskAt(now);
    if (!ticker.hasMicrostructure) {
      issues.add('BID_ASK_UNAVAILABLE');
      critical = critical || requireFreshBidAsk;
    } else if (!freshBidAsk) {
      issues.add('BID_ASK_STALE');
      critical = critical || requireFreshBidAsk;
    }
    if (ticker.fundingUpdatedAt == null) {
      issues.add('FUNDING_TIMESTAMP_UNAVAILABLE');
    }
    if (ticker.orderBookUpdatedAt == null) {
      issues.add('ORDERBOOK_TIMESTAMP_UNAVAILABLE');
    }

    final bool hasInstrumentRules = tradingRules?.isComplete ?? false;
    if (!hasInstrumentRules) {
      issues.add('INSTRUMENT_RULES_UNAVAILABLE');
      critical = true;
    }

    for (final MapEntry<Duration, List<Candle>> entry
        in candlesByTimeframe.entries) {
      final Duration timeframe = entry.key;
      final List<Candle> candles = entry.value;
      final String code = _timeframeCode(timeframe);
      if (candles.isEmpty) {
        issues.add('CANDLES_${code}_UNAVAILABLE');
        critical = true;
        minimumCandleCount = 0;
        continue;
      }
      if (candles.length < minimumCandleCount) {
        minimumCandleCount = candles.length;
      }
      if (candles.length < 80) {
        issues.add('CANDLES_${code}_INSUFFICIENT');
        critical = true;
      } else if (candles.length < 200) {
        issues.add('CANDLES_${code}_LIMITED');
      }

      DateTime? previous;
      for (final Candle candle in candles) {
        if (!_isValidCandle(candle)) {
          issues.add('CANDLES_${code}_INVALID_OHLC');
          critical = true;
          break;
        }
        if (previous != null) {
          final Duration distance = candle.time.toUtc().difference(previous);
          if (distance <= Duration.zero) {
            issues.add('CANDLES_${code}_DUPLICATE_OR_OUT_OF_ORDER');
            critical = true;
            break;
          }
          if (distance > timeframe + const Duration(seconds: 1)) {
            issues.add('CANDLES_${code}_MISSING');
            critical = true;
            break;
          }
        }
        previous = candle.time.toUtc();
      }
    }

    if (minimumCandleCount == 1 << 30) minimumCandleCount = 0;
    final MarketDataQualityLevel level;
    if (critical) {
      level = MarketDataQualityLevel.low;
    } else if (issues.isEmpty && minimumCandleCount >= 200) {
      level = MarketDataQualityLevel.high;
    } else {
      level = MarketDataQualityLevel.medium;
    }
    return MarketDataIntegrity(
      level: level,
      issues: List<String>.unmodifiable(issues),
      hasCriticalIssue: critical,
      hasFreshBidAsk: freshBidAsk,
      hasInstrumentRules: hasInstrumentRules,
      minimumCandleCount: minimumCandleCount,
      checkedAt: now,
    );
  }

  static bool _isValidCandle(Candle candle) {
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
    return candle.high >= bodyHigh &&
        candle.low <= bodyLow &&
        candle.high >= candle.low;
  }

  static bool _isStale(DateTime timestamp, DateTime now, Duration maximumAge) {
    final Duration age = now.difference(timestamp.toUtc());
    return age.isNegative || age > maximumAge;
  }

  static String _timeframeCode(Duration timeframe) {
    if (timeframe == const Duration(minutes: 1)) return '1M';
    if (timeframe == const Duration(minutes: 5)) return '5M';
    if (timeframe == const Duration(minutes: 15)) return '15M';
    if (timeframe == const Duration(hours: 1)) return '1H';
    return '${timeframe.inSeconds}S';
  }
}
