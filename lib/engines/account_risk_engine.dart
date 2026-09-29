import '../models/account_risk_models.dart';
import '../utils/exchange_decimal.dart';

class AccountRiskEngine {
  const AccountRiskEngine._();

  static AccountRiskDecision evaluate({
    required AccountRiskPolicy policy,
    required AccountRiskState state,
    required double requestedRiskAmount,
    required int proposedLeverage,
    required int safetyLeverage,
    DateTime? now,
  }) {
    final DateTime evaluationTime = (now ?? DateTime.now()).toUtc();
    final List<String> reasons = <String>[];
    bool blocked = false;
    bool wait = false;

    if (!policy.isValid) {
      reasons.add('ACCOUNT_RISK_POLICY_INVALID');
      blocked = true;
    }
    final double configuredPercent =
        policy.accountRiskPercent < policy.maxRiskPerTradePercent
        ? policy.accountRiskPercent
        : policy.maxRiskPerTradePercent;
    final double allowedRisk = policy.accountEquity > 0.0
        ? ExchangeDecimal.percentOf(policy.accountEquity, configuredPercent)
        : 0.0;
    if (!requestedRiskAmount.isFinite || requestedRiskAmount <= 0.0) {
      reasons.add('REQUESTED_RISK_INVALID');
      blocked = true;
    } else if (requestedRiskAmount > allowedRisk + 0.00000001) {
      reasons.add('MAX_RISK_PER_TRADE_EXCEEDED');
      blocked = true;
    }
    final double maxOpenRisk = policy.accountEquity > 0.0
        ? ExchangeDecimal.percentOf(
            policy.accountEquity,
            policy.maxOpenRiskPercent,
          )
        : 0.0;
    if (state.openRiskAmount + requestedRiskAmount > maxOpenRisk + 0.00000001) {
      reasons.add('MAX_OPEN_RISK_EXCEEDED');
      blocked = true;
    }
    if (state.dailyRealizedR <= -policy.dailyRiskLimitR) {
      reasons.add('DAILY_RISK_LIMIT_EXCEEDED');
      blocked = true;
    }
    if (state.weeklyRealizedR <= -policy.weeklyRiskLimitR) {
      reasons.add('WEEKLY_RISK_LIMIT_EXCEEDED');
      blocked = true;
    }
    if (state.consecutiveLosses >= policy.consecutiveLossLimit) {
      final DateTime? cooldownUntil = state.cooldownUntil;
      if (cooldownUntil == null || evaluationTime.isBefore(cooldownUntil)) {
        reasons.add('LOSS_COOLDOWN_ACTIVE');
        wait = true;
      }
    }
    if (state.tradesToday >= policy.maxTradesPerDay) {
      reasons.add('MAX_TRADES_EXCEEDED');
      blocked = true;
    }
    if (state.openPositions >= policy.maxOpenPositions) {
      reasons.add('MAX_POSITIONS_EXCEEDED');
      blocked = true;
    }
    if (state.hasDuplicateSetup) {
      reasons.add('DUPLICATE_SETUP');
      blocked = true;
    }
    if (state.hasConflictingPosition) {
      reasons.add('CONFLICTING_POSITION');
      blocked = true;
    }
    if (proposedLeverage > policy.personalMaxLeverage) {
      reasons.add('PERSONAL_MAX_LEVERAGE_EXCEEDED');
      blocked = true;
    }
    if (!policy.highRiskOverride && proposedLeverage > safetyLeverage) {
      reasons.add('SAFETY_LEVERAGE_EXCEEDED');
      blocked = true;
    }

    final AccountRiskStatus status = blocked
        ? AccountRiskStatus.blocked
        : wait
        ? AccountRiskStatus.wait
        : AccountRiskStatus.allowed;
    final int quality = status == AccountRiskStatus.allowed
        ? requestedRiskAmount <= allowedRisk * 0.75
              ? 90
              : 75
        : status == AccountRiskStatus.wait
        ? 40
        : 0;
    if (reasons.isEmpty) reasons.add('ACCOUNT_RISK_WITHIN_LIMITS');
    return AccountRiskDecision(
      status: status,
      requestedRiskAmount: requestedRiskAmount,
      allowedRiskAmount: allowedRisk,
      accountRiskPercent: policy.accountEquity <= 0.0
          ? 0.0
          : ExchangeDecimal.divide(requestedRiskAmount, policy.accountEquity) *
                100.0,
      riskQuality: quality,
      reasonCodes: List<String>.unmodifiable(reasons),
    );
  }
}
