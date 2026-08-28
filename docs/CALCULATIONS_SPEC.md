# Crypto Radar — Calculation Specification

Status: normative specification for calculation, journal, backtest and future
execution modules.

Scope: Bybit USDT linear perpetual contracts. Inverse contracts, options,
portfolio margin and cross-margin liquidation are outside this specification
until they have their own verified models.

## 1. Core principles

- Risk and PnL calculations must be deterministic and testable.
- Exchange constraints are part of validation, not UI decoration.
- Fees, spread and slippage are separate costs and must not be merged silently.
- Backtest and MFE/MAE calculations may use only information available at that
  historical moment.
- Any unavailable input must produce `NOT_AVAILABLE` / `NOT_CONFIGURED`, never
  a fabricated value.
- Calculations used for money, quantity and exchange-step rounding must not rely
  on binary `double` as their canonical representation. Use decimal arithmetic
  or scaled integers/`BigInt` and serialize canonical decimal strings.

## 2. Required inputs

Every calculation must receive an immutable input object containing at least:

- symbol and side (`LONG` / `SHORT`);
- entry, stop and targets;
- quantity or allocated margin plus leverage;
- entry and exit order types (`maker` / `taker`);
- maker/taker fee rates;
- entry/target/stop slippage assumptions;
- bid, ask and timestamp when market execution is modelled;
- `tickSize`, `qtyStep`, `minOrderQty`, `minNotional` and exchange maximum
  leverage;
- margin mode and maintenance margin rate when liquidation is calculated;
- data source and whether each value is observed, configured or estimated.

All percentages must state whether they use decimal form (`0.001`) or display
form (`0.1%`). Internal formulas use decimal form.

## 3. Exchange-step normalization

For a positive step `s`:

```text
floorToStep(value, s) = floor(value / s) * s
ceilToStep(value, s)  = ceil(value / s) * s
```

Quantity is always rounded down:

```text
normalizedQuantity = floorToStep(rawQuantity, qtyStep)
```

Price normalization must never make a simulated result artificially better:

| Level | LONG | SHORT |
|---|---:|---:|
| Stop | round down | round up |
| Take Profit | round down | round up |

This convention is conservative: it does not underestimate stop risk and does
not overestimate target reward. A limit Entry supplied by the user remains the
user's value until explicit exchange-order normalization. A market Entry uses
the observed ask for LONG and bid for SHORT.

Reject the trade before position calculation when:

```text
normalizedQuantity <= 0
normalizedQuantity < minOrderQty
normalizedQuantity * normalizedEntry < minNotional
tickSize <= 0
qtyStep <= 0
```

## 4. Position values

For USDT linear contracts:

```text
entryNotional = normalizedQuantity * effectiveEntryPrice
margin        = entryNotional / leverage
```

`leverage` must be positive, finite, within the exchange limit and within the
Crypto Radar safety cap. Safety leverage is always rounded down, never up.

## 5. Spread and slippage

Spread is applied only when modelling market execution:

```text
LONG market entry  = ask
SHORT market entry = bid
```

Slippage is applied to execution prices before PnL and fee calculations. For a
positive absolute slippage amount:

```text
LONG entry:  effectiveEntry = quotedEntry + entrySlippage
SHORT entry: effectiveEntry = quotedEntry - entrySlippage

LONG exit:   effectiveExit  = quotedExit - exitSlippage
SHORT exit:  effectiveExit  = quotedExit + exitSlippage
```

If slippage is configured as a percentage, first convert it to an absolute
price amount using the relevant quoted price. Store the type and value so that
absolute and percentage assumptions cannot be confused.

## 6. Gross and net PnL

```text
LONG:  grossPnL = (effectiveExitPrice - effectiveEntryPrice) * quantity
SHORT: grossPnL = (effectiveEntryPrice - effectiveExitPrice) * quantity
```

Fees are calculated independently for each fill:

```text
entryNotional = quantity * effectiveEntryPrice
exitNotional  = quantity * effectiveExitPrice

entryFee = entryNotional * feeRate(entryOrderType)
exitFee  = exitNotional  * feeRate(exitOrderType)

netPnL = grossPnL - entryFee - exitFee
```

Never reuse `entryNotional` as `exitNotional`. All fee rates and costs must be
non-negative. Funding is not included unless a separate timestamped funding
model is enabled; when excluded, the UI must say so.

## 7. Stop and effective risk

Validate direction before calculation:

```text
LONG:  stopPrice < effectiveEntryPrice
SHORT: stopPrice > effectiveEntryPrice
```

Then calculate:

```text
stopDistance = abs(effectiveEntryPrice - effectiveStopPrice)
stopNotional = quantity * effectiveStopPrice
stopExitFee  = stopNotional * feeRate(stopOrderType)
priceLoss    = stopDistance * quantity

effectiveRisk = priceLoss + entryFee + stopExitFee
```

If stop slippage is modelled, apply it to `effectiveStopPrice` before
`stopNotional`, `priceLoss` and `stopExitFee` are calculated.

`effectiveRisk` is the expected maximum loss for the planned Stop under the
configured execution assumptions. It must not exceed the user's risk limit.

Explicitly reject:

- `stopDistance == 0`;
- stop on the wrong side of Entry;
- zero/negative/non-finite Entry, Stop, quantity or leverage;
- effective risk greater than the configured maximum loss;
- any result that cannot meet exchange minimums after safe rounding.

## 8. R:R and targets

For each target:

```text
rawRR = abs(targetPrice - effectiveEntryPrice) / stopDistance
```

Target direction must be validated:

```text
LONG:  targetPrice > effectiveEntryPrice
SHORT: targetPrice < effectiveEntryPrice
```

Net target outcome uses the target's own effective exit price, exit notional,
fee and slippage:

```text
netRR = targetNetPnL / effectiveRisk
```

For partial closes, quantities must sum to no more than total quantity after
step normalization. Report both values:

```text
rawResultR = sum(
  partialQuantity / totalQuantity
  * ((effectiveExit - effectiveEntry) / stopDistance)
  * direction
)

direction = +1 for LONG, -1 for SHORT

netResultR = totalRealizedNetPnL / effectiveRisk
```

`netResultR` is the primary journal/performance value because it includes
entry fee plus the actual fees/slippage of all partial exits.

## 9. MFE and MAE

MFE and MAE use candles between confirmed Entry and Exit in chronological
order. For an open trade, use only already closed candles.

```text
excursionR = (extremePrice - effectiveEntryPrice)
             / stopDistance
             * direction

MFE = maximum favorable excursionR, clamped at minimum 0
MAE = absolute value of the most adverse excursionR, clamped at minimum 0
```

For LONG, favorable extreme is candle High and adverse extreme is candle Low.
For SHORT, favorable extreme is candle Low and adverse extreme is candle High.

If Stop and target are both touched in the same candle and lower-timeframe
ordering is unavailable, use the documented conservative ordering. Never pick
the profitable ordering after seeing the final outcome.

## 10. Liquidation and leverage safety

A rough isolated-margin estimate may be used only as an explicitly labelled
estimate:

```text
LONG approximate liquidation:
entryPrice * (1 - 1/leverage + maintenanceMarginRate)

SHORT approximate liquidation:
entryPrice * (1 + 1/leverage - maintenanceMarginRate)

liquidationBuffer = abs(entryPrice - liquidationPrice) / entryPrice
```

This estimate is not valid as an exact Bybit liquidation price for every
margin mode, risk tier, fee treatment or account state. For Bybit Demo/future
execution, prefer the exchange-provided liquidation value or a separately
verified Bybit formula with risk tiers and isolated/cross mode inputs.

A heuristic safety cap may be calculated as:

```text
rawSafeLeverage = 1 / (
  stopDistance / entryPrice
  + maintenanceMarginRate
  + safetyMargin
)

safeLeverage = floorToLeverageStep(rawSafeLeverage)
```

The final recommended leverage is the minimum of:

- leverage allowed by the user's maximum loss;
- heuristic safety leverage;
- exchange maximum leverage;
- Crypto Radar product cap;
- any lower volatility/regime safety cap.

Never move the structural Stop closer to obtain a higher leverage.

## 11. Journal aggregates

Use only closed trades for realized performance:

```text
profitFactor = sum(positive netPnL) / abs(sum(negative netPnL))
winRate      = count(netPnL > 0) / count(all closed trades)
currentBalance = startingBalance + sum(realized netPnL)
```

Break-even trades remain in the closed-trade denominator and are reported
separately. When there are profits but no losses, Profit Factor is infinite and
must be displayed as `∞` or `N/A`, never replaced with an arbitrary large
number.

Equity points are ordered by actual Exit time, not Entry time. For each point:

```text
peakEquity = max(previousPeak, currentEquity)
drawdownAmount = peakEquity - currentEquity
drawdownPercent = peakEquity > 0
  ? drawdownAmount / peakEquity * 100
  : NOT_AVAILABLE

maxDrawdown = maximum drawdownAmount / drawdownPercent over the curve
```

Open trades do not change realized Current Balance.

## 12. Serialization and reproducibility

- Store canonical decimal values as strings, not lossy JSON floating numbers.
- Preserve the original exchange rules, fee model, risk settings, strategy
  version, calculation version and execution assumptions inside the trade
  snapshot.
- Loading an old record must use its historical snapshot, not today's settings.
- Save -> load -> recalculate must produce exactly the same canonical decimal
  outputs.
- Schema changes require an explicit version and migration tests.

## 13. Mandatory unit tests

At minimum, add deterministic tests for:

1. LONG gross/net PnL with different entry/exit notionals.
2. SHORT gross/net PnL.
3. maker entry plus taker exit.
4. market Entry using ask for LONG and bid for SHORT.
5. entry, target and stop slippage directions.
6. entry/exit fees calculated from their own notionals.
7. Stop fee included in effective risk.
8. partial TP1/TP2/TP3 raw and net Result R.
9. quantity floor to `qtyStep`.
10. conservative Stop/TP tick rounding for LONG and SHORT.
11. `minOrderQty` and `minNotional` rejection.
12. zero Stop distance rejection without division by zero.
13. Stop and targets on the wrong side of Entry.
14. quantity becoming zero after step rounding.
15. very small price such as `0.00000012` without binary rounding drift.
16. high-price/high-quantity overflow protection.
17. safe leverage always rounded down.
18. open-trade MFE/MAE using only closed candles.
19. conservative same-candle Stop/target ordering.
20. Profit Factor with wins/losses, no losses and no trades.
21. Win Rate using closed trades only.
22. Equity ordered by Exit time when Entry order differs.
23. Max Drawdown amount and percent from peak equity.
24. open trades excluded from realized balance.
25. save/load canonical calculation identity.
26. historical trade snapshots unaffected by later settings changes.

## 14. Acceptance criteria

The calculation layer is accepted only when:

- it is a pure module independent from UI widgets;
- every invalid state returns a typed validation error;
- all monetary outputs identify observed/configured/estimated inputs;
- LONG and SHORT behave symmetrically;
- exchange-step rules are enforced before a trade is called valid;
- fees, spread and slippage are visible separately;
- no-lookahead tests pass;
- historical records remain reproducible;
- `flutter analyze` and the full test suite pass;
- Chrome UI shows the same values as the calculation engine without duplicating
  formulas inside widgets.
