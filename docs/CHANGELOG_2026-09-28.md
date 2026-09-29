# Crypto Radar — coordinated FART assistant update (2026-09-28)

## Implemented in this iteration

### Precision / readiness
- FARTCOINUSDT remains the only execution candidate in the simplified assistant.
- Direction and entry quality remain separate.
- Missing liquidity sweep is no longer an invisible mandatory veto; liquidity
  contributes to quality while zone, confirmation, structure/risk and critical
  data integrity remain decisive.
- Neutral/missing BTC/ETH/SOL context no longer blocks READY by itself.
- Strong opposite broad-market context can move the setup back to WAIT.
- Adaptive R:R thresholds: approximately 1.7 for high-quality setups, 2.0
  normally, and 2.5 for weaker/counter-trend setups.
- Continuation minimum structural room defaults to 1% to the first real target.
- Market analysis can still run when balance is not configured; only position
  sizing / cost-aware Net R:R is unavailable in that case.
- Risk setting supports up to 2%; leverage remains capped at 10x.

### Binance confirmation
- Added a public Binance USD-M Futures confirmation provider for FARTCOINUSDT.
- Uses closed 5m / 15m / 1h candles and relative 5m volume.
- Strong opposite Binance momentum can return a setup to WAIT.
- Missing/failed Binance data is visible but is not a critical hard block.
- No Binance account or trading permissions are used.

### Market context
- Context expanded to BTC / ETH / SOL.
- BTC carries higher context weight; FART relative strength is measured against
  available fresh context rather than requiring every context asset.

### Refresh / stale analysis
- Live FART price still arrives through WebSocket.
- The existing 15-second REST refresh stays as fallback.
- When LivePriceService reports a newly closed 1m candle, the controller now
  requests a full multi-timeframe refresh immediately.

### Position lifecycle
- Manual opened positions now retain the quality, Entry Zone and structural
  targets that existed at the moment of opening.
- Existing local saved positions remain backward compatible.
- Position state is surfaced as HOLD / PROTECT / EXIT with Russian UI wording.
- The assistant now shows movement from the actual Entry, a dynamic R:R to the
  next still-relevant planned target, and warns when the manual Entry was outside
  the original Entry Zone without forcing an automatic exit.
- A favorable move of roughly 1% triggers re-evaluation/protection rather than
  blindly waiting for a distant target.
- Stop widening remains forbidden. Structural protection is only suggested
  after confirmed favorable movement / partial realization.

### Adaptive Futures Grid
- Added an analysis-only Grid engine.
- States: READY / WAIT / DANGER / OFF.
- Modes: Neutral / Long / Short / Off.
- Uses structural boundaries, ATR/volatility, range position, relative volume,
  trend agreement and spread where available.
- Reports range quality, breakout risk, adaptive spacing, level count and a
  conservative leverage recommendation capped by the user maximum.
- It never places or modifies exchange orders.

### UI
- Added Grid tab.
- Added compact technical panel: support/resistance, Fibonacci, EMA20/50/200,
  MACD, RSI, RVOL and ATR.
- Added Binance and BTC/ETH/SOL context visibility.
- Clarified that scores are quality heuristics, not probabilities of profit.

### Security
- Real `.env` / `.env.txt` is excluded from the working deliverable.
- Added `.env.example` with placeholders only.

## Intentionally left disabled / next phase

- Real Bybit execution and API-key permissions.
- 24/7 cloud Core, persistent reconciliation and idempotent execution ledger.
- Automatic Grid execution.
- Full correlation leader/lag scanner beyond BTC/ETH/SOL context.
- Full integration of the legacy Journal/Telegram/Scanner screens into the
  simplified FART assistant navigation. Existing modules remain in source and
  were not destructively rewritten.

## Verification limitation in this environment

The editing container does not contain Flutter/Dart, so `flutter analyze` and
`flutter test` could not be executed here. Source-level delimiter checks and
`git diff --check` were performed. Run the normal Flutter checks on the Windows
machine after the Flutter/Windows application-control issue is resolved.
