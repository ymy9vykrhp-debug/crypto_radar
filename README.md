# Crypto Radar

Crypto Radar is a local-first Flutter market-analysis application. The current
entry screen is focused on **FARTCOINUSDT** and keeps real order execution
blocked: analysis and position notes are manual-only.

## Current FART workflow

- **Bybit** is the primary market-data source and the reference venue.
- **Binance USD-M Futures** is used only as a public secondary confirmation for
  FARTCOIN. It never becomes the source of truth for a Bybit position.
- **BTC / ETH / SOL** are broad-market context. Missing neutral context lowers
  information coverage but does not create a hidden hard veto.
- Precision logic separates market direction from entry quality and exposes
  `READY`, `WAIT`, and `NO TRADE`.
- Continuation mode requires roughly **1% structural room to the first target**
  by default. Targets are structural rather than fixed percentages.
- R:R is adaptive: the current starting thresholds are about **1.7 / 2.0 / 2.5**
  depending on setup quality and counter-trend risk.
- Risk configuration supports **0–2% per trade**, while leverage is capped at
  the user limit and never above **10x** in the manual assistant.
- An opened manual position is managed as **HOLD / PROTECT / EXIT** (displayed
  in Russian as `ВСЁ ПО ПЛАНУ / ДЕРЖАТЬ-ЗАЩИЩАТЬ / СРОЧНО ЗАКРЫТЬ`). Stop
  protection cannot widen the recorded risk.
- Adaptive Futures Grid is currently **analysis-only**: it reports
  `GRID READY / WAIT / DANGER / OFF`, mode, range, quality, breakout risk,
  spacing and a conservative leverage suggestion. It places no orders.

## Refresh model

- Bybit live price uses WebSocket.
- Full REST market analysis has a 15-second fallback refresh.
- A newly closed live 1-minute candle requests an immediate full refresh so the
  analysis does not wait for the next fallback tick.
- Stale/invalid critical market data remains a hard safety block. Missing
  optional confirmation is a soft condition.

## Run the application

Open PowerShell in the project directory:

```powershell
flutter pub get
flutter run -d chrome
```

Verification:

```powershell
flutter analyze
flutter test
```

If Windows reports that application-control policy blocked `dartaotruntime.exe`,
that is an operating-system/Flutter toolchain policy problem rather than a Dart
compile error in Crypto Radar. Resolve that policy/toolchain issue before using
analyze/test results as a code verdict.

## Secrets

Never commit `.env` or `.env.txt`. Use `.env.example` only as a template. Any
Telegram token that has previously been shared outside the local machine should
be rotated before reuse.

## Optional Telegram relay

The existing local Telegram relay remains in the repository. It is not wired to
automatic real trading. Start it separately with the existing tool script and
keep bot secrets outside Flutter/web source code.

## Deliberately not enabled yet

- unrestricted Bybit LIVE execution;
- unattended real AUTO trading;
- 24/7 cloud Core and exchange reconciliation;
- automatic Futures Grid order placement.

Those require a separate server/execution phase after local analysis and forward
/ demo testing are stable.
