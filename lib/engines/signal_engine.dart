import '../models/market_data_models.dart';
import '../models/first_move_models.dart';
import '../models/market_models.dart';
import '../models/signal_models.dart';
import 'market_data_integrity_engine.dart';
import 'stop_engine.dart';
import 'structural_target_engine.dart';

class SignalEngine {
  const SignalEngine._();

  static MarketSnapshot buildSnapshot({
    required String symbol,
    required TickerStats ticker,
    required List<Candle> oneCandles,
    required List<Candle> fiveCandles,
    required List<Candle> fifteenCandles,
    required List<Candle> hourCandles,
    InstrumentTradingRules? tradingRules,
    DateTime? observedAt,
    bool requireFreshBidAsk = true,
  }) {
    final DateTime snapshotTime = (observedAt ?? DateTime.now()).toUtc();
    final TimeframeAnalysis one = _analyzeTimeframe('1м', oneCandles);
    final TimeframeAnalysis five = _analyzeTimeframe('5м', fiveCandles);
    final TimeframeAnalysis fifteen = _analyzeTimeframe('15м', fifteenCandles);
    final TimeframeAnalysis hour = _analyzeTimeframe('1ч', hourCandles);
    final List<ConfirmationItem> confirmations = _buildConfirmations(
      five,
      fifteen,
      hour,
    );

    int longScore = 0;
    int shortScore = 0;
    for (final ConfirmationItem item in confirmations) {
      if (item.bias == Bias.bullish) {
        longScore += item.weight;
      } else if (item.bias == Bias.bearish) {
        shortScore += item.weight;
      }
    }

    final int difference = longScore - shortScore;
    final Bias planBias;
    final String signal;
    if (difference >= 5) {
      planBias = Bias.bullish;
      signal = 'ПОКУПКА';
    } else if (difference <= -5) {
      planBias = Bias.bearish;
      signal = 'ПРОДАЖА';
    } else {
      planBias = difference >= 0 ? Bias.bullish : Bias.bearish;
      signal = 'ЖДАТЬ';
    }

    final int strength = _clampInt(50 + difference.abs() * 5, 50, 95);
    final _Magnet magnet = _chooseMagnet(fifteen, planBias);
    final double price = ticker.price > 0.0 ? ticker.price : fifteen.price;
    final double potential = price == 0.0
        ? 0.0
        : (magnet.price - price).abs() / price * 100.0;
    final double expectedDistance = fifteen.atr * 1.5;
    final TradePlan tradePlan = _createTradePlan(
      analysis: fifteen,
      bias: planBias,
      tickSize: tradingRules?.tickSize ?? 0.0,
    );
    final TickerStats preservedTicker = ticker.copyWith(price: price);
    final MarketDataIntegrity dataIntegrity = MarketDataIntegrityEngine.assess(
      ticker: preservedTicker,
      candlesByTimeframe: <Duration, List<Candle>>{
        const Duration(minutes: 1): oneCandles,
        const Duration(minutes: 5): fiveCandles,
        const Duration(minutes: 15): fifteenCandles,
        const Duration(hours: 1): hourCandles,
      },
      tradingRules: tradingRules,
      checkedAt: snapshotTime,
      requireFreshBidAsk: requireFreshBidAsk,
    );

    return MarketSnapshot(
      symbol: symbol,
      ticker: preservedTicker,
      oneMinute: one,
      fiveMinutes: five,
      fifteenMinutes: fifteen,
      oneHour: hour,
      confirmations: List<ConfirmationItem>.unmodifiable(confirmations),
      longScore: longScore,
      shortScore: shortScore,
      signal: signal,
      strength: strength,
      magnetPrice: magnet.price,
      magnetLabel: magnet.label,
      potentialPercent: potential,
      expectedLow: price - expectedDistance,
      expectedHigh: price + expectedDistance,
      tradePlan: tradePlan,
      updatedAt: snapshotTime,
      tradingRules: tradingRules,
      dataIntegrity: dataIntegrity,
    );
  }

