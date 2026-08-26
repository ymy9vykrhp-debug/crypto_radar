import '../models/market_models.dart';
import '../models/signal_models.dart';
import '../models/execution_models.dart';

class TradeTracker {
  const TradeTracker({
    this.standardEntryTimeout = const Duration(hours: 12),
    this.scalpEntryTimeout = const Duration(minutes: 15),
  });

  final Duration standardEntryTimeout;
  final Duration scalpEntryTimeout;

  RadarSignal consume(RadarSignal source, Candle candle) {
    final DateTime? lastTracked = source.lastTrackedCandleTime;
    if (lastTracked != null && !candle.time.isAfter(lastTracked)) {
      return source;
    }
    if (source.status == SignalStatus.stopped && source.needsPostStopTracking) {
      return _trackAfterStop(source, candle);
    }
    if (!source.status.isActive) {
      return source;
    }

    RadarSignal signal = source.copyWith(lastTrackedCandleTime: candle.time);
    if (signal.status == SignalStatus.waitingEntry) {
      final Duration entryTimeout = signal.style == SignalStyle.scalp
          ? scalpEntryTimeout
          : standardEntryTimeout;
      if (candle.time.difference(signal.time) >= entryTimeout) {
        return signal.copyWith(
          status: SignalStatus.expired,
          stage: SignalStage.expired,
          exitTime: candle.time,
        );
      }
      if (signal.stage != SignalStage.entryConfirmed) {
        return signal;
      }
      if (signal.entryConfirmedTime != null &&
          candle.time.isBefore(signal.entryConfirmedTime!)) {
        return signal;
      }
      final bool entered = signal.entryVariant == EntryVariant.immediate
          ? true
          : candle.low <= signal.entryHigh && candle.high >= signal.entryLow;
      if (!entered) {
        return signal;
      }
      signal = signal.copyWith(
        status: SignalStatus.inPosition,
        stage: SignalStage.inPosition,
        entryTime: candle.time,
      );
    }

    return _trackPosition(signal, candle);
  }

  RadarSignal consumeAll(RadarSignal source, Iterable<Candle> candles) {
    RadarSignal result = source;
    for (final Candle candle in candles) {
      result = consume(result, candle);
      if (!result.status.isActive && !result.needsPostStopTracking) {
        break;
      }
    }
    return result;
  }

  RadarSignal closeAtEnd(RadarSignal source, Candle candle) {
    if (!source.status.isActive) {
      return source;
    }
    if (source.status == SignalStatus.waitingEntry) {
      return source.copyWith(
        status: SignalStatus.cancelled,
        stage: SignalStage.cancelled,
        exitTime: candle.time,
        lastTrackedCandleTime: candle.time,
      );
    }
    final double risk = source.risk;
    final double currentR = risk == 0.0
        ? 0.0
        : source.direction == SignalDirection.long
        ? (candle.close - source.entryPrice) / risk
        : (source.entryPrice - candle.close) / risk;
    final double resultR = source.tp1Time == null
        ? currentR
        : (_targetR(source.tp1, source) + currentR) / 2.0;
    return source.copyWith(
      status: SignalStatus.cancelled,
      stage: SignalStage.cancelled,
      exitTime: candle.time,
      lastTrackedCandleTime: candle.time,
      resultR: resultR,
    );
  }

