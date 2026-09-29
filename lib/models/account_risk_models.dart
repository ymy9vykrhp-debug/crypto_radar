enum AccountRiskStatus { allowed, wait, blocked }

class AccountRiskPolicy {
  const AccountRiskPolicy({
    required this.accountEquity,
    this.accountRiskPercent = 0.5,
    this.maxRiskPerTradePercent = 1.0,
    this.dailyRiskLimitR = 2.0,
    this.weeklyRiskLimitR = 5.0,
    this.maxOpenRiskPercent = 2.0,
    this.consecutiveLossLimit = 3,
    this.cooldownAfterLosses = const Duration(hours: 4),
    this.personalMaxLeverage = 10,
    this.highRiskOverride = false,
    this.maxTradesPerDay = 6,
    this.maxOpenPositions = 2,
  });

  final double accountEquity;
  final double accountRiskPercent;
  final double maxRiskPerTradePercent;
  final double dailyRiskLimitR;
  final double weeklyRiskLimitR;
  final double maxOpenRiskPercent;
  final int consecutiveLossLimit;
  final Duration cooldownAfterLosses;
  final int personalMaxLeverage;
  final bool highRiskOverride;
  final int maxTradesPerDay;
  final int maxOpenPositions;

  bool get isValid =>
      accountEquity.isFinite &&
      accountEquity > 0.0 &&
      accountRiskPercent > 0.0 &&
      accountRiskPercent <= maxRiskPerTradePercent &&
      maxRiskPerTradePercent <= 20.0 &&
      dailyRiskLimitR > 0.0 &&
      weeklyRiskLimitR > 0.0 &&
      maxOpenRiskPercent > 0.0 &&
      consecutiveLossLimit > 0 &&
      personalMaxLeverage >= 1 &&
      personalMaxLeverage <= 10;
}

class AccountRiskState {
  const AccountRiskState({
    this.dailyRealizedR = 0.0,
    this.weeklyRealizedR = 0.0,
    this.openRiskAmount = 0.0,
    this.consecutiveLosses = 0,
    this.cooldownUntil,
    this.tradesToday = 0,
    this.openPositions = 0,
    this.hasDuplicateSetup = false,
    this.hasConflictingPosition = false,
  });

  final double dailyRealizedR;
  final double weeklyRealizedR;
  final double openRiskAmount;
  final int consecutiveLosses;
  final DateTime? cooldownUntil;
  final int tradesToday;
  final int openPositions;
  final bool hasDuplicateSetup;
  final bool hasConflictingPosition;
}

class AccountRiskDecision {
  const AccountRiskDecision({
    required this.status,
    required this.requestedRiskAmount,
    required this.allowedRiskAmount,
    required this.accountRiskPercent,
    required this.riskQuality,
    required this.reasonCodes,
  });

  final AccountRiskStatus status;
  final double requestedRiskAmount;
  final double allowedRiskAmount;
  final double accountRiskPercent;
  final int riskQuality;
  final List<String> reasonCodes;

  bool get isAllowed => status == AccountRiskStatus.allowed;
}