  static RadarSignal? createSignal(
    MarketSnapshot snapshot, {
    DateTime? signalTime,
  }) {
    if (snapshot.signal == 'ЖДАТЬ') {
      return null;
    }
    final TimeframeAnalysis analysis = snapshot.fifteenMinutes;
    final SignalDirection direction = snapshot.tradePlan.bias == Bias.bullish
        ? SignalDirection.long
        : SignalDirection.short;
    final DateTime time = signalTime ?? snapshot.fiveMinutes.candles.last.time;
    final Bias volumeBias = analysis.relativeVolume < 1.2
        ? Bias.neutral
        : analysis.candles.last.isBullish
        ? Bias.bullish
        : Bias.bearish;
    final Bias liquidityBias = analysis.liquidity.sweepBelow
        ? Bias.bullish
        : analysis.liquidity.sweepAbove
        ? Bias.bearish
        : Bias.neutral;
    final String id =
        '${snapshot.symbol}:standard:${direction.name}:'
        '${time.toUtc().millisecondsSinceEpoch}';

    return RadarSignal(
      id: id,
      symbol: snapshot.symbol,
      time: time,
      direction: direction,
      style: SignalStyle.standard,
      referencePrice: snapshot.ticker.price,
      entryLow: snapshot.tradePlan.entryLow,
      entryHigh: snapshot.tradePlan.entryHigh,
      stop: snapshot.tradePlan.stop,
      tp1: snapshot.tradePlan.tp1,
      tp2: snapshot.tradePlan.tp2,
      score: _maxInt(snapshot.longScore, snapshot.shortScore),
      trend1m: snapshot.oneMinute.trend,
      trend5m: snapshot.fiveMinutes.trend,
      trend15m: analysis.trend,
      trend1h: snapshot.oneHour.trend,
      rsi: analysis.rsi,
      macd: analysis.macd.histogram,
      ema20: analysis.ema20,
      ema50: analysis.ema50,
      ema200: analysis.ema200,
      relativeVolume: analysis.relativeVolume,
      rvolBias: volumeBias,
      fvgBias: _nearbyZoneBiasForKind(analysis, ZoneKind.fairValueGap),
      orderBlockBias: _nearbyZoneBiasForKind(analysis, ZoneKind.orderBlock),
      liquidityBias: liquidityBias,
      bos: analysis.structure.bos,
      choch: analysis.structure.choch,
      leverage: snapshot.tradePlan.leverage,
      lastTrackedCandleTime: snapshot.fiveMinutes.candles.last.time,
      firstMove: _firstMoveContext(
        snapshot: snapshot,
        direction: direction,
        style: SignalStyle.standard,
        entryLow: snapshot.tradePlan.entryLow,
        entryHigh: snapshot.tradePlan.entryHigh,
        tp1: snapshot.tradePlan.tp1,
      ),
    );
  }

  static RadarSignal? createScalpSignal(
    MarketSnapshot snapshot, {
    DateTime? signalTime,
  }) {
    final TimeframeAnalysis one = snapshot.oneMinute;
    final TimeframeAnalysis fifteen = snapshot.fifteenMinutes;
    final TimeframeAnalysis hour = snapshot.oneHour;
    final Bias directionBias;
    if (fifteen.trend == Bias.bullish && hour.trend != Bias.bearish) {
      directionBias = Bias.bullish;
    } else if (fifteen.trend == Bias.bearish && hour.trend != Bias.bullish) {
      directionBias = Bias.bearish;
    } else {
      return null;
    }

    final Bias structureTrigger = one.structure.choch != Bias.neutral
        ? one.structure.choch
        : one.structure.bos != Bias.neutral
        ? one.structure.bos
        : one.structure.bias;
    final Bias liquidityBias = one.liquidity.sweepBelow
        ? Bias.bullish
        : one.liquidity.sweepAbove
        ? Bias.bearish
        : Bias.neutral;
    final bool structureAligned =
        structureTrigger == directionBias || liquidityBias == directionBias;
    if (!structureAligned || one.atr <= 0.0) {
      return null;
    }

    final Bias macdBias = one.macd.histogram > 0.0
        ? Bias.bullish
        : one.macd.histogram < 0.0
        ? Bias.bearish
        : Bias.neutral;
    final bool rsiAligned = directionBias == Bias.bullish
        ? one.rsi >= 52.0 && one.rsi <= 72.0
        : one.rsi <= 48.0 && one.rsi >= 28.0;
    int score = 55;
    if (one.trend == directionBias) {
      score += 15;
    }
    if (macdBias == directionBias) {
      score += 10;
    }
    if (rsiAligned) {
      score += 10;
    }
    if (one.relativeVolume >= 0.8) {
      score += 10;
    }
    if (score < 75) {
      return null;
    }

    final SignalDirection direction = directionBias == Bias.bullish
        ? SignalDirection.long
        : SignalDirection.short;
    final DateTime time = signalTime ?? one.candles.last.time;
    final double price = one.price;
    final double entryPadding = one.atr * 0.10;
    final StructuralTargetPlan targetPlan = StructuralTargetEngine.build(
      analysis: one,
      direction: direction,
      entryLow: price - entryPadding,
      entryHigh: price + entryPadding,
      tickSize: snapshot.tradingRules?.tickSize ?? 0.0,
    );
    final double? structuralStop = StopEngine.findStructuralInvalidation(
      direction: direction,
      analysis: one,
      entry: price,
    );
    final Bias volumeBias = one.relativeVolume < 0.8
        ? Bias.neutral
        : one.candles.last.isBullish
        ? Bias.bullish
        : Bias.bearish;
    final String id =
        '${snapshot.symbol}:scalp:${direction.name}:'
        '${time.toUtc().millisecondsSinceEpoch}';

    return RadarSignal(
      id: id,
      symbol: snapshot.symbol,
      time: time,
      direction: direction,
      style: SignalStyle.scalp,
      referencePrice: price,
      entryLow: price - entryPadding,
      entryHigh: price + entryPadding,
      stop: structuralStop ?? 0.0,
      tp1: targetPlan.tp1,
      tp2: targetPlan.tp2,
      score: score,
      trend1m: one.trend,
      trend5m: snapshot.fiveMinutes.trend,
      trend15m: fifteen.trend,
      trend1h: hour.trend,
      rsi: one.rsi,
      macd: one.macd.histogram,
      ema20: one.ema20,
      ema50: one.ema50,
      ema200: one.ema200,
      relativeVolume: one.relativeVolume,
      rvolBias: volumeBias,
      fvgBias: _nearbyZoneBiasForKind(one, ZoneKind.fairValueGap),
      orderBlockBias: _nearbyZoneBiasForKind(one, ZoneKind.orderBlock),
      liquidityBias: liquidityBias,
      bos: one.structure.bos,
      choch: one.structure.choch,
      // SignalEngine describes the setup only. Final leverage belongs to the
      // Position/Account Risk layer after structural Stop validation.
      leverage: 1,
      lastTrackedCandleTime: one.candles.last.time,
      firstMove: _firstMoveContext(
        snapshot: snapshot,
        direction: direction,
        style: SignalStyle.scalp,
        entryLow: price - entryPadding,
        entryHigh: price + entryPadding,
        tp1: targetPlan.tp1,
      ),
    );
  }

