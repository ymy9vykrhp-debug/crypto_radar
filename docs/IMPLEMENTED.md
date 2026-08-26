# Crypto Radar — Implementation Status

Last updated: 2026-08-26

## DONE — Phase 1 stable core

- Modular Flutter layout: models, services, engines, screens, widgets and storage backends.
- BTCUSDT and FARTCOINUSDT live data with 15-second refresh.
- 1m/5m/15m/1h analysis through one shared `SignalEngine`.
- RSI, MACD, EMA20/50/200, RVOL, ATR, Fibonacci, Ichimoku, structure, BOS/CHOCH, support/resistance, liquidity, FVG and Order Blocks.
- Standard and 1m scalp signal models; leverage capped at 10x; heuristic 1:1/1:3/1:5/1:9 table clearly separated from historical probability.
- Local Journal with unique active signal handling.
- Trade Tracker with entry/TP1/TP2/stop, conservative same-candle ordering, MFE, MAE, timing and result R.
- No-lookahead Backtest for BTCUSDT and FARTCOINUSDT using the same `SignalEngine` as live.
- Local JSON/browser storage without live trading.
- Baseline verification: `flutter analyze` clean; 6 tests passed.
- Git recovery point: `b40eee5` (`working-journal-backtest-v1`).

## DONE — Phase 2 explainable decision

- `DecisionSnapshot` with stable reason, warning and invalidation codes.
- Local deterministic `ExplanationEngine` that consumes the snapshot only.
- “ПОЧЕМУ?” tab and Home button showing supporting and opposing factors, entry/stop/target logic and decision-change conditions.
- Reason codes persist in Journal signals, including automatic migration of existing local records, and aggregate into Backtest reports.
- Neutral Confirmation Matrix rows now display `—` instead of a misleading positive weight.
- Verification: `flutter analyze` clean; all 10 tests passed; debug web build succeeded; Chrome debug launch connected successfully.
- Full smoke-backtest completed on 2026-08-25: BTCUSDT 143 signals/trades, 47.6% win rate, +0.06 average R; FARTCOINUSDT 155 signals/trades, 49.0% win rate, 0.00 average R. These moving-window results are diagnostics, not promised performance.

## DONE — Phase A execution quality

- Explicit signal lifecycle: `SETUP_FOUND`, `WAIT_FOR_ZONE`, `WAIT_FOR_TRIGGER`, `ENTRY_CONFIRMED`, `IN_POSITION`, `TP1_HIT`, `TP2_HIT`, `STOPPED`, `CANCELLED`, `EXPIRED`.
- Confirmed entry is the live default. Aggressive entry remains an explicit comparison mode and never silently replaces the default.
- `FalseBreakoutEngine` separates a possible pierce from a confirmed reclaim/sweep and requires a later closed candle for confirmation.
- `StopEngine` places structural invalidation first and adds a dynamic ATR/wick/tick/overshoot buffer. Unsafe distance or poor R:R produces `WAIT` / `NO TRADE`.
- Separate Direction, Entry, Stop and Risk quality scores are visible in Radar, “ПОЧЕМУ?” and Journal.
- Tracker persists stop overshoot, approximate time outside the level, reclaim and post-stop TP1/TP2. `STOP_THEN_TARGET` is reported instead of hiding a structurally bad stop.
- Backtest compares six entry variants and three stop approaches through eight fixed execution profiles. Headline metrics use the primary confirmed-BOS profile instead of mixing all profiles.
- Each profile exposes a chronological 60/20/20 train/validation/out-of-sample diagnostic with sample size. This is not yet a full walk-forward study or automatic optimizer.
- Verification: `flutter analyze` clean; all 19 tests passed, including no-lookahead confirmation, false-breakout, reclaim, dynamic buffer, deduplication and stop-then-target cases.
- Full Phase A smoke-backtest completed for BTCUSDT and FARTCOINUSDT. Results are moving-window diagnostics and do not include exchange fees/slippage.

## DONE — Guarded Learning + connected chart

- New `ГРАФИК` tab renders Bybit candles from the same `MarketSnapshot` used by live Radar and `SignalEngine`.
- Chart overlays EMA20/50, support/resistance, liquidity, FVG/OB zones and the Journal signal's ENTRY zone, STOP, TP1 and TP2. It is analysis-only and cannot place Bybit orders.
- `StrategyLearningEngine` ranks confirmed execution profiles with confidence shrinkage instead of selecting the highest raw win rate.
- Automatic adaptation is locked until at least 120 completed trades, 20 validation trades and 30 OOS trades, with positive Average R in both validation and OOS, PF >= 1.20 and bounded drawdown.
- Aggressive profiles are excluded from automatic live selection. Until the gate passes, `live_confirmed` remains unchanged.
- Factor evidence shows sample size, confidence and collect/neutral/strengthen/reduce research guidance. It does not silently rewrite `SignalEngine` weights from tiny samples.
- Verification: `flutter analyze` clean; all 21 tests passed; the local web app loaded live Bybit data and the chart was visually checked without browser errors.

## DONE — Interactive chart workspace

- The chart has its own visual-only data path for 1m/5m/15m/1h/4h history; `SignalEngine`, live decisions, Journal, Tracker and Backtest rules were not changed.
- Mouse-wheel and button zoom, drag/pan through history, fit, reset, latest-candle return, fullscreen and 100/200/300/500-candle windows.
- Crosshair and candle tooltip expose time, OHLC, volume, range, body and direction; candle and overlay clicks open contextual details.
- Clean layer controls for Entry, Stop, TP1/TP2, S/R, Heavy Levels, Liquidity, FVG, Order Blocks, HH/HL/LH/LL, BOS, CHOCH, False Breakout, Sweep, Price Magnet and Expected Move.
- Visual structure annotations cover confirmed pivots, trend, correction, correction end, continuation and possible reversal without feeding those annotations back into trading decisions.
- EMA20/50/200 and VWAP overlays plus removable/collapsible Volume, RSI, MACD and ATR panels.
- “ПОЧЕМУ?” mode highlights only the layers linked to the current immutable decision reason/warning codes and provides direct access to the Decision Snapshot.
- Verification: `flutter analyze` clean; all 25 tests passed; Chrome interaction smoke-test covered zoom, pan, tooltip, 4h, layers, indicators and fullscreen without browser warnings/errors.

## TODO

- Phase 3: deeper Market Structure Engine 2.0 and correction/BOS/CHOCH event history.
- Phase 4: scored Heavy Levels, OB, FVG and Liquidity engines.
- Phase 5: breakout/rejection and candle/volume behaviour.
- Phase 6: full Market Regime, Strategy Selector and explicit NO TRADE.
- Full rolling walk-forward/OOS research, fees and slippage remain required before Paper Trading.
- A Pine Script mirror may be added after the strategy is stable, but it would recalculate the strategy inside TradingView rather than read local Flutter signals. A licensed Advanced Charts integration is a later deployment option.
- Alert delivery and alert deduplication remain deferred to the alerts phase.
- Advanced chart roadmap: Volume Profile, Footprint/Clusters, Heatmap, Order Flow, Replay, Journal trade overlays and Backtest replay.
- The broader navigation/workspace/theme/localization UI master plan remains a separate follow-up stage.
- Phases 7–15: see `CRYPTO_RADAR_ROADMAP.md`.

## Safety notes

- Current market-regime and entry-state labels in Phase 2 are preliminary summaries of existing engine outputs, not the future Phase 6 classifier.
- Scores and R:R target estimates are not guarantees or financial advice.
- Bybit remains market-data-only; no order, balance or position APIs are used.
