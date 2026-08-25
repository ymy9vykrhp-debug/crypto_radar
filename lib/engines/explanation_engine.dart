import '../models/decision_models.dart';
import '../models/market_models.dart';

/// Produces human-readable text from a completed decision contract.
/// It has no access to candles and cannot change prices or the decision.
class ExplanationEngine {
  const ExplanationEngine._();

  static DecisionExplanation explain(DecisionSnapshot snapshot) {
    final List<DecisionReason> supporting = snapshot.reasonCodes
        .map<DecisionReason>(
          (ReasonCode code) =>
              _reason(snapshot, code, ReasonSeverity.supporting),
        )
        .toList(growable: false);
    final List<DecisionReason> opposing = snapshot.warningCodes
        .map<DecisionReason>(
          (ReasonCode code) => _reason(snapshot, code, ReasonSeverity.warning),
        )
        .toList(growable: false);
    final List<String> invalidation = snapshot.invalidationCodes
        .map<String>(
          (ReasonCode code) =>
              _reason(snapshot, code, ReasonSeverity.invalidation).detail,
        )
        .toList(growable: false);

    return DecisionExplanation(
      whatIsHappening: _whatIsHappening(snapshot),
      whyDecision: _whyDecision(snapshot),
      supporting: supporting,
      opposing: opposing,
      whatWeWaitFor: _whatWeWaitFor(snapshot),
      entryExplanation: _entryExplanation(snapshot),
      stopExplanation: _stopExplanation(snapshot),
      targetExplanation: _targetExplanation(snapshot),
      invalidation: invalidation,
      whatChangesMind: _whatChangesMind(snapshot),
      riskNotice:
          'Signal Strength ${snapshot.signalScore}/100 — это сила совпадения '
          'факторов, а не вероятность прибыли. Режим рынка пока является '
          'предварительной сводкой; полноценный Regime Engine запланирован на '
          'Phase 6.',
    );
  }

  static String _whatIsHappening(DecisionSnapshot snapshot) {
    final String trends = snapshot.timeframeTrends.entries
        .map<String>((MapEntry<String, Bias> item) {
          return '${item.key}: ${item.value.label}';
        })
        .join(', ');
    final String correction = switch (snapshot.correctionState) {
      'BULLISH_5M_CORRECTION_ACTIVE' =>
        'На 5м активна коррекция вверх против базового сценария.',
      'BEARISH_5M_CORRECTION_ACTIVE' =>
        'На 5м активна коррекция вниз против базового сценария.',
      '5M_CORRECTION_UNCONFIRMED' =>
        'Состояние 5м-коррекции пока не подтверждено.',
      _ => 'Подтверждённая встречная 5м-коррекция не обнаружена.',
    };
    return 'Предварительный режим: ${snapshot.marketRegime.label}. '
        '$trends. $correction';
  }

  static String _whyDecision(DecisionSnapshot snapshot) {
    switch (snapshot.decision) {
      case DecisionAction.long:
        return 'Текущий SignalEngine выбрал LONG: преимущество бычьих '
            'подтверждений достигло рабочего порога. Состояние входа: '
            '${snapshot.entryDecision.label}.';
      case DecisionAction.short:
        return 'Текущий SignalEngine выбрал SHORT: преимущество медвежьих '
            'подтверждений достигло рабочего порога. Состояние входа: '
            '${snapshot.entryDecision.label}.';
      case DecisionAction.wait:
        return 'Решение WAIT означает, что разница подтверждений пока не даёт '
            'достаточного преимущества. Это осознанный результат, а не ошибка '
            'или отсутствие данных.';
    }
  }

