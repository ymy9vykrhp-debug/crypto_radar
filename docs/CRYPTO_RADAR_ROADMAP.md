# Crypto Radar — Technical Roadmap

This document is the compact, durable project master plan. Changes are delivered in small phases; each phase must pass `flutter analyze`, unit/widget tests, and a launch/build check before the next phase starts.

## Non-negotiable rules

- No live order execution. Bybit is market data only until backtest, out-of-sample, paper-trading, and manual approval gates are complete.
- Live Radar and Backtest use the same `SignalEngine`; historical evaluation only sees candles closed at that point.
- Signal strength is a confluence score, never presented as profit probability.
- Historical probabilities always show sample size and confidence.
- Backtest resolves an ambiguous candle conservatively: stop before target.
- Explanation/AI layers may describe an algorithmic decision but may not alter it.
- New engines are config-driven and are added without growing `main.dart`.
- Local-first storage stays behind an abstraction so it can be replaced later.

## Target pipeline

`Market Data -> Indicators -> Structure -> Levels -> Regime -> Strategy -> Decision -> Risk -> Journal/Tracker -> Backtest/Statistics -> Explanation`

Supported now: BTCUSDT and FARTCOINUSDT; 1m, 5m, 15m, 1h. A later data phase adds 4h and configurable symbols/timeframes.

## Architecture

- `models/`: immutable market, signal, decision, journal, and report objects.
- `services/`: external data and application controllers.
- `engines/`: deterministic analysis, decision, tracking, backtest, and explanation logic.
- `screens/`: thin UI screens.
- `widgets/`: reusable presentation components.
- `services/storage/`: local persistence backends.
- Planned: `indicators/`, `repositories/`, `config/` as their phases require them.

## Delivery phases

1. **Stable core:** Journal, unique signal identity, Trade Tracker, MFE/MAE/timing/R, Backtest, no-lookahead tests.
2. **Explainable decision:** `DecisionSnapshot`, stable reason/warning/invalidation codes, local `ExplanationEngine`, “ПОЧЕМУ?” UI.
3. **Market Structure 2.0:** pivots, HH/HL/LH/LL sequence, confirmed BOS/CHOCH events, impulse/correction state.
4. **Heavy Levels:** scored S/R, Order Blocks, FVG, liquidity pools/sweeps and price magnet.
5. **Level behaviour:** breakout/rejection scores and candle/volume context.
6. **Regime and strategy:** regime detector, strategy selector, explicit `NO_TRADE`, entry/risk/stop/target engines.
7. **Journal/statistics integration:** persist all new context; factor/reason/strategy/regime effectiveness with sample sizes.
8. **Visual structure:** timeframe heatmap and compact annotated chart.
9. **News risk:** high-impact events as a risk filter, never a trade generator.
10. **Research safety:** what-if, train/validation/out-of-sample, walk-forward, guarded self-analysis.
11. **Paper trading:** virtual balance, positions, fees-ready accounting and equity curve.
12. **Local Radar Chat:** questions answered only from `DecisionSnapshot`; future LLM is explanation-only.
13. **Macro/cross-market:** correlations, risk-on/off, divergence and lead/lag.
14. **External views/alerts:** TradingView and Telegram after strategy stability.
15. **Execution discussion only:** Bybit orders may be considered after all safety gates and explicit user approval.

## Required metrics and records

Journal signals retain direction, entry/stop/targets, score, leverage, multi-timeframe context, indicators, structure, levels, regime/strategy and reason codes. Tracker statuses cover waiting, entered, TP1, TP2, stop, cancel/expiry. Backtest reports signals/trades, win rate, TP1/TP2/stop, average R, profit factor, drawdown, MFE/MAE, movement and timing; later phases add equity curves and deeper slicing.

## Verification gate

After every phase:

1. Format changed Dart files.
2. Run `flutter analyze`.
3. Run all tests, especially no-lookahead and ambiguous TP/stop ordering.
4. Build or launch Chrome and inspect existing tabs/layout.
5. Update `docs/IMPLEMENTED.md` with DONE / IN PROGRESS / TODO.

