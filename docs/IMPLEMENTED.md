# Crypto Radar — Implementation Status

Last updated: 2026-08-29

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

## DONE — Product UI/UX shell

- Replaced the flat six-tab layout with adaptive desktop navigation and a mobile drawer: Home, Market, Signals, Journal, Research, News, Integrations and Settings.
- Added a selected-asset workspace with Overview, Chart, Structure, Levels, Volume/Clusters, Signal, Why, Journal and News. Workspace data never mixes symbols.
- Home now prioritizes decision, action, execution stage, quality scores, regime, strategy, entry/stop/targets, R:R, magnet, expected move, news risk and data quality.
- Signals and Journal use searchable/filterable/sortable responsive tables; a selected row opens setup, plan, MFE/MAE, overshoot, timeline, errors/review and technical evidence.
- Heavy Levels, Backtest Results, Strategy Comparison and Factor Statistics use dedicated tables; Research is separated from Journal.
- Added a separate Alert Center list, honest News/Order Flow placeholders and grouped Settings instead of long switch lists.
- Introduced shared Material icons, reusable product components, centralized semantic colors, Dark/Light/System themes and a RU/EN localization layer for the product shell.
- Trading engines, Journal persistence/tracking, entry/stop calculations and Backtest logic were not changed by this UI phase.
- Verification: `flutter analyze` clean; all 27 tests passed, including a narrow-screen shell test; desktop navigation, asset workspace, chart, Journal details, Research, RU/EN and Dark/Light were visually checked without browser errors.

## DONE — Dynamic Crypto Universe + Asset Explorer

- Public Bybit instruments/tickers now build the USDT Perpetual universe dynamically instead of using a permanent hardcoded asset list.
- Added Favorites, Top Liquid, Top Alts, Meme Coins, High Volatility and All categories, plus search and sorting.
- Asset Explorer shows price, 24h change, volume, turnover, volatility and honest fast/full-analysis states. Full SignalEngine analysis remains scoped to the selected asset workspace.
- Favorites and the last successful universe response are cached locally; missing network data produces a recoverable error without clearing valid cached assets.
- Selecting any supported asset opens a symbol-isolated Workspace; Scanner remains separate.
- Verification: `flutter analyze` clean; all 31 tests passed; Chrome debug launch succeeded; live public Bybit response contained 732 trading USDT Perpetual instruments at verification time.
- Git recovery point: `958f65c` (`add dynamic crypto universe and asset explorer`).

## DONE — LIVE price + confirmed-entry alerts

- Added mutually exclusive `⚡ LIVE` and `15s` modes. The economy timer is cancelled while LIVE is active; manual refresh remains available in both modes.
- LIVE uses the public Bybit linear WebSocket ticker with no authentication, publishes the newest in-memory price to UI widgets at most once per 350 ms, sends a 20-second heartbeat and reconnects with bounded backoff.
- Price widgets listen independently, so high-frequency ticks do not rebuild the complete Dashboard or rerun `SignalEngine`.
- A confirmed 1m WebSocket candle schedules one full REST/candle analysis refresh per minute in LIVE mode. The existing 15-second analysis remains exclusive to economy mode.
- Connection state is visible as `LIVE`, `CONNECTING` or `OFFLINE`; switching symbols closes the previous channel and subscribes to the selected asset.
- Added a strong-signal alert gate for a new `ENTRY_CONFIRMED`, with per-symbol cooldown, direction/quality exceptions and exact-signal deduplication.
- The modal shows Entry, Stop, TP1/TP2, R:R, leverage and real explanation reasons. Confidence is explicitly labelled factor confluence, never profit probability; USDT risk is not fabricated without a position size.
- Added an optional system alert sound in Settings. The WebSocket and all timers/subscriptions are closed during mode changes and application disposal.
- Safety remains `MONITOR / ANALYSIS ONLY`; no private Bybit endpoint, API key, order or execution path was introduced.
- Verification: `flutter analyze` clean; all 35 tests passed; Chrome debug launch succeeded; a live public Bybit WebSocket smoke-test received `tickers.BTCUSDT` with `lastPrice`.