  static List<String> _whatWeWaitFor(DecisionSnapshot snapshot) {
    final List<String> result = <String>[];
    if (snapshot.decision == DecisionAction.wait) {
      result.add(
        'Согласование направления 15м и 1ч и преимущество матрицы не менее рабочего порога.',
      );
    }
    if (snapshot.entryDecision == EntryDecision.waitForZone) {
      result.add(
        'Возврат цены в зону ${_price(snapshot.entryLow)} — ${_price(snapshot.entryHigh)} без слома сценария.',
      );
    }
    if (snapshot.entryDecision == EntryDecision.tooLate) {
      result.add(
        'Новый сетап или безопасный ретест — текущую цену не догоняем.',
      );
    }
    if (snapshot.warningCodes.contains(ReasonCode.noStructureConfirmation)) {
      result.add('Подтверждённый BOS в сторону сценария.');
    }
    if (snapshot.warningCodes.contains(ReasonCode.correctionNotFinished)) {
      result.add('Завершение встречной 5м-коррекции.');
    }
    if (snapshot.warningCodes.contains(ReasonCode.rvolLow)) {
      result.add('Усиление относительного объёма вместо слабого RVOL.');
    }
    if (result.isEmpty) {
      result.add('Удержание зоны входа и отсутствие сигнала отмены.');
    }
    return List<String>.unmodifiable(result);
  }

  static String _entryExplanation(DecisionSnapshot snapshot) {
    final String zone =
        '${_price(snapshot.entryLow)} — ${_price(snapshot.entryHigh)}';
    switch (snapshot.entryDecision) {
      case EntryDecision.enterNow:
        return 'Текущая цена ${_price(snapshot.price)} находится внутри '
            'расчётной зоны $zone. Это разрешает вход по текущей модели, но не '
            'гарантирует результат.';
      case EntryDecision.waitForZone:
        return 'Оптимальная зона — $zone. Текущая цена '
            '${_price(snapshot.price)} находится вне неё либо базовый сигнал '
            'ещё WAIT, поэтому радар не предлагает догонять движение.';
      case EntryDecision.tooLate:
        return 'Цена ${_price(snapshot.price)} уже слишком далеко прошла от '
            'зоны $zone относительно ATR. Вход помечен ENTRY TOO LATE; нужен '
            'ретест или новый сетап.';
    }
  }

  static String _stopExplanation(DecisionSnapshot snapshot) {
    final String side = snapshot.stop < snapshot.entryLow ? 'ниже' : 'выше';
    return 'Stop ${_price(snapshot.stop)} расположен $side расчётной зоны '
        'входа с учётом текущей 15м-волатильности. Его пересечение означает '
        'техническую отмену сценария; улучшенный структурный Stop Engine '
        'добавляется в следующих фазах.';
  }

  static String _targetExplanation(DecisionSnapshot snapshot) {
    return 'TP1 ${_price(snapshot.tp1)} — первая расчётная цель '
        '(примерно ${snapshot.riskReward.toStringAsFixed(2)}R). '
        'TP2 ${_price(snapshot.tp2)} — расширенная цель. Ценовой магнит '
        '${_price(snapshot.priceMagnet)} и ожидаемый ход '
        '${snapshot.expectedMovePercent.toStringAsFixed(2)}% являются '
        'эвристическими ориентирами, а не гарантированными целями.';
  }

  static List<String> _whatChangesMind(DecisionSnapshot snapshot) {
    switch (snapshot.decision) {
      case DecisionAction.long:
        return <String>[
          'LONG → WAIT: исчезает BOS, объём ослабевает или цена теряет зону входа.',
          'LONG → SHORT: 15м CHOCH вниз, медвежий BOS и закрепление ниже поддержки.',
        ];
      case DecisionAction.short:
        return <String>[
          'SHORT → WAIT: исчезает BOS, объём продавца ослабевает или цена теряет зону входа.',
          'SHORT → LONG: 15м CHOCH вверх, бычий BOS и закрепление выше сопротивления.',
        ];
      case DecisionAction.wait:
        return <String>[
          'WAIT → LONG: согласованные бычьи 15м/1ч, бычий BOS и приемлемая зона входа.',
          'WAIT → SHORT: согласованные медвежьи 15м/1ч, медвежий BOS и приемлемая зона входа.',
        ];
    }
  }