  RadarSignal _trackPosition(RadarSignal source, Candle candle) {
    final double risk = source.risk;
    if (risk == 0.0) {
      return source.copyWith(
        status: SignalStatus.cancelled,
        stage: SignalStage.cancelled,
        exitTime: candle.time,
      );
    }

    final double favorable = source.direction == SignalDirection.long
        ? candle.high - source.entryPrice
        : source.entryPrice - candle.low;
    final double adverse = source.direction == SignalDirection.long
        ? source.entryPrice - candle.low
        : candle.high - source.entryPrice;
    final double favorablePercent = source.entryPrice == 0.0
        ? 0.0
        : favorable / source.entryPrice * 100.0;
    final double adversePercent = source.entryPrice == 0.0
        ? 0.0
        : adverse / source.entryPrice * 100.0;
    RadarSignal signal = source.copyWith(
      mfeR: _maxDouble(source.mfeR, favorable / risk),
      maeR: _maxDouble(source.maeR, adverse / risk),
      mfePercent: _maxDouble(source.mfePercent, favorablePercent),
      maePercent: _maxDouble(source.maePercent, adversePercent),
    );

    final bool breakEvenStop =
        signal.style == SignalStyle.scalp && signal.tp1Time != null;
    final double effectiveStop = breakEvenStop
        ? signal.entryPrice
        : signal.stop;
    final bool stopTouched = signal.direction == SignalDirection.long
        ? candle.low <= effectiveStop
        : candle.high >= effectiveStop;
    final bool tp1Touched = signal.direction == SignalDirection.long
        ? candle.high >= signal.tp1
        : candle.low <= signal.tp1;
    final bool tp2Touched = signal.direction == SignalDirection.long
        ? candle.high >= signal.tp2
        : candle.low <= signal.tp2;

    // A 5m candle does not reveal the intrabar order. If stop and target are
    // both touched, the conservative assumption is that the stop came first.
    if (stopTouched) {
      final double resultR = signal.tp1Time == null
          ? -1.0
          : signal.style == SignalStyle.scalp
          ? _targetR(signal.tp1, signal) / 2.0
          : (_targetR(signal.tp1, signal) - 1.0) / 2.0;
      final double invalidation = signal.invalidationPrice > 0.0
          ? signal.invalidationPrice
          : signal.stop;
      final double extreme = signal.direction == SignalDirection.long
          ? candle.low
          : candle.high;
      final double overshoot = signal.direction == SignalDirection.long
          ? _maxDouble(0.0, invalidation - candle.low)
          : _maxDouble(0.0, candle.high - invalidation);
      final bool reclaimed = signal.direction == SignalDirection.long
          ? candle.close > invalidation
          : candle.close < invalidation;
      final Duration aftermathWindow = signal.style == SignalStyle.scalp
          ? const Duration(minutes: 30)
          : const Duration(hours: 2);
      return signal.copyWith(
        status: SignalStatus.stopped,
        stage: SignalStage.stopped,
        exitTime: candle.time,
        stopTime: candle.time,
        maximumOvershootPrice: extreme,
        overshootPoints: overshoot,
        overshootPercent: signal.entryPrice == 0.0
            ? 0.0
            : overshoot / signal.entryPrice * 100.0,
        overshootAtr: signal.stopBufferAtr == 0.0 || signal.stopBuffer == 0.0
            ? 0.0
            : overshoot / (signal.stopBuffer / signal.stopBufferAtr),
        timeOutsideLevelSeconds: _candleDuration(signal).inSeconds,
        reclaimedLevel: reclaimed,
        postStopTrackingUntil: candle.time.add(aftermathWindow),
        resultR: resultR,
      );
    }
    if (tp2Touched) {
      final double resultR =
          (_targetR(signal.tp1, signal) + _targetR(signal.tp2, signal)) / 2.0;
      return signal.copyWith(
        status: SignalStatus.tp2Hit,
        stage: SignalStage.tp2Hit,
        tp1Time: signal.tp1Time ?? candle.time,
        tp2Time: candle.time,
        exitTime: candle.time,
        resultR: resultR,
      );
    }
    if (tp1Touched && signal.tp1Time == null) {
      return signal.copyWith(
        status: SignalStatus.tp1Hit,
        stage: SignalStage.tp1Hit,
        tp1Time: candle.time,
      );
    }
    return signal;
  }

  RadarSignal _trackAfterStop(RadarSignal source, Candle candle) {
    final DateTime until = source.postStopTrackingUntil!;
    if (candle.time.isAfter(until)) {
      return source.copyWith(lastTrackedCandleTime: until);
    }
    final double invalidation = source.invalidationPrice > 0.0
        ? source.invalidationPrice
        : source.stop;
    final bool long = source.direction == SignalDirection.long;
    final double extreme = long ? candle.low : candle.high;
    final double previousExtreme = source.maximumOvershootPrice;
    final double maximumExtreme = previousExtreme == 0.0
        ? extreme
        : long
        ? _minDouble(previousExtreme, extreme)
        : _maxDouble(previousExtreme, extreme);
    final double currentOvershoot = long
        ? _maxDouble(0.0, invalidation - candle.low)
        : _maxDouble(0.0, candle.high - invalidation);
    final double overshoot = _maxDouble(
      source.overshootPoints,
      currentOvershoot,
    );
    final bool outside = long
        ? candle.low < invalidation
        : candle.high > invalidation;
    final bool reclaimed =
        source.reclaimedLevel ||
        (long ? candle.close > invalidation : candle.close < invalidation);
    final bool tp1After =
        source.postStopTp1 ||
        (long ? candle.high >= source.tp1 : candle.low <= source.tp1);
    final bool tp2After =
        source.postStopTp2 ||
        (long ? candle.high >= source.tp2 : candle.low <= source.tp2);
    final List<String> codes = List<String>.of(source.reasonCodes);
    if ((tp1After || tp2After) && !codes.contains('STOP_THEN_TARGET')) {
      codes.add('STOP_THEN_TARGET');
    }
    return source.copyWith(
      lastTrackedCandleTime: candle.time,
      maximumOvershootPrice: maximumExtreme,
      overshootPoints: overshoot,
      overshootPercent: source.entryPrice == 0.0
          ? 0.0
          : overshoot / source.entryPrice * 100.0,
      overshootAtr: source.stopBufferAtr == 0.0 || source.stopBuffer == 0.0
          ? 0.0
          : overshoot / (source.stopBuffer / source.stopBufferAtr),
      timeOutsideLevelSeconds:
          source.timeOutsideLevelSeconds +
          (outside ? _candleDuration(source).inSeconds : 0),
      reclaimedLevel: reclaimed,
      postStopTp1: tp1After,
      postStopTp2: tp2After,
      reasonCodes: codes,
      postStopTrackingUntil: until,
    );
  }

  Duration _candleDuration(RadarSignal signal) {
    return signal.style == SignalStyle.scalp
        ? const Duration(minutes: 1)
        : const Duration(minutes: 5);
  }

  double _targetR(double target, RadarSignal signal) {
    return (target - signal.entryPrice).abs() / signal.risk;
  }

  double _maxDouble(double first, double second) {
    return first >= second ? first : second;
  }

  double _minDouble(double first, double second) {
    return first <= second ? first : second;
  }
}