## DONE — Smart Position Calculator

- Added a pure `PositionCalculator` after the existing Decision/structural-stop path. It never moves Entry, Stop or targets to manufacture a preferred leverage.
- The user enters allocated margin and chooses 1%, 2%, 3% or a custom risk. The calculator derives maximum loss, effective stop cost, risk-limited notional and rounds the recommended leverage down.
- A separate `LeverageSafety` caps the mathematical result using ATR, 24h volatility, structural-stop width, estimated spread, market regime, asset risk class, impulse/CHAOS state, Confidence and an approximate liquidation buffer. The hard product cap remains 10x.
- Added editable/persisted `FeeModel` settings for maker/taker rates, entry/target/stop order types, target/stop slippage, estimated spread and safety buffer. Defaults are estimates and are never presented as account-specific Bybit fees.
- Added gross/net stop and TP1/TP2/optional TP3 outcomes, Raw and Net R:R, costs-to-target ratio and a separate 0.3% small-move evaluation with WORTH IT / COSTS HIGH / SKIP verdicts.
- The calculator can return TRADE ACCEPTABLE, WAIT, LOW EDGE, SKIP THIS TRADE or TRADE BLOCKED and explains the result in plain language.
- Entry, Stop and TP fields can be overridden inside the calculator with immediate recalculation. The original Decision Engine structure remains unchanged.
- The calculator is available from Home, the asset Signal workspace and a strong ENTRY_CONFIRMED alert. It produces an execution-ready `SmartTradePlan`, but no order, API key or private Bybit endpoint was added.
- Future exchange constraints are represented by `qtyStep`, `minOrderQuantity`, `minNotional`, `tickSize` and exchange maximum leverage fields without pretending that account execution is connected.
- Verification: `flutter analyze` clean; all 47 tests passed; responsive calculator widget test passed at 430 px; Chrome debug launch connected and ran without runtime errors.

## DONE — Integration foundation, Bybit market depth, Telegram and Help

- Added a common `MarketDataProvider` boundary and normalized exchange venue/trading-rule models. Future OKX, Binance and Coinbase adapters can feed the existing `SignalEngine` without exchange JSON leaking into strategy code.
- Bybit public ticker data now includes bid/ask, real spread, mark/index price, funding, Open Interest and L1 orderbook timestamp. Instrument metadata retains `tickSize`, `qtyStep`, `minOrderQty`, `minNotionalValue` and maximum leverage.
- Smart Position Calculator now receives real Bybit trading constraints and uses an observed positive bid/ask spread instead of the configured estimate when current public data is available.
- Added explicit execution modes and an `ExecutionBroker` contract. The application uses monitor-only behavior; Paper and Demo report `NOT CONFIGURED`; the separate live broker is immutable `LIVE BLOCKED` and contains no HTTP client or credentials.
- Added browser-safe Official Telegram delivery through a local loopback relay. A PowerShell launcher reads Bot Token through a hidden prompt; Chat ID can be discovered in memory after `/start`. The Flutter application stores only relay enablement/address. Unique signal ID is used for relay deduplication, and Telegram cannot access any execution broker.
- The Integrations screen now shows Bybit market-depth fields, Telegram relay health/test delivery, future exchange adapters, isolated External Signal Sources and explicit execution-mode readiness.
- Added a read-only Help Engine and Help Center with current Decision Snapshot explanation, Getting Started, Signals, Risk, Bybit Demo, Telegram and FAQ content.
- Added centralized `ProductLinksConfig` plus About & Support. Missing links remain disabled and display `NOT CONFIGURED`.
- Verification: `flutter analyze` clean; all 55 tests passed; local Telegram relay health smoke-test passed safely without secrets; Chrome debug launch connected and started the application.

## DONE — Stable multi-asset foundation audit