  static TimeframeAnalysis _analyzeTimeframe(
    String name,
    List<Candle> candles,
  ) {
    if (candles.length < 60) {
      throw Exception('Недостаточно свечей для $name');
    }
    final List<double> closes = candles
        .map<double>((Candle candle) => candle.close)
        .toList(growable: false);
    final double price = closes.last;
    final double ema20 = _ema(closes, 20);
    final double ema50 = _ema(closes, 50);
    final double ema200 = _ema(closes, 200);
    final double atr = _atr(candles, 14);
    final List<SwingPoint> swings = _findSwings(candles);
    final StructureResult structure = _structure(candles, swings);
    final _Levels levels = _levels(price, swings, candles);

    return TimeframeAnalysis(
      name: name,
      candles: List<Candle>.unmodifiable(candles),
      price: price,
      ema20: ema20,
      ema50: ema50,
      ema200: ema200,
      rsi: _rsi(closes, 14),
      macd: _macd(closes),
      relativeVolume: _relativeVolume(candles, 20),
      atr: atr,
      trend: _trend(price, ema20, ema50, ema200),
      ichimoku: _ichimoku(candles),
      fibonacci: _fibonacci(candles, price),
      structure: structure,
      support: levels.support,
      resistance: levels.resistance,
      liquidity: _liquidity(candles, swings, atr),
      fairValueGaps: List<PriceZone>.unmodifiable(
        _fairValueGaps(candles, name),
      ),
      orderBlocks: List<PriceZone>.unmodifiable(
        _orderBlocks(candles, name, atr),
      ),
    );
  }

  static double _ema(List<double> values, int period) {
    if (values.isEmpty) {
      return 0.0;
    }
    final double multiplier = 2.0 / (period + 1.0);
    double current = values.first;
    for (int index = 1; index < values.length; index++) {
      current = (values[index] - current) * multiplier + current;
    }
    return current;
  }

  static List<double> _emaSeries(List<double> values, int period) {
    if (values.isEmpty) {
      return const <double>[];
    }
    final double multiplier = 2.0 / (period + 1.0);
    double current = values.first;
    final List<double> result = <double>[current];
    for (int index = 1; index < values.length; index++) {
      current = (values[index] - current) * multiplier + current;
      result.add(current);
    }
    return result;
  }

