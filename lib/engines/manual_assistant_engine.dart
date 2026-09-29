import 'dart:math' as math;

import '../models/decision_models.dart';
import '../models/execution_models.dart';
import '../models/exchange_confirmation_models.dart';
import '../models/live_market_models.dart';
import '../models/market_models.dart';
import '../models/position_calculator_models.dart';
import '../models/signal_models.dart';
import 'decision_engine.dart';
import 'entry_readiness_gate.dart';
import 'phase_a_engine.dart';
import 'position_calculator.dart';
import 'signal_engine.dart';

enum AssistantMode { continuation, scalp }

enum RetestState { none, breakoutDetected, waitingRetest, confirmed, failed }

class ManualPosition {
  const ManualPosition({
    required this.side,
    required this.entry,
    required this.stop,
    required this.initialStop,
    required this.quantity,
    required this.openedAt,
    this.partialTaken = false,
    this.qualityAtOpen,
    this.entryLowAtOpen,
    this.entryHighAtOpen,
    this.plannedTargets = const <double>[],
  });
  final SignalDirection side;
  final double entry, stop, initialStop, quantity;
  final DateTime openedAt;
  final bool partialTaken;
  final int? qualityAtOpen;
  final double? entryLowAtOpen;
  final double? entryHighAtOpen;
  final List<double> plannedTargets;
  double get sign => side == SignalDirection.long ? 1 : -1;
  ManualPosition protect(double value) {
    if (!value.isFinite || value <= 0 || (value - stop) * sign < 0) {
      throw ArgumentError('Стоп нельзя расширять');
    }
    return ManualPosition(
      side: side,
      entry: entry,
      stop: value,
      initialStop: initialStop,
      quantity: quantity,
      openedAt: openedAt,
      partialTaken: partialTaken,
      qualityAtOpen: qualityAtOpen,
      entryLowAtOpen: entryLowAtOpen,
      entryHighAtOpen: entryHighAtOpen,
      plannedTargets: plannedTargets,
    );
  }

  ManualPosition reduce(double remaining) {
    if (!remaining.isFinite || remaining <= 0 || remaining >= quantity) {
      throw ArgumentError('Остаток должен быть меньше текущего объёма');
    }
    return ManualPosition(
      side: side,
      entry: entry,
      stop: stop,
      initialStop: initialStop,
      quantity: remaining,
      openedAt: openedAt,
      partialTaken: true,
      qualityAtOpen: qualityAtOpen,
      entryLowAtOpen: entryLowAtOpen,
      entryHighAtOpen: entryHighAtOpen,
      plannedTargets: plannedTargets,
    );
  }

