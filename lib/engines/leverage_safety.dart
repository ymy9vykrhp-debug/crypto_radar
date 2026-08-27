import 'dart:math' as math;

import '../models/decision_models.dart';
import '../models/position_calculator_models.dart';

class LeverageSafety {
  const LeverageSafety._();

  static LeverageSafetyResult evaluate({
    required SmartPositionInput input,
    required FeeModel feeModel,
    required double calculatedLeverage,
    required double stopDistancePercent,
  }) {
    final List<String> reasons = <String>[];
    int cap = math.min(10, input.exchangeMaxLeverage.floor());
    if (cap < 1) cap = 1;

    void applyCap(int value, String reason) {
      if (value < cap) {
        cap = math.max(1, value);
        reasons.add(reason);
      }
    }

    switch (input.assetRiskClass) {
      case AssetRiskClass.major:
        break;
      case AssetRiskClass.standard:
        applyCap(8, 'Для альткоина действует дополнительный лимит плеча.');
      case AssetRiskClass.speculative:
        applyCap(
          6,
          'Спекулятивный актив ограничен по плечу независимо от Confidence.',
        );
    }

    if (input.atrPercent >= 3.0) {
      applyCap(
        2,
        'ATR указывает на экстремальную внутридневную волатильность.',
      );
    } else if (input.atrPercent >= 2.0) {
      applyCap(3, 'ATR высокий — допустимое плечо уменьшено.');
    } else if (input.atrPercent >= 1.0) {
      applyCap(5, 'ATR выше комфортного уровня для большого плеча.');
    } else if (input.atrPercent >= 0.60) {
      applyCap(7, 'ATR требует умеренного запаса по плечу.');
    }

    if (input.volatilityPercent >= 30.0) {
      applyCap(2, 'Рыночная волатильность соответствует режиму CHAOS.');
    } else if (input.volatilityPercent >= 20.0) {
      applyCap(3, 'Очень высокая волатильность актива.');
    } else if (input.volatilityPercent >= 12.0) {
      applyCap(5, 'Высокая суточная волатильность актива.');
    } else if (input.volatilityPercent >= 7.0) {
      applyCap(7, 'Повышенная суточная волатильность актива.');
    }

    if (stopDistancePercent >= 5.0) {
      applyCap(2, 'Структурный Stop слишком широкий для большого плеча.');
    } else if (stopDistancePercent >= 3.0) {
      applyCap(3, 'Широкий структурный Stop ограничивает плечо.');
    } else if (stopDistancePercent >= 1.5) {
      applyCap(5, 'Расстояние до Stop требует умеренного плеча.');
    }

    if (feeModel.estimatedSpreadPercent >= 0.15) {
      applyCap(2, 'Очень широкий оценочный Spread.');
    } else if (feeModel.estimatedSpreadPercent >= 0.08) {
      applyCap(4, 'Повышенный Spread ограничивает размер позиции.');
    } else if (feeModel.estimatedSpreadPercent >= 0.04) {
      applyCap(6, 'Spread выше комфортного уровня для большого плеча.');
    }

    switch (input.marketRegime) {
      case MarketRegimeHint.mixed:
        applyCap(4, 'Режим MIXED / UNCERTAIN не допускает большого плеча.');
      case MarketRegimeHint.range:
        applyCap(6, 'В диапазоне повышен риск ложных пробоев.');
      case MarketRegimeHint.trendUp:
      case MarketRegimeHint.trendDown:
        break;
    }

    if (input.confidence < 55) {
      applyCap(2, 'Качество сетапа недостаточно для повышенного плеча.');
    } else if (input.confidence < 70) {
      applyCap(3, 'Confidence ниже рабочего уровня.');
    } else if (input.confidence < 80) {
      applyCap(5, 'Умеренный Confidence ограничивает плечо.');
    }

    if (input.hasSharpImpulse) {
      applyCap(4, 'После резкого импульса нужен дополнительный запас.');
    }
    if (input.isChaos) {
      applyCap(2, 'CHAOS / HIGH VOL: повышенное плечо заблокировано.');
    }

    final int riskLimited = calculatedLeverage.isFinite
        ? math.max(0, calculatedLeverage.floor())
        : 0;
    int safe = math.min(riskLimited, cap);
    double liquidationDistance = _liquidationDistance(safe);
    final double requiredBuffer = math.max(
      stopDistancePercent * 2.0,
      stopDistancePercent + input.atrPercent * 2.0 + 1.0,
    );
    while (safe > 1 && liquidationDistance < requiredBuffer) {
      safe--;
      liquidationDistance = _liquidationDistance(safe);
    }
    if (safe < math.min(riskLimited, cap)) {
      reasons.add('Плечо снижено из-за недостаточного запаса до ликвидации.');
    }

    final int aggressive = safe <= 0
        ? 0
        : math.min(riskLimited, math.min(10, safe + 2));
    final int dangerousFrom = safe <= 0
        ? 1
        : math.min(10, math.max(aggressive + 1, safe + 3));

    if (reasons.isEmpty) {
      reasons.add('Плечо ограничено только установленным риском сделки.');
    }

    return LeverageSafetyResult(
      calculatedLeverage: calculatedLeverage.isFinite
          ? calculatedLeverage
          : 0.0,
      safetyLimit: cap,
      safeLeverage: safe,
      aggressiveLeverage: aggressive,
      dangerousFromLeverage: dangerousFrom,
      recommendedLeverage: safe,
      estimatedLiquidationDistancePercent: liquidationDistance,
      reasons: List<String>.unmodifiable(reasons),
    );
  }

  static double _liquidationDistance(int leverage) {
    if (leverage <= 0) return 0.0;
    // A deliberately conservative approximation for UI planning only. The
    // exchange-specific value will later come from the Demo execution layer.
    return math.max(0.0, 100.0 / leverage - 0.75);
  }
}
