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

`Market Data -> Indicators -> Structure -> Levels -> Regime -> Strategy -> Decision -> Structural Stop/Targets -> Smart Position/Risk -> Journal/Tracker -> Backtest/Statistics -> Explanation`

Supported now: a dynamic public Bybit USDT Perpetual universe with one selected asset per workspace; 1m, 5m, 15m and 1h trading analysis; visual-only 4h chart history. Historical Backtest remains deliberately limited to BTCUSDT and FARTCOINUSDT until broader validation is implemented.

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
   - **Phase A execution-quality gate (completed):** staged confirmation, false-breakout/reclaim analysis, structural buffered stops, entry/stop/risk quality, stop-then-target tracking and fixed execution-profile comparison.
3. **Market Structure 2.0:** pivots, HH/HL/LH/LL sequence, confirmed BOS/CHOCH events, impulse/correction state.
4. **Heavy Levels:** scored S/R, Order Blocks, FVG, liquidity pools/sweeps and price magnet.
5. **Level behaviour:** breakout/rejection scores and candle/volume context.
6. **Regime and strategy:** regime detector, strategy selector, explicit `NO_TRADE`, entry/risk/stop/target engines.
7. **Journal/statistics integration:** persist all new context; factor/reason/strategy/regime effectiveness with sample sizes.
8. **Visual structure and product shell:** interactive connected chart delivered with 1m/5m/15m/1h/4h, history navigation, crosshair, clean layers, structure/event annotations, indicator subpanels, “ПОЧЕМУ?” highlighting and fullscreen. Adaptive product navigation, selected-asset workspace, responsive Journal/Signals/Research tables, grouped settings, themes and shell localization are delivered. Advanced Volume Profile, Footprint/Clusters, Heatmap, Order Flow, Replay, Journal/Backtest overlays and remaining localization depth remain.
9. **News risk:** high-impact events as a risk filter, never a trade generator.
10. **Research safety:** fixed train/validation/out-of-sample and guarded profile learning delivered; rolling walk-forward, fees/slippage and what-if remain.
11. **Paper trading:** virtual balance, positions, fees-ready accounting and equity curve.
12. **Local Radar Chat:** questions answered only from `DecisionSnapshot`; future LLM is explanation-only.
13. **Macro/cross-market:** correlations, risk-on/off, divergence and lead/lag.
14. **External views/alerts:** TradingView and Telegram after strategy stability.
15. **Execution discussion only:** Bybit orders may be considered after all safety gates and explicit user approval.
16. **Product / Support / Official Links (deferred, after the active delivery queue):** prepare non-commercial product identity, official-link configuration and local Help Center UI without payments, accounts or trading access.

Local monitor-only `ENTRY_CONFIRMED` popups and public WebSocket price updates are already delivered. Phase 14 refers only to external TradingView/Telegram delivery and remains gated by strategy stability.

The local Smart Position Calculator is delivered after Decision and structural Stop/targets. It calculates margin, risk-limited notional, fee/slippage estimates, leverage safety, quantity and net outcomes without order execution. Bybit Demo remains Phase 11/future execution work.

### Deferred Phase 16 scope — Product / Support / Official Links

- Add an **About Crypto Radar** view with Version, Build, Strategy Version and Data Engine Version.
- Add **Official Links** entries for Official Telegram Signals, Telegram Community, Support, Website, Documentation, Changelog and Contact Developer.
- Keep two independent Telegram domains:
  - **Official Crypto Radar Telegram:** future first-party signals, updates, notifications and community links.
  - **External Signal Sources:** third-party inputs that follow `Parser -> Radar Analysis -> Filters -> Priority -> Statistics`.
- Never mix official links and external sources in one table, model or status flow.
- Introduce one centralized `ProductLinksConfig` containing `websiteUrl`, `telegramSignalsUrl`, `telegramCommunityUrl`, `telegramSupportUrl`, `supportEmail`, `documentationUrl`, `changelogUrl`, `privacyUrl` and `termsUrl`. Widgets must not contain direct product URLs.
- Missing configuration is safe: the action is disabled, status is `NOT CONFIGURED`, and the application continues normally.
- Add **About & Support** to Settings and later add a compact sidebar footer: `Crypto Radar`, `v0.x Beta`, Help, Telegram and Support.
- Prepare local Help Center navigation for Getting Started, How Signals Work, Risk Management, Bybit Demo Setup, Telegram, FAQ and Contact Support. Unavailable material may be an explicit local placeholder.
- This phase is UI/config/help architecture only. It must not add payments, subscriptions, licences, login, billing, registration or a commercial backend.
- Official Telegram links do not grant signal ingestion or order permissions. External Telegram sources remain a later isolated parser/gateway concern and can never place orders directly.

## Required metrics and records

Journal signals retain direction, entry/stop/targets, score, leverage, multi-timeframe context, indicators, structure, levels, regime/strategy and reason codes. Tracker statuses cover waiting, entered, TP1, TP2, stop, cancel/expiry. Backtest reports signals/trades, win rate, TP1/TP2/stop, average R, profit factor, drawdown, MFE/MAE, movement and timing; later phases add equity curves and deeper slicing.

Phase A also retains entry/stop variants, four quality scores, structural invalidation, dynamic stop buffer, false-breakout state, sweep/reclaim evidence, stop overshoot and `STOP_THEN_TARGET`. Fixed-profile reports include chronological train/validation/OOS slices with sample sizes. These slices are diagnostic only; rolling walk-forward, fees and slippage remain later research gates.

Guarded learning may change only future confirmed entry/stop profiles after its sample, validation, OOS, profit-factor and drawdown gates all pass. Low-sample factor results are stored as evidence but never auto-promoted. The built-in chart remains the canonical connected visualization because it consumes the exact same local snapshot and signal objects.

## Verification gate

After every phase:

1. Format changed Dart files.
2. Run `flutter analyze`.
3. Run all tests, especially no-lookahead and ambiguous TP/stop ordering.
4. Build or launch Chrome and inspect existing tabs/layout.
5. Update `docs/IMPLEMENTED.md` with DONE / IN PROGRESS / TODO.