  static double _rsi(List<double> closes, int period) {
    if (closes.length <= period) {
      return 50.0;
    }
    double gains = 0.0;
    double losses = 0.0;
    final int start = closes.length - period;
    for (int index = start; index < closes.length; index++) {
      final double change = closes[index] - closes[index - 1];
      if (change >= 0.0) {
        gains += change;
      } else {
        losses += change.abs();
      }
    }
    if (losses == 0.0) {
      return 100.0;
    }
    final double relativeStrength = (gains / period) / (losses / period);
    return 100.0 - 100.0 / (1.0 + relativeStrength);
  }

  static MacdResult _macd(List<double> closes) {
    final List<double> fast = _emaSeries(closes, 12);
    final List<double> slow = _emaSeries(closes, 26);
    final List<double> macdValues = <double>[];
    for (int index = 0; index < closes.length; index++) {
      macdValues.add(fast[index] - slow[index]);
    }
    final List<double> signalValues = _emaSeries(macdValues, 9);
    final double macd = macdValues.last;
    final double signal = signalValues.last;
    return MacdResult(macd: macd, signal: signal, histogram: macd - signal);
  }

  static double _atr(List<Candle> candles, int period) {
    if (candles.length <= period) {
      return 0.0;
    }
    double sum = 0.0;
    final int start = candles.length - period;
    for (int index = start; index < candles.length; index++) {
      final Candle candle = candles[index];
      final double previousClose = candles[index - 1].close;
      final double highLow = candle.high - candle.low;
      final double highClose = (candle.high - previousClose).abs();
      final double lowClose = (candle.low - previousClose).abs();
      sum += _maxDouble(highLow, _maxDouble(highClose, lowClose));
    }
    return sum / period;
  }

  static double _relativeVolume(List<Candle> candles, int period) {
    if (candles.length <= period) {
      return 1.0;
    }
    final int start = candles.length - period - 1;
    double sum = 0.0;
    for (int index = start; index < candles.length - 1; index++) {
      sum += candles[index].volume;
    }
    final double average = sum / period;
    return average == 0.0 ? 1.0 : candles.last.volume / average;
  }

  static Bias _trend(double price, double ema20, double ema50, double ema200) {
    if (price > ema20 && ema20 > ema50 && ema50 > ema200) {
      return Bias.bullish;
    }
    if (price < ema20 && ema20 < ema50 && ema50 < ema200) {
      return Bias.bearish;
    }
    if (price > ema20 && ema20 > ema50) {
      return Bias.bullish;
    }
    if (price < ema20 && ema20 < ema50) {
      return Bias.bearish;
    }
    return Bias.neutral;
  }

  static IchimokuResult _ichimoku(List<Candle> candles) {
    final double conversion = _rangeMidpoint(candles, 9);
    final double base = _rangeMidpoint(candles, 26);
    final double spanA = (conversion + base) / 2.0;
    final double spanB = _rangeMidpoint(candles, 52);
    final double price = candles.last.close;
    final double cloudTop = _maxDouble(spanA, spanB);
    final double cloudBottom = _minDouble(spanA, spanB);
    final Bias bias;
    if (price > cloudTop && conversion > base) {
      bias = Bias.bullish;
    } else if (price < cloudBottom && conversion < base) {
      bias = Bias.bearish;
    } else {
      bias = Bias.neutral;
    }
    return IchimokuResult(
      conversion: conversion,
      base: base,
      spanA: spanA,
      spanB: spanB,
      bias: bias,
    );
  }

  static double _rangeMidpoint(List<Candle> candles, int period) {
    final int start = candles.length > period ? candles.length - period : 0;
    double highest = candles[start].high;
    double lowest = candles[start].low;
    for (int index = start + 1; index < candles.length; index++) {
      highest = _maxDouble(highest, candles[index].high);
      lowest = _minDouble(lowest, candles[index].low);
    }
    return (highest + lowest) / 2.0;
  }