  Map<String, Object?> toJson() => {
    'side': side.name,
    'entry': entry,
    'stop': stop,
    'initialStop': initialStop,
    'quantity': quantity,
    'openedAt': openedAt.toIso8601String(),
    'partialTaken': partialTaken,
    'qualityAtOpen': qualityAtOpen,
    'entryLowAtOpen': entryLowAtOpen,
    'entryHighAtOpen': entryHighAtOpen,
    'plannedTargets': plannedTargets,
  };
  factory ManualPosition.fromJson(Map<String, dynamic> j) => ManualPosition(
    side: SignalDirection.values.byName(j['side'] as String),
    entry: (j['entry'] as num).toDouble(),
    stop: (j['stop'] as num).toDouble(),
    initialStop: (j['initialStop'] as num).toDouble(),
    quantity: (j['quantity'] as num).toDouble(),
    openedAt: DateTime.parse(j['openedAt'] as String),
    partialTaken: j['partialTaken'] == true,
    qualityAtOpen: (j['qualityAtOpen'] as num?)?.toInt(),
    entryLowAtOpen: (j['entryLowAtOpen'] as num?)?.toDouble(),
    entryHighAtOpen: (j['entryHighAtOpen'] as num?)?.toDouble(),
    plannedTargets: (j['plannedTargets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<num>()
        .map<double>((num value) => value.toDouble())
        .toList(growable: false),
  );
}

class AssistantResult {
  const AssistantResult({
    required this.state,
    required this.action,
    required this.reasons,
    required this.quality,
    required this.factors,
    required this.direction,
    required this.setup,
    required this.price,
    required this.decision,
    required this.signal,
    required this.retest,
    required this.context,
    required this.relativeStrength,
    required this.binanceConfirmation,
    required this.contextCoverage,
    required this.requiredNetRiskReward,
    required this.targets,
    required this.economics,
    this.suggestedStop,
    this.positionMovePercent,
    this.dynamicRiskReward,
    this.entryOutsidePlannedZone = false,
    this.threat = false,
  });
  final String state, action, direction, setup, context, relativeStrength;
  final String binanceConfirmation;
  final List<String> reasons;
  final Map<String, int> factors;
  final int quality;
  final int contextCoverage;
  final double price;
  final double requiredNetRiskReward;
  final DecisionSnapshot decision;
  final RadarSignal? signal;
  final RetestState retest;
  final List<double> targets;
  final SmartTradePlan? economics;
  final double? suggestedStop;
  final double? positionMovePercent;
  final double? dynamicRiskReward;
  final bool entryOutsidePlannedZone;
  final bool threat;
}

/// Manual assistance only. A READY result never records or executes a trade.
class ManualAssistantEngine {
  static AssistantResult evaluate({
    required MarketSnapshot market,
    MarketSnapshot? btc,
    MarketSnapshot? eth,
    MarketSnapshot? sol,
    ExchangeConfirmationSnapshot? binance,
    LivePriceTick? tick,
    required DateTime now,
    required AssistantMode mode,
    required double balance,
    required double riskPercent,
    required int maxLeverage,
    required FeeModel fees,
    double minPotentialPercent = 1,
    ManualPosition? position,
  }) {
    final freshTick =
        tick != null &&
        tick.symbol == market.symbol &&
        tick.price.isFinite &&
        tick.price > 0 &&
        !tick.receivedAt.isAfter(now) &&
        now.difference(tick.receivedAt) <= const Duration(seconds: 10) &&
        !tick.receivedAt.isBefore(
          market.ticker.sourceUpdatedAt ?? market.updatedAt,
        );
    final price = freshTick ? tick.price : market.ticker.price;
    // Reuse the existing analysis on the same candles with the current price.
    final live = _withPrice(market, price);
    final raw = mode == AssistantMode.scalp
        ? SignalEngine.createScalpSignal(live)
        : SignalEngine.createSignal(live);
    final signal = raw == null
        ? null
        : PhaseAEngine.preview(market: live, signal: raw);
    final decision = DecisionEngine.build(live, executionSignal: signal);
    final gate = EntryReadinessGate.evaluate(
      market: live,
      decision: decision,
      evaluatedAt: now,
    );
    final side =
        signal?.direction ??
        (market.tradePlan.bias == Bias.bearish
            ? SignalDirection.short
            : SignalDirection.long);
    final sign = side == SignalDirection.long ? 1.0 : -1.0;
    final direction = market.fifteenMinutes.trend == market.oneHour.trend
        ? market.oneHour.trend
        : Bias.neutral;
    final counter = direction != Bias.neutral && direction != side.bias;
    final List<MarketSnapshot> freshContextMarkets = <MarketSnapshot>[
      if (_freshContext(btc, now)) btc!,
      if (_freshContext(eth, now)) eth!,
      if (_freshContext(sol, now)) sol!,
    ];
    final int contextCoverage = freshContextMarkets.length;
    int contextScore = 0;
    if (_freshContext(btc, now)) contextScore += _momentum(btc!) * 2;
    if (_freshContext(eth, now)) contextScore += _momentum(eth!);
    if (_freshContext(sol, now)) contextScore += _momentum(sol!);
    final String context = contextCoverage == 0
        ? 'UNAVAILABLE'
        : contextScore >= 4
        ? 'STRONGLY_SUPPORTS_LONG'
        : contextScore > 0
        ? 'SUPPORTS_LONG'
        : contextScore <= -4
        ? 'STRONGLY_SUPPORTS_SHORT'
        : contextScore < 0
        ? 'SUPPORTS_SHORT'
        : 'NEUTRAL';
    final double contextAverageChange = freshContextMarkets.isEmpty
        ? 0.0
        : freshContextMarkets
                  .map<double>(_change)
                  .fold<double>(0.0, (double a, double b) => a + b) /
              freshContextMarkets.length;
    final double relative = contextCoverage == 0
        ? 0.0
        : _change(market) - contextAverageChange;
    final String relativeState = contextCoverage == 0
        ? 'UNAVAILABLE'
        : relative > .25
        ? 'FART_STRONG'
        : relative < -.25
        ? 'FART_WEAK'
        : 'FART_NEUTRAL';
    final bool binanceFresh =
        binance != null &&
        binance.symbol == market.symbol &&
        binance.isFreshAt(now);
    final int binanceScore = binanceFresh
        ? _binanceMomentum(binance!)
        : 0;
    final String binanceConfirmation = !binanceFresh
        ? 'UNAVAILABLE'
        : binanceScore >= 2
        ? 'SUPPORTS_LONG'
        : binanceScore <= -2
        ? 'SUPPORTS_SHORT'
        : 'NEUTRAL';
    final retest = detectRetest(
      market.fiveMinutes.candles,
      side,
      market.fiveMinutes.atr * .15,
    );
    final frame = mode == AssistantMode.scalp
        ? market.oneMinute
        : market.fiveMinutes;
    final recent = frame.candles;
    final impulse = recent.length >= 4
        ? (recent.last.close - recent[recent.length - 4].close) * sign
        : 0.0;
    final extended =
        frame.atr > 0 &&
        impulse > frame.atr * 2 &&
        (price - frame.ema20) * sign > frame.atr * 1.5;
    final targets = structuralTargets(market, price, side);
    final potential = targets.isEmpty || price <= 0
        ? 0.0
        : (targets.first - price).abs() / price * 100;
    final factors = <String, int>{
      'Структура': frame.structure.bias == side.bias ? 20 : 0,
      'Ликвидность': signal?.liquiditySweepConfirmed == true
          ? 15
          : (decision.qualityScores.liquidity * .1)
                .round()
                .clamp(0, 10)
                .toInt(),
      'Зона входа': gate.priceInZone && !extended ? 20 : 0,
      'Подтверждение': gate.entryConfirmed ? 15 : 0,
      'BTC / ETH / SOL': contextCoverage == 0
          ? 0
          : contextScore * sign > 0
          ? 10
          : contextScore == 0
          ? 5
          : 0,
      'Binance': !binanceFresh
          ? 0
          : binanceScore * sign > 0
          ? 10
          : binanceScore == 0
          ? 5
          : 0,
      'Относительная сила': contextCoverage == 0
          ? 0
          : relative * sign > .25
          ? 5
          : relative * sign >= -.25
          ? 3
          : 0,
      'Стоп / риск': gate.riskReady ? 10 : 0,
      'Retest': retest == RetestState.confirmed ? 5 : 0,
    };
    final int quality =
        (factors.values.fold<int>(0, (int a, int b) => a + b) -
                (counter ? 10 : 0))
            .clamp(0, 100)
            .toInt();
    final hard = <String>[];
    final wait = <String>[];
    if (!gate.marketDataReady || !gate.microstructureReady) {
      hard.add(
        'Данные устарели или неполны: ${gate.reasonCodes.where((r) => r.contains('DATA') || r.contains('STALE') || r.contains('RULES')).join(', ')}',
      );
    }
    if (!decision.stop.isFinite ||
        decision.stop <= 0 ||
        (price - decision.stop) * sign <= 0) {
      hard.add('SL некорректен или цена пересекла invalidation');
    }
    if (signal == null) wait.add('Нет подтверждённого сетапа выбранного типа');
    if (!gate.priceInZone) wait.add('Цена вне Entry Zone');
    if (!gate.entryConfirmed)
      wait.add('Ожидается закрытая подтверждающая свеча');
    // Liquidity improves quality, but a missing sweep is not a hidden veto.
    // Structural confirmation + zone + risk remain the mandatory entry checks.
    if (!gate.riskReady) wait.add('Качество Stop / R:R недостаточно');
    if (!gate.directionReady)
      wait.add('Направление сетапа недостаточно подтверждено');
    if (extended) wait.add('DO NOT CHASE: ждать откат или breakout + retest');
    if (retest == RetestState.breakoutDetected ||
        retest == RetestState.waitingRetest) {
      wait.add('Пробой есть, подтверждённого ретеста ещё нет');
    }
    if (retest == RetestState.failed) wait.add('Ретест не удержан');
    if (contextCoverage > 0 && contextScore * sign <= -4) {
      wait.add('BTC / ETH / SOL сильно против направления входа');
    }
    if (binanceFresh && binanceScore * sign <= -2) {
      wait.add('Binance подтверждает противоположный импульс');
    }
    if (counter &&
        (signal?.liquiditySweepConfirmed != true ||
            retest != RetestState.confirmed ||
            quality < 75)) {
      wait.add('Контртренд: нужны sweep, retest и качество не ниже 75');
    }
    if (mode == AssistantMode.continuation && potential < minPotentialPercent) {
      wait.add(
        'До первой структурной цели меньше ${minPotentialPercent.toStringAsFixed(2)}%',
      );
    }
    if (targets.isEmpty) wait.add('Нет структурной цели впереди цены');
    SmartTradePlan? economics;
    final double requiredNetRiskReward = _requiredNetRiskReward(quality, counter);
    final bool accountConfigured =
        balance.isFinite &&
        balance > 0 &&
        riskPercent.isFinite &&
        riskPercent > 0 &&
        riskPercent <= 2 &&
        maxLeverage >= 1;
    if (accountConfigured && targets.isNotEmpty &&
        decision.stop > 0 &&
        (price - decision.stop) * sign > 0) {
      final rules = market.tradingRules;
      economics = PositionCalculator.calculate(
        input: SmartPositionInput(
          symbol: market.symbol,
          direction: side,
          decisionAction: side == SignalDirection.long
              ? DecisionAction.long
              : DecisionAction.short,
          signalStage: signal?.stage ?? SignalStage.setupFound,
          currentPrice: price,
          entryZoneLow: decision.entryLow,
          entryZoneHigh: decision.entryHigh,
          entry: price,
          stop: decision.stop,
          tp1: targets.first,
          tp2: targets.length > 1 ? targets[1] : targets.first,
          tp3: targets.length > 2 ? targets[2] : null,
          targetAllocations: targets.length == 1 ? const [1, 0] : const [],
          confidence: quality,
          atr: frame.atr,
          volatilityPercent: price > 0 ? frame.atr / price * 800 : 0,
          marketRegime: decision.marketRegime,
          setupType: '${side.name} ${mode.name}',
          allocatedMargin: balance,
          riskPercent: riskPercent,
          personalMaxLeverage: maxLeverage,
          exchangeMaxLeverage: rules?.maxLeverage ?? 0,
          tickSize: rules?.tickSize ?? 0,
          quantityStep: rules?.quantityStep ?? 0,
          minOrderQuantity: rules?.minOrderQuantity ?? 0,
          minNotional: rules?.minNotional ?? 0,
          observedSpreadPercent: market.ticker.spreadPercent,
          bidPrice: market.ticker.bidPrice,
          askPrice: market.ticker.askPrice,
        ),
        feeModel: fees,
      );
      if (economics.validationIssues.isNotEmpty) {
        hard.addAll(economics.validationIssues.map((v) => v.message));
      }
      if (economics.quantity <= 0 ||
          economics.margin > balance ||
          economics.stopOutcome.expectedLoss >
              balance * riskPercent / 100 + .01) {
        hard.add('Расчёт превышает допустимый риск или доступную маржу');
      }
      if (economics.netRiskReward < requiredNetRiskReward ||
          economics.targets.first.netProfit <= 0) {
        wait.add(
          'Недостаточный Net R:R: ${economics.netRiskReward.toStringAsFixed(2)} < ${requiredNetRiskReward.toStringAsFixed(2)}',
        );
      }
    } else if (decision.riskReward.isFinite &&
        decision.riskReward < requiredNetRiskReward) {
      wait.add(
        'Недостаточный структурный R:R: ${decision.riskReward.toStringAsFixed(2)} < ${requiredNetRiskReward.toStringAsFixed(2)}',
      );
    }
    String state = hard.isNotEmpty
        ? 'NO TRADE'
        : wait.isNotEmpty
        ? 'WAIT'
        : 'READY';
    String action = state == 'READY'
        ? 'Вход допустим по текущим данным. Решение принимаешь ты.'
        : hard.isNotEmpty
        ? 'Новый вход запрещён: устранить указанную причину.'
        : extended
        ? 'Ждать откат с удержанием структуры или подтверждённый ретест.'
        : 'Ждать выполнения условий в списке.';
    double? suggestedStop;
    double? positionMovePercent;
    double? dynamicRiskReward;
    bool entryOutsidePlannedZone = false;
    bool threat = false;
    List<String> reasons = [...hard, ...wait];
    if (position != null) {
      final pnlDistance = (price - position.entry) * position.sign;
      positionMovePercent = position.entry > 0
          ? pnlDistance / position.entry * 100
          : null;
      entryOutsidePlannedZone =
          position.entryLowAtOpen != null &&
          position.entryHighAtOpen != null &&
          (position.entry < position.entryLowAtOpen! ||
              position.entry > position.entryHighAtOpen!);
      double? nextTarget;
      for (final double target in position.plannedTargets) {
        if ((target - price) * position.sign > 0) {
          nextTarget = target;
          break;
        }
      }
      final double currentStopDistance = (price - position.stop) * position.sign;
      if (nextTarget != null && currentStopDistance > 0) {
        final double rewardDistance = (nextTarget - price) * position.sign;
        if (rewardDistance > 0) {
          dynamicRiskReward = rewardDistance / currentStopDistance;
        }
      }
      final initialRisk = (position.entry - position.initialStop).abs();
      final adverseStructure =
          market.fiveMinutes.structure.bos != Bias.neutral &&
          market.fiveMinutes.structure.bos != position.side.bias;
      final bool broadThreat =
          contextCoverage > 0 && contextScore * position.sign <= -4;
      final bool binanceThreat =
          binanceFresh && binanceScore * position.sign <= -2;
      threat = broadThreat || binanceThreat;
      final invalidated = (price - position.stop) * position.sign <= 0;
      if (!gate.marketDataReady || !gate.microstructureReady) {
        state = 'PROTECT';
        action =
            'Данные недостоверны. Проверить позицию и защитный стоп на бирже.';
        reasons = ['Невозможно надёжно оценить открытую позицию'];
      } else if (invalidated || (adverseStructure && threat)) {
        state = 'EXIT';
        action = 'Идея нарушена. Проверить фактическую позицию и рассмотреть закрытие вручную.';
        reasons = [
          invalidated
              ? 'Цена пересекла текущий защитный стоп'
              : 'FART подтвердил движение против позиции на фоне внешнего рынка',
        ];
      } else if (threat ||
          (initialRisk > 0 && pnlDistance >= initialRisk) ||
          (positionMovePercent != null && positionMovePercent >= 1) ||
          position.partialTaken) {
        state = 'PROTECT';
        action = 'Не добавлять. Рассмотреть частичную фиксацию и защиту по структуре.';
        reasons = [
          if (threat) 'EXTERNAL THREAT: рынок / Binance против позиции',
          if (initialRisk > 0 && pnlDistance >= initialRisk)
            'Движение достигло первоначального 1R',
          if (positionMovePercent != null && positionMovePercent >= 1)
            'Цена уже прошла не меньше 1% в пользу позиции — результат нужно переоценить и защитить',
          if (entryOutsidePlannedZone)
            'Фактический Entry был вне плановой зоны — не добавлять к позиции',
          if (position.partialTaken)
            'Частичная фиксация отмечена пользователем',
        ];
        final structural = position.side == SignalDirection.long
            ? market.fiveMinutes.support
            : market.fiveMinutes.resistance;
        final confirmedMove =
            market.fiveMinutes.structure.bias == position.side.bias &&
            pnlDistance >= initialRisk;
        if (position.partialTaken || confirmedMove) {
          final candidate = structural == null
              ? position.stop
              : structural - position.sign * market.fiveMinutes.atr * .15;
          if ((candidate - position.stop) * position.sign > 0 &&
              (price - candidate) * position.sign >
                  market.fiveMinutes.atr * .2) {
            suggestedStop = candidate;
          }
        }
      } else {
        state = 'HOLD';
        action = entryOutsidePlannedZone
            ? 'Структура пока жива, но фактический Entry был вне плановой зоны. Не добавлять; стоп не расширять.'
            : 'Удерживать по плану; не расширять стоп.';
        reasons = [
          if (entryOutsidePlannedZone)
            'Фактический Entry был вне плановой зоны — качество входа ниже исходного плана',
          if (contextCoverage == 0 && !binanceFresh)
            'Внешний контекст недоступен — контролировать позицию вручную',
          'Текущий стоп не нарушен; нового Entry Signal нет',
        ];
      }
    }
    return AssistantResult(
      state: state,
      action: action,
      reasons: reasons,
      quality: quality,
      factors: factors,
      direction: direction.name.toUpperCase(),
      setup:
          '${side.name.toUpperCase()} ${mode.name.toUpperCase()}${counter ? ' · COUNTERTREND' : ''}',
      price: price,
      decision: decision,
      signal: signal,
      retest: retest,
      context: context,
      relativeStrength: relativeState,
      binanceConfirmation: binanceConfirmation,
      contextCoverage: contextCoverage,
      requiredNetRiskReward: requiredNetRiskReward,
      targets: targets,
      economics: economics,
      suggestedStop: suggestedStop,
      positionMovePercent: positionMovePercent,
      dynamicRiskReward: dynamicRiskReward,
      entryOutsidePlannedZone: entryOutsidePlannedZone,
      threat: threat,
    );
  }

  static int _binanceMomentum(ExchangeConfirmationSnapshot snapshot) {
    int score = 0;
    for (final Bias trend in <Bias>[
      snapshot.trend5m,
      snapshot.trend15m,
      snapshot.trend1h,
    ]) {
      if (trend == Bias.bullish) score++;
      if (trend == Bias.bearish) score--;
    }
    if (snapshot.relativeVolume5m >= 1.35) {
      if (snapshot.change5mPercent > .10) score++;
      if (snapshot.change5mPercent < -.10) score--;
    }
    return score.clamp(-4, 4).toInt();
  }

  static double _requiredNetRiskReward(int quality, bool counterTrend) {
    if (counterTrend || quality < 65) return 2.5;
    if (quality >= 85) return 1.7;
    return 2.0;
  }

  static bool _freshContext(MarketSnapshot? m, DateTime now) =>
      m != null &&
      !m.dataIntegrity.hasCriticalIssue &&
      !m.updatedAt.isAfter(now) &&
      now.difference(m.updatedAt) <= const Duration(seconds: 60) &&
      m.fiveMinutes.candles.length >= 4;
  static double _change(MarketSnapshot m) {
    final c = m.fiveMinutes.candles;
    if (c.length < 4 || c[c.length - 4].close <= 0) return 0;
    return (c.last.close / c[c.length - 4].close - 1) * 100;
  }

  static int _momentum(MarketSnapshot m) {
    final change = _change(m);
    return (change > .1
            ? 1
            : change < -.1
            ? -1
            : 0) +
        (m.fiveMinutes.structure.bias == Bias.bullish
            ? 1
            : m.fiveMinutes.structure.bias == Bias.bearish
            ? -1
            : 0);
  }

  static List<double> structuralTargets(
    MarketSnapshot m,
    double price,
    SignalDirection side,
  ) {
    final sign = side == SignalDirection.long ? 1 : -1;
    final levels = <double>{};
    for (final f in [m.fiveMinutes, m.fifteenMinutes, m.oneHour]) {
      for (final p in [
        f.support,
        f.resistance,
        f.liquidity.above,
        f.liquidity.below,
        f.structure.lastSwingHigh,
        f.structure.lastSwingLow,
      ]) {
        if (p != null && p.isFinite && p > 0 && (p - price) * sign > 0)
          levels.add(p);
      }
    }
    final sorted = levels.toList()
      ..sort((a, b) => ((a - price).abs()).compareTo((b - price).abs()));
    return sorted.take(3).toList();
  }

  static RetestState detectRetest(
    List<Candle> candles,
    SignalDirection side,
    double tolerance,
  ) {
    if (candles.length < 12) return RetestState.none;
    final sign = side == SignalDirection.long ? 1.0 : -1.0;
    for (
      int i = candles.length - 1;
      i >= math.max(10, candles.length - 12);
      i--
    ) {
      final previous = candles.sublist(i - 10, i);
      final level = side == SignalDirection.long
          ? previous.map((c) => c.high).reduce(math.max)
          : previous.map((c) => c.low).reduce(math.min);
      if ((candles[i].close - level) * sign <= tolerance) continue;
      if (i == candles.length - 1) return RetestState.breakoutDetected;
      var confirmed = false;
      for (final c in candles.skip(i + 1)) {
        if ((c.close - level) * sign < -tolerance) return RetestState.failed;
        final touches =
            c.low <= level + tolerance && c.high >= level - tolerance;
        if (touches &&
            (c.close - level) * sign > 0 &&
            (c.close - c.open) * sign > 0)
          confirmed = true;
      }
      return confirmed ? RetestState.confirmed : RetestState.waitingRetest;
    }
    return RetestState.none;
  }

  static MarketSnapshot _withPrice(MarketSnapshot m, double price) =>
      MarketSnapshot(
        symbol: m.symbol,
        ticker: m.ticker.copyWith(price: price),
        oneMinute: m.oneMinute,
        fiveMinutes: m.fiveMinutes,
        fifteenMinutes: m.fifteenMinutes,
        oneHour: m.oneHour,
        confirmations: m.confirmations,
        longScore: m.longScore,
        shortScore: m.shortScore,
        signal: m.signal,
        strength: m.strength,
        magnetPrice: m.magnetPrice,
        magnetLabel: m.magnetLabel,
        potentialPercent: m.potentialPercent,
        expectedLow: m.expectedLow,
        expectedHigh: m.expectedHigh,
        tradePlan: m.tradePlan,
        updatedAt: m.updatedAt,
        tradingRules: m.tradingRules,
        dataIntegrity: m.dataIntegrity,
      );
}
