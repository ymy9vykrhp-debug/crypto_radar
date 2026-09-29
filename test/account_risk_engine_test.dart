import 'package:crypto_radar/engines/account_risk_engine.dart';
import 'package:crypto_radar/models/account_risk_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default account policy allows no more than 0.5 percent per trade', () {
    const AccountRiskPolicy policy = AccountRiskPolicy(accountEquity: 1000.0);

    final AccountRiskDecision allowed = AccountRiskEngine.evaluate(
      policy: policy,
      state: const AccountRiskState(),
      requestedRiskAmount: 5.0,
      proposedLeverage: 4,
      safetyLeverage: 4,
    );
    final AccountRiskDecision blocked = AccountRiskEngine.evaluate(
      policy: policy,
      state: const AccountRiskState(),
      requestedRiskAmount: 5.01,
      proposedLeverage: 4,
      safetyLeverage: 4,
    );

    expect(allowed.status, AccountRiskStatus.allowed);
    expect(allowed.allowedRiskAmount, 5.0);
    expect(blocked.status, AccountRiskStatus.blocked);
    expect(blocked.reasonCodes, contains('MAX_RISK_PER_TRADE_EXCEEDED'));
  });

  test('daily, weekly and open-risk limits are hard vetoes', () {
    final AccountRiskDecision result = _notConst;
    expect(result.status, AccountRiskStatus.blocked);
    expect(result.reasonCodes, contains('DAILY_RISK_LIMIT_EXCEEDED'));
    expect(result.reasonCodes, contains('WEEKLY_RISK_LIMIT_EXCEEDED'));
    expect(result.reasonCodes, contains('MAX_OPEN_RISK_EXCEEDED'));
  });

  test('loss streak activates a temporary WAIT cooldown', () {
    final DateTime now = DateTime.utc(2026, 8, 29, 12);
    final AccountRiskDecision result = AccountRiskEngine.evaluate(
      policy: const AccountRiskPolicy(accountEquity: 1000.0),
      state: AccountRiskState(
        consecutiveLosses: 3,
        cooldownUntil: now.add(const Duration(hours: 2)),
      ),
      requestedRiskAmount: 4.0,
      proposedLeverage: 3,
      safetyLeverage: 3,
      now: now,
    );

    expect(result.status, AccountRiskStatus.wait);
    expect(result.reasonCodes, contains('LOSS_COOLDOWN_ACTIVE'));
  });

  test('10x is unavailable unless explicit high-risk override allows it', () {
    const AccountRiskState state = AccountRiskState();
    final AccountRiskDecision safe = AccountRiskEngine.evaluate(
      policy: const AccountRiskPolicy(accountEquity: 1000.0),
      state: state,
      requestedRiskAmount: 4.0,
      proposedLeverage: 10,
      safetyLeverage: 4,
    );
    final AccountRiskDecision override = AccountRiskEngine.evaluate(
      policy: const AccountRiskPolicy(
        accountEquity: 1000.0,
        highRiskOverride: true,
      ),
      state: state,
      requestedRiskAmount: 4.0,
      proposedLeverage: 10,
      safetyLeverage: 4,
    );

    expect(safe.status, AccountRiskStatus.blocked);
    expect(safe.reasonCodes, contains('SAFETY_LEVERAGE_EXCEEDED'));
    expect(override.status, AccountRiskStatus.allowed);
  });
}

final AccountRiskDecision _notConst = AccountRiskEngine.evaluate(
  policy: const AccountRiskPolicy(accountEquity: 1000.0),
  state: const AccountRiskState(
    dailyRealizedR: -2.0,
    weeklyRealizedR: -5.0,
    openRiskAmount: 18.0,
  ),
  requestedRiskAmount: 4.0,
  proposedLeverage: 3,
  safetyLeverage: 3,
);