  static FibonacciResult _fibonacci(List<Candle> candles, double price) {
    final int start = candles.length > 120 ? candles.length - 120 : 0;
    double high = candles[start].high;
    double low = candles[start].low;
    for (int index = start + 1; index < candles.length; index++) {
      high = _maxDouble(high, candles[index].high);
      low = _minDouble(low, candles[index].low);
    }
    const List<double> ratios = <double>[0.236, 0.382, 0.5, 0.618, 0.786];
    double nearestRatio = ratios.first;
    double nearestLevel = high - (high - low) * nearestRatio;
    double nearestDistance = (price - nearestLevel).abs();
    for (final double ratio in ratios.skip(1)) {
      final double level = high - (high - low) * ratio;
      final double distance = (price - level).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestRatio = ratio;
        nearestLevel = level;
      }
    }
    return FibonacciResult(
      swingLow: low,
      swingHigh: high,
      nearestLevel: nearestLevel,
      ratio: nearestRatio,
    );
  }

  static List<SwingPoint> _findSwings(List<Candle> candles) {
    final List<SwingPoint> swings = <SwingPoint>[];
    for (int index = 2; index < candles.length - 2; index++) {
      final Candle current = candles[index];
      final bool isHigh =
          current.high > candles[index - 1].high &&
          current.high > candles[index - 2].high &&
          current.high >= candles[index + 1].high &&
          current.high >= candles[index + 2].high;
      final bool isLow =
          current.low < candles[index - 1].low &&
          current.low < candles[index - 2].low &&
          current.low <= candles[index + 1].low &&
          current.low <= candles[index + 2].low;
      if (isHigh) {
        swings.add(SwingPoint(index: index, price: current.high, isHigh: true));
      }
      if (isLow) {
        swings.add(SwingPoint(index: index, price: current.low, isHigh: false));
      }
    }
    return swings;
  }

  static StructureResult _structure(
    List<Candle> candles,
    List<SwingPoint> swings,
  ) {
    final List<SwingPoint> highs = swings
        .where((SwingPoint swing) => swing.isHigh)
        .toList(growable: false);
    final List<SwingPoint> lows = swings
        .where((SwingPoint swing) => !swing.isHigh)
        .toList(growable: false);
    if (highs.length < 2 || lows.length < 2) {
      return const StructureResult(
        highLabel: '-',
        lowLabel: '-',
        bias: Bias.neutral,
        bos: Bias.neutral,
        choch: Bias.neutral,
        lastSwingHigh: null,
        lastSwingLow: null,
      );
    }

    final double previousHigh = highs[highs.length - 2].price;
    final double latestHigh = highs.last.price;
    final double previousLow = lows[lows.length - 2].price;
    final double latestLow = lows.last.price;
    final String highLabel = latestHigh > previousHigh ? 'HH' : 'LH';
    final String lowLabel = latestLow > previousLow ? 'HL' : 'LL';
    final Bias bias;
    if (highLabel == 'HH' && lowLabel == 'HL') {
      bias = Bias.bullish;
    } else if (highLabel == 'LH' && lowLabel == 'LL') {
      bias = Bias.bearish;
    } else {
      bias = Bias.neutral;
    }

    final double close = candles.last.close;
    Bias bos = Bias.neutral;
    if (close > latestHigh) {
      bos = Bias.bullish;
    } else if (close < latestLow) {
      bos = Bias.bearish;
    }
    Bias choch = Bias.neutral;
    if (bias == Bias.bearish && close > latestHigh) {
      choch = Bias.bullish;
    } else if (bias == Bias.bullish && close < latestLow) {
      choch = Bias.bearish;
    }

    return StructureResult(
      highLabel: highLabel,
      lowLabel: lowLabel,
      bias: bias,
      bos: bos,
      choch: choch,
      lastSwingHigh: latestHigh,
      lastSwingLow: latestLow,
    );
  }

  static _Levels _levels(
    double price,
    List<SwingPoint> swings,
    List<Candle> candles,
  ) {
    double? support;
    double? resistance;
    for (final SwingPoint swing in swings) {
      if (!swing.isHigh && swing.price < price) {
        if (support == null || swing.price > support) {
          support = swing.price;
        }
      }
      if (swing.isHigh && swing.price > price) {
        if (resistance == null || swing.price < resistance) {
          resistance = swing.price;
        }
      }
    }
    final int start = candles.length > 50 ? candles.length - 50 : 0;
    double fallbackLow = candles[start].low;
    double fallbackHigh = candles[start].high;
    for (int index = start + 1; index < candles.length; index++) {
      fallbackLow = _minDouble(fallbackLow, candles[index].low);
      fallbackHigh = _maxDouble(fallbackHigh, candles[index].high);
    }
    return _Levels(
      support: support ?? fallbackLow,
      resistance: resistance ?? fallbackHigh,
    );
  }

  static LiquidityResult _liquidity(
    List<Candle> candles,
    List<SwingPoint> swings,
    double atr,
  ) {
    final List<SwingPoint> highs = swings
        .where((SwingPoint swing) => swing.isHigh)
        .toList(growable: false);
    final List<SwingPoint> lows = swings
        .where((SwingPoint swing) => !swing.isHigh)
        .toList(growable: false);
    final double tolerance = atr * 0.2;
    final double? equalHigh = _latestEqualLevel(highs, tolerance);
    final double? equalLow = _latestEqualLevel(lows, tolerance);

    final Candle latest = candles.last;
    final int start = candles.length > 22 ? candles.length - 22 : 0;
    double previousHigh = candles[start].high;
    double previousLow = candles[start].low;
    for (int index = start + 1; index < candles.length - 1; index++) {
      previousHigh = _maxDouble(previousHigh, candles[index].high);
      previousLow = _minDouble(previousLow, candles[index].low);
    }
    final bool sweepAbove =
        latest.high > previousHigh &&
        latest.close < previousHigh &&
        latest.close < latest.open;
    final bool sweepBelow =
        latest.low < previousLow &&
        latest.close > previousLow &&
        latest.close > latest.open;
    return LiquidityResult(
      above: equalHigh ?? (highs.isEmpty ? previousHigh : highs.last.price),
      below: equalLow ?? (lows.isEmpty ? previousLow : lows.last.price),
      sweepAbove: sweepAbove,
      sweepBelow: sweepBelow,
    );
  }

  static double? _latestEqualLevel(List<SwingPoint> points, double tolerance) {
    for (int index = points.length - 1; index > 0; index--) {
      final double first = points[index].price;
      final double second = points[index - 1].price;
      if ((first - second).abs() <= tolerance) {
        return (first + second) / 2.0;
      }
    }
    return null;
  }

  static List<PriceZone> _fairValueGaps(
    List<Candle> candles,
    String timeframe,
  ) {
    final List<PriceZone> zones = <PriceZone>[];
    final int start = candles.length > 100 ? candles.length - 100 : 2;
    for (int index = _maxInt(start, 2); index < candles.length; index++) {
      final Candle first = candles[index - 2];
      final Candle third = candles[index];
      if (third.low > first.high) {
        zones.add(
          PriceZone(
            lower: first.high,
            upper: third.low,
            bias: Bias.bullish,
            kind: ZoneKind.fairValueGap,
            timeframe: timeframe,
          ),
        );
      } else if (third.high < first.low) {
        zones.add(
          PriceZone(
            lower: third.high,
            upper: first.low,
            bias: Bias.bearish,
            kind: ZoneKind.fairValueGap,
            timeframe: timeframe,
          ),
        );
      }
    }
    return zones.length <= 8
        ? zones
        : zones.sublist(zones.length - 8, zones.length);
  }

  static List<PriceZone> _orderBlocks(
    List<Candle> candles,
    String timeframe,
    double atr,
  ) {
    final List<PriceZone> zones = <PriceZone>[];
    final int start = candles.length > 100 ? candles.length - 100 : 1;
    for (int index = _maxInt(start, 1); index < candles.length - 1; index++) {
      final Candle base = candles[index];
      final Candle displacement = candles[index + 1];
      final bool bullishBlock =
          base.isBearish &&
          displacement.isBullish &&
          displacement.range >= atr * 1.15 &&
          displacement.close > base.high;
      final bool bearishBlock =
          base.isBullish &&
          displacement.isBearish &&
          displacement.range >= atr * 1.15 &&
          displacement.close < base.low;
      if (bullishBlock) {
        zones.add(
          PriceZone(
            lower: base.low,
            upper: _maxDouble(base.open, base.close),
            bias: Bias.bullish,
            kind: ZoneKind.orderBlock,
            timeframe: timeframe,
          ),
        );
      } else if (bearishBlock) {
        zones.add(
          PriceZone(
            lower: _minDouble(base.open, base.close),
            upper: base.high,
            bias: Bias.bearish,
            kind: ZoneKind.orderBlock,
            timeframe: timeframe,
          ),
        );
      }
    }
    return zones.length <= 8
        ? zones
        : zones.sublist(zones.length - 8, zones.length);
  }

  static List<ConfirmationItem> _buildConfirmations(
    TimeframeAnalysis five,
    TimeframeAnalysis fifteen,
    TimeframeAnalysis hour,
  ) {
    final Bias rsiBias = fifteen.rsi >= 55.0
        ? Bias.bullish
        : fifteen.rsi <= 45.0
        ? Bias.bearish
        : Bias.neutral;
    final Bias macdBias = fifteen.macd.histogram > 0.0
        ? Bias.bullish
        : fifteen.macd.histogram < 0.0
        ? Bias.bearish
        : Bias.neutral;
    final Bias volumeBias = fifteen.relativeVolume < 1.2
        ? Bias.neutral
        : fifteen.candles.last.isBullish
        ? Bias.bullish
        : Bias.bearish;
    final Bias sweepBias = fifteen.liquidity.sweepBelow
        ? Bias.bullish
        : fifteen.liquidity.sweepAbove
        ? Bias.bearish
        : Bias.neutral;
    final Bias zoneBias = _nearbyZoneBias(fifteen);
    return <ConfirmationItem>[
      ConfirmationItem(
        name: 'Тренд 5м',
        value: five.trend.label,
        bias: five.trend,
        weight: 1,
      ),
      ConfirmationItem(
        name: 'Тренд 15м',
        value: fifteen.trend.label,
        bias: fifteen.trend,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'Тренд 1ч',
        value: hour.trend.label,
        bias: hour.trend,
        weight: 3,
      ),
      ConfirmationItem(
        name: 'Структура 15м',
        value: '${fifteen.structure.highLabel} / ${fifteen.structure.lowLabel}',
        bias: fifteen.structure.bias,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'BOS',
        value: fifteen.structure.bos.label,
        bias: fifteen.structure.bos,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'CHOCH',
        value: fifteen.structure.choch.label,
        bias: fifteen.structure.choch,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'RSI 14',
        value: fifteen.rsi.toStringAsFixed(1),
        bias: rsiBias,
        weight: 1,
      ),
      ConfirmationItem(
        name: 'MACD',
        value: fifteen.macd.histogram.toStringAsFixed(6),
        bias: macdBias,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'Ichimoku',
        value: fifteen.ichimoku.bias.label,
        bias: fifteen.ichimoku.bias,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'Relative Volume',
        value: '${fifteen.relativeVolume.toStringAsFixed(2)}×',
        bias: volumeBias,
        weight: 1,
      ),
      ConfirmationItem(
        name: 'Liquidity sweep',
        value: sweepBias == Bias.neutral ? 'НЕТ' : sweepBias.label,
        bias: sweepBias,
        weight: 2,
      ),
      ConfirmationItem(
        name: 'FVG / Order Block',
        value: zoneBias == Bias.neutral ? 'ВНЕ ЗОН' : zoneBias.label,
        bias: zoneBias,
        weight: 2,
      ),
    ];
  }

  static Bias _nearbyZoneBias(TimeframeAnalysis analysis) {
    final List<PriceZone> zones = <PriceZone>[
      ...analysis.fairValueGaps,
      ...analysis.orderBlocks,
    ];
    PriceZone? nearest;
    double nearestDistance = double.infinity;
    for (final PriceZone zone in zones) {
      final double distance = (analysis.price - zone.midpoint).abs();
      if (distance < nearestDistance) {
        nearest = zone;
        nearestDistance = distance;
      }
    }
    return nearest != null && nearestDistance <= analysis.atr * 1.25
        ? nearest.bias
        : Bias.neutral;
  }

  static Bias _nearbyZoneBiasForKind(
    TimeframeAnalysis analysis,
    ZoneKind kind,
  ) {
    final List<PriceZone> zones = kind == ZoneKind.fairValueGap
        ? analysis.fairValueGaps
        : analysis.orderBlocks;
    PriceZone? nearest;
    double nearestDistance = double.infinity;
    for (final PriceZone zone in zones) {
      final double distance = (analysis.price - zone.midpoint).abs();
      if (distance < nearestDistance) {
        nearest = zone;
        nearestDistance = distance;
      }
    }
    return nearest != null && nearestDistance <= analysis.atr * 1.25
        ? nearest.bias
        : Bias.neutral;
  }

  static _Magnet _chooseMagnet(TimeframeAnalysis analysis, Bias bias) {
    final List<_Magnet> candidates = <_Magnet>[];
    void add(double? price, String label) {
      if (price == null || price <= 0.0) {
        return;
      }
      if (bias == Bias.bullish && price > analysis.price) {
        candidates.add(_Magnet(price, label));
      } else if (bias == Bias.bearish && price < analysis.price) {
        candidates.add(_Magnet(price, label));
      }
    }

    add(analysis.resistance, 'Сопротивление');
    add(analysis.support, 'Поддержка');
    add(analysis.liquidity.above, 'Ликвидность сверху');
    add(analysis.liquidity.below, 'Ликвидность снизу');
    add(analysis.fibonacci.nearestLevel, 'Fibonacci');
    for (final PriceZone zone in <PriceZone>[
      ...analysis.fairValueGaps,
      ...analysis.orderBlocks,
    ]) {
      add(
        zone.midpoint,
        zone.kind == ZoneKind.fairValueGap ? 'FVG' : 'Order Block',
      );
    }
    if (candidates.isEmpty) {
      final double fallback = bias == Bias.bullish
          ? analysis.price + analysis.atr * 1.5
          : analysis.price - analysis.atr * 1.5;
      return _Magnet(fallback, 'ATR-цель');
    }
    candidates.sort((_Magnet first, _Magnet second) {
      final double firstDistance = (analysis.price - first.price).abs();
      final double secondDistance = (analysis.price - second.price).abs();
      return firstDistance.compareTo(secondDistance);
    });
    return candidates.first;
  }

  static TradePlan _createTradePlan({
    required TimeframeAnalysis analysis,
    required Bias bias,
    required double tickSize,
  }) {
    final double atr = analysis.atr;
    final double price = analysis.price;
    final bool bullish = bias == Bias.bullish;
    final double entryLow = bullish ? price - atr * 0.25 : price - atr * 0.05;
    final double entryHigh = bullish ? price + atr * 0.05 : price + atr * 0.25;
    final SignalDirection direction = bullish
        ? SignalDirection.long
        : SignalDirection.short;
    final double? structuralStop = StopEngine.findStructuralInvalidation(
      direction: direction,
      analysis: analysis,
      entry: (entryLow + entryHigh) / 2.0,
    );
    final StructuralTargetPlan targets = StructuralTargetEngine.build(
      analysis: analysis,
      direction: direction,
      entryLow: entryLow,
      entryHigh: entryHigh,
      tickSize: tickSize,
    );
    return TradePlan(
      bias: bias,
      entryLow: entryLow,
      entryHigh: entryHigh,
      stop: structuralStop ?? 0.0,
      tp1: targets.tp1,
      tp2: targets.tp2,
      leverage: 1,
      reason: bullish
          ? 'Вход после удержания зоны и бычьего подтверждения 5м.'
          : 'Вход после отклонения зоны и медвежьего подтверждения 5м.',
      tp1Reason: targets.tp1Label,
      tp2Reason: targets.tp2Label,
      structuralTargetValid: targets.valid,
      structuralStopValid: structuralStop != null,
    );
  }

  static FirstMoveRecord _firstMoveContext({
    required MarketSnapshot snapshot,
    required SignalDirection direction,
    required SignalStyle style,
    required double entryLow,
    required double entryHigh,
    required double tp1,
  }) {
    final double boundary = direction == SignalDirection.long
        ? entryHigh
        : entryLow;
    final double move = boundary <= 0.0 || tp1 <= 0.0
        ? 0.0
        : direction == SignalDirection.long
        ? (tp1 - boundary) / boundary * 100.0
        : (boundary - tp1) / boundary * 100.0;
    final double atrPercent = snapshot.ticker.price <= 0.0
        ? 0.0
        : snapshot.fifteenMinutes.atr / snapshot.ticker.price * 100.0;
    return FirstMoveRecord(
      tradingMode: style == SignalStyle.scalp ? 'MOMENTUM_SCALP' : 'INTRADAY',
      marketRegime: _marketRegime(snapshot),
      volatilityRegime: atrPercent >= 2.0
          ? 'HIGH'
          : atrPercent >= 0.8
          ? 'NORMAL'
          : 'LOW',
      btcState: snapshot.symbol == 'BTCUSDT' ? 'BENCHMARK' : 'PENDING',
      expectedMovePercent: move,
      atrPercent: atrPercent,
      spreadPercent: snapshot.ticker.spreadPercent,
    );
  }

  static String _marketRegime(MarketSnapshot snapshot) {
    final Bias fifteen = snapshot.fifteenMinutes.trend;
    final Bias hour = snapshot.oneHour.trend;
    if (fifteen == Bias.bullish && hour == Bias.bullish) return 'TREND_UP';
    if (fifteen == Bias.bearish && hour == Bias.bearish) return 'TREND_DOWN';
    if (fifteen == Bias.neutral && hour == Bias.neutral) return 'RANGE';
    return 'MIXED';
  }

  static double _maxDouble(double first, double second) {
    return first >= second ? first : second;
  }

  static double _minDouble(double first, double second) {
    return first <= second ? first : second;
  }

  static int _maxInt(int first, int second) {
    return first >= second ? first : second;
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

class _Levels {
  const _Levels({required this.support, required this.resistance});

  final double? support;
  final double? resistance;
}

class _Magnet {
  const _Magnet(this.price, this.label);

  final double price;
  final String label;
}