  static DecisionReason _reason(
    DecisionSnapshot snapshot,
    ReasonCode code,
    ReasonSeverity severity,
  ) {
    final (String, String) text = switch (code) {
      ReasonCode.bullish1mStructure => (
        '1м бычий',
        'Минутный тренд направлен вверх.',
      ),
      ReasonCode.bearish1mStructure => (
        '1м медвежий',
        'Минутный тренд направлен вниз.',
      ),
      ReasonCode.bullish5mStructure => (
        '5м бычий',
        'Пятиминутный тренд поддерживает LONG-сценарий.',
      ),
      ReasonCode.bearish5mStructure => (
        '5м медвежий',
        'Пятиминутный тренд поддерживает SHORT-сценарий.',
      ),
      ReasonCode.bullish15mStructure => (
        '15м бычий',
        'Структура 15м поддерживает движение вверх.',
      ),
      ReasonCode.bearish15mStructure => (
        '15м медвежий',
        'Структура 15м поддерживает движение вниз.',
      ),
      ReasonCode.bullish1hStructure => (
        '1ч бычий',
        'Часовой контекст направлен вверх.',
      ),
      ReasonCode.bearish1hStructure => (
        '1ч медвежий',
        'Часовой контекст направлен вниз.',
      ),
      ReasonCode.bullish5mCorrection => (
        '5м коррекция вверх',
        'Локальное движение вверх идёт против базового сценария.',
      ),
      ReasonCode.bearish5mCorrection => (
        '5м коррекция вниз',
        'Локальное движение вниз идёт против базового сценария.',
      ),
      ReasonCode.correctionNotFinished => (
        'Коррекция не завершена',
        'Признаков завершения встречной 5м-коррекции пока недостаточно.',
      ),
      ReasonCode.bosConfirmed => (
        'BOS подтверждён',
        '15м BOS совпадает с направлением сценария.',
      ),
      ReasonCode.chochWarning => (
        'CHOCH против сценария',
        '15м CHOCH указывает на возможную смену характера движения.',
      ),
      ReasonCode.bullishChoch => (
        'Бычий CHOCH',
        'Бычий CHOCH способен отменить медвежий сценарий.',
      ),
      ReasonCode.bearishChoch => (
        'Медвежий CHOCH',
        'Медвежий CHOCH способен отменить бычий сценарий.',
      ),
      ReasonCode.strongResistanceAbove => (
        'Сопротивление выше',
        'Над ценой находится область сопротивления.',
      ),
      ReasonCode.strongSupportBelow => (
        'Поддержка ниже',
        'Под ценой находится область поддержки.',
      ),
      ReasonCode.bearishOrderBlock => (
        'Bearish Order Block',
        'Найден медвежий Order Block в контексте 15м.',
      ),
      ReasonCode.bullishOrderBlock => (
        'Bullish Order Block',
        'Найден бычий Order Block в контексте 15м.',
      ),
      ReasonCode.fvgConfluence => (
        'FVG confluence',
        'FVG совпадает с направлением базового сценария.',
      ),
      ReasonCode.liquidityAbove => (
        'Ликвидность выше',
        'Обнаружен ближайший пул ликвидности над ценой.',
      ),
      ReasonCode.liquidityBelow => (
        'Ликвидность ниже',
        'Обнаружен ближайший пул ликвидности под ценой.',
      ),
      ReasonCode.liquiditySweep => (
        'Liquidity Sweep',
        'Зафиксирован sweep в пользу текущего сценария.',
      ),
      ReasonCode.rvolHigh => (
        'RVOL высокий',
        'Relative Volume ${snapshot.relativeVolume.toStringAsFixed(2)}× подтверждает активность.',
      ),
      ReasonCode.rvolLow => (
        'RVOL слабый',
        'Relative Volume ${snapshot.relativeVolume.toStringAsFixed(2)}× недостаточен для сильного подтверждения.',
      ),
      ReasonCode.rvolAverage => (
        'RVOL средний',
        'Relative Volume ${snapshot.relativeVolume.toStringAsFixed(2)}× не даёт сильного преимущества.',
      ),
      ReasonCode.atrHigh => (
        'Высокая волатильность',
        'ATR относительно цены повышен; риск проскальзывания и широкого стопа выше.',
      ),
      ReasonCode.entryTooLate => (
        'Вход опоздал',
        'Цена слишком далеко ушла от расчётной зоны входа.',
      ),
      ReasonCode.entryAtGoodZone => (
        'Цена в зоне',
        'Текущая цена находится внутри расчётной зоны входа.',
      ),
      ReasonCode.waitForEntryZone => (
        'Ждём зону',
        'Цена должна вернуться в расчётную зону без отмены сценария.',
      ),
      ReasonCode.riskRewardPoor => (
        'R:R слабый',
        'Расчётное отношение риска к TP1 ниже 1:1.',
      ),
      ReasonCode.riskRewardGood => (
        'R:R допустимый',
        'Расчётное отношение до TP1 не ниже 1:1.',
      ),
      ReasonCode.timeframeConflict => (
        'Конфликт таймфреймов',
        'Тренды 5м, 15м и 1ч не полностью согласованы.',
      ),
      ReasonCode.newsRiskHigh => (
        'Высокий новостной риск',
        'Важное событие требует паузы; News Engine пока не подключён.',
      ),
      ReasonCode.noStructureConfirmation => (
        'Нет BOS',
        '15м BOS в сторону сценария ещё не подтверждён.',
      ),
      ReasonCode.noTradeConditions => (
        'Нет преимущества',
        'Матрица подтверждений пока не достигла порога LONG/SHORT.',
      ),
      ReasonCode.macdAligned => (
        'MACD подтверждает',
        'Гистограмма MACD совпадает с направлением сценария.',
      ),
      ReasonCode.macdOpposes => (
        'MACD против',
        'Гистограмма MACD направлена против базового сценария.',
      ),
      ReasonCode.rsiAligned => (
        'RSI подтверждает',
        'RSI находится в рабочем диапазоне для сценария.',
      ),
      ReasonCode.rsiOverextended => (
        'RSI экстремальный',
        'RSI вышел за 70/30; вход может быть запоздалым.',
      ),
      ReasonCode.emaAligned => (
        'EMA согласованы',
        'EMA20/50/200 выстроены в сторону сценария.',
      ),
      ReasonCode.emaOpposes => (
        'EMA против',
        'Порядок EMA20/50/200 направлен против сценария.',
      ),
      ReasonCode.dataQualityLow => (
        'Недостаточно истории',
        'Количество закрытых свечей недостаточно для полного качества анализа.',
      ),
      ReasonCode.invalidationAboveStop => (
        'Выше Stop',
        'Закрепление выше ${_price(snapshot.stop)} отменяет SHORT-сценарий.',
      ),
      ReasonCode.invalidationBelowStop => (
        'Ниже Stop',
        'Закрепление ниже ${_price(snapshot.stop)} отменяет LONG-сценарий.',
      ),
      ReasonCode.closeAboveResistance => (
        'Пробой сопротивления',
        'Закрепление выше 15м-сопротивления отменяет медвежье преимущество.',
      ),
      ReasonCode.closeBelowSupport => (
        'Пробой поддержки',
        'Закрепление ниже 15м-поддержки отменяет бычье преимущество.',
      ),
    };
    return DecisionReason(
      code: code,
      title: text.$1,
      detail: text.$2,
      severity: severity,
    );
  }

  static String _price(double value) {
    final int digits = value >= 100.0
        ? 2
        : value >= 1.0
        ? 4
        : 6;
    return value.toStringAsFixed(digits);
  }
}