- Re-audited Bybit V5 instruments/tickers, the dynamic USDT Perpetual universe, categories, search, favorites, sorting, cache, error handling, Asset Explorer and the selected-asset Workspace without rewriting working code.
- Verified that BTCUSDT, FARTCOINUSDT, ETHUSDT, SOLUSDT and XRPUSDT resolve to symbol-isolated candle histories; empty or invalid responses are rejected without replacing valid state.
- Added deterministic regression coverage for rapid symbol switching and failed/empty Bybit responses.
- Verification: `flutter analyze` clean; all 57 tests passed; Chrome debug launch succeeded.
- Git recovery point: `abfcd13` (`phase-1-dynamic-crypto-universe`).

## DONE — Personal Trading Journal foundation

- Expanded the existing Journal into one local Trading Journal with Overview, Trades, Calendar, Performance, Strategies, Mistakes, Notes and Reports; no duplicate storage or second journal was introduced.
- Manual trades support LONG/SHORT, open and closed lifecycle, planned and actual levels, TP1/TP2/optional TP3, size, margin, leverage, fees, strategy, timeframe, entry reason, free-form notes, tags and structured review fields.
- PnL, PnL %, planned R:R and Result R are derived from immutable trade records. Manual trades are excluded from Radar research by default.
- Source separation is explicit for MANUAL, PAPER and future BYBIT_DEMO. A single protected import boundary is ready for Paper/Demo execution facts; LIVE remains reserved and blocked.
- Journal Settings store a user-defined starting balance plus optional daily/weekly limits. Current Balance uses realized PnL only, so open trades do not alter it.
- Added period/source/symbol/strategy/result/side filters, sortable trades, interactive details and editable manual records. System execution facts cannot be deleted or overwritten, while personal notes/tags/reviews remain editable.
- Added a semantic trading calendar, daily reviews and notes, weekly/monthly reports and notes, best/worst day and week, strategy/asset/LONG-vs-SHORT/source breakdowns, mistakes and a fact/tag-based Discipline Score.
- Added an interactive local Equity Curve with period filtering, zoom/pan/reset and point tooltips. Metrics include balance, PnL/return, Net R, trades, WR, PF, drawdown, averages, streaks and best/worst trades/days.
- Trade records persist a version/context snapshot. Screenshot, chart snapshot and replay references are reserved without delaying the journal foundation.
- Verification: `flutter analyze` clean; all 67 tests passed, including dedicated model/engine/storage/widget coverage; Chrome debug launch connected and exited normally.

## DONE — Deterministic calculation hardening

- Exchange-step operations now use decimal arithmetic for `tickSize` and `qtyStep`; quantities floor exactly and LONG/SHORT Stop/TP prices round conservatively.
- Entry, target and Stop slippage alter execution prices before PnL. Market spread is applied through ask/bid only in explicit market mode.
- Entry and exit commissions use their own effective notionals and order types. Stop risk includes entry fee, Stop fee and configured safety buffer without double-counting slippage.
- Added typed validation for missing exchange rules, invalid directions, zero quantity after rounding, exchange minimums, risk overflow and invalid partial TP allocations.
- TP1/TP2/TP3 support 50/30/20 default partial exits plus weighted Raw/Net Result R.
- Journal numeric snapshots persist canonical decimal strings and realized calendar/equity statistics follow Exit chronology.
- Custom risk accepts 0.1–20%. The personal high-risk mode can select up to 10x only inside the mathematical risk and exchange limits; safe leverage remains visible and no execution is enabled.
- Regression coverage includes tiny/high prices, LONG/SHORT fees and slippage, conservative rounding, partial exits, save/load identity, Profit Factor edge cases, Exit-time equity and closed-candle MFE/MAE.
- Verification: `flutter analyze` clean; all 86 tests passed.

## DONE — Market-data integrity and cost-aware research foundation

- Added a mandatory `MarketDataIntegrity` gate. It validates source timestamps,
  candle ordering/gaps/OHLC, bid/ask freshness and complete Bybit instrument
  rules before a snapshot may receive HIGH/MEDIUM/LOW quality.
- The Stop Engine no longer invents `tickSize` or quantity constraints. Missing
  real exchange rules produce `INSTRUMENT_RULES_UNAVAILABLE` and block the
  setup instead of calculating a misleading trade plan.
- Added `HistoricalDataStore` with 1000-candle pagination, UTC normalization,
  deduplication, validation and local IndexedDB/file cache. Network failures do
  not erase previously validated history.
- Added a pure `ExecutionSimulator` for research only. It models bid/ask spread,
  separate entry/exit slippage, maker/taker fees on actual notionals, partial
  targets, optional funding events, exchange minimums and conservative
  Stop-before-TP ordering inside an ambiguous candle.
- Backtest headline Average R, Profit Factor and Drawdown now use net results.
  Raw and Net metrics plus total execution cost and Cost/Gross remain visible
  separately and survive report serialization.
- Added an `AccountRiskEngine` with account-equity risk, daily/weekly R limits,
  consecutive-loss cooldown, exposure/position limits and duplicate/conflicting
  position vetoes. It is active in the calculator only after account equity is
  configured; execution remains disabled.
- New installations no longer enable the personal high-risk leverage override
  by default. Signal generation stores 1x as a neutral reference; allowed
  leverage is calculated only after structural Stop, costs and account risk.
- Direction, location, entry, stop, liquidity, data, setup and risk quality are
  stored separately. Journal records retain engine versions and outcome flags,
  including `STOP_THEN_TARGET`, so a tight/liquidity Stop is not mislabeled as a
  wrong directional call.
- Regression tests cover data-quality vetoes, historical pagination/cache,
  LONG/SHORT cost-aware simulation, funding, same-candle ambiguity, account
  risk, old-report compatibility and outcome classification.
- Verification: `flutter analyze` clean; all 104 tests passed; Chrome debug
  launch connected, reached `main()` and exited normally without runtime errors.

## TODO

- Phase 3: deeper Market Structure Engine 2.0 and correction/BOS/CHOCH event history.
- Phase 4: scored Heavy Levels, OB, FVG and Liquidity engines.
- Phase 5: breakout/rejection and candle/volume behaviour.
- Phase 6: full Market Regime, Strategy Selector and explicit NO TRADE.
- Full 6–12 month rolling walk-forward/OOS research remains required before
  Paper Trading. The execution-cost model is implemented; historical fee-tier,
  funding and spread datasets still need a verified source for long studies.
- A Pine Script mirror may be added after the strategy is stable, but it would recalculate the strategy inside TradingView rather than read local Flutter signals. A licensed Advanced Charts integration is a later deployment option.
- Telegram outgoing `ENTRY_CONFIRMED` delivery is implemented through a local relay. Read-only commands, summaries and other external alert channels remain future work.
- Advanced chart roadmap: Volume Profile, Footprint/Clusters, Heatmap, Order Flow, Replay, Journal trade overlays and Backtest replay.
- Remaining UI depth: configurable Assets/Favorites/Opportunity Queue, real Alerts/News feeds, persisted UI preferences, Mistakes/Review editing and complete localization of legacy engine-generated explanation text.
- Personal Journal next steps: connect the prepared import boundary to a Paper broker first, then a separately secured Bybit Demo broker; screenshot files and replay overlays remain future additions.
- Product identity/config/help foundation is delivered. Real official URLs, expanded support content and compact sidebar footer remain configuration/polish work.
- Phases 7–16: see `CRYPTO_RADAR_ROADMAP.md`.

## Safety notes

- Current market-regime and entry-state labels in Phase 2 are preliminary summaries of existing engine outputs, not the future Phase 6 classifier.
- Scores and R:R target estimates are not guarantees or financial advice.
- Bybit remains market-data-only; no order, balance or position APIs are used.
- `ExecutionSimulator` is deterministic research code only. Demo, Auto Demo and
  LIVE order submission remain disconnected and blocked.
