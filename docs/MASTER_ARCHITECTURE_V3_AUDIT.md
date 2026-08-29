# Crypto Radar — Master Architecture V3 Audit

Audit date: 2026-08-29  
Audited checkpoint: `60daacf` (`checkpoint entry ready notifications`)  
Scope: current Flutter application, local storage, public Bybit data, research,
journal, chart, Telegram relay and execution boundaries.

## Status legend

- **DONE** — the current scope is implemented and has automated coverage. It
  does not mean that a trading edge or future profitability is proven.
- **PARTIAL** — a reusable foundation exists, but the V3 contract is incomplete.
- **NOT STARTED** — only a placeholder, enum, reserved field or roadmap text may
  exist; there is no working domain implementation.
- **BROKEN** — current behavior conflicts with a non-negotiable V3 rule.

## 1. CURRENT STATE

Crypto Radar is a working local-first Flutter analysis application, not a 24/7
trading system. The current runtime is hosted by the Flutter UI and analyzes one
selected asset deeply. It has a dynamic Bybit USDT perpetual universe, public
market data, deterministic analysis, staged entry/stop logic, a connected chart,
a local journal, cost-aware simulation/backtest, a position calculator, a Help
Center and a local Telegram relay. Private Bybit trading is not connected and
LIVE execution is deliberately blocked.

The repository contains 100 Dart files under `lib/` (about 27.7k lines) and 24
test files (about 3.6k lines). `main.dart` is small; the main orchestration debt
is now `radar_screen.dart`, while `signal_engine.dart` remains the largest domain
engine.

## 2–4. MASTER PLAN COVERAGE

| # | Master block | Status | Evidence and gap |
|---:|---|---|---|
| 0 | Main goal | PARTIAL | The product supports observe/analyze/wait/risk/journal/research, but statistical edge is not proven and the runtime is not an always-on system. |
| 1 | Trading corporation / desks | PARTIAL | Structure, indicators, liquidity and execution logic exist, but they are not independent evidence-producing desk contracts; much analysis still lives in `SignalEngine`. |
| 2 | Data Center | PARTIAL | `MarketDataProvider`, `BybitService`, `LivePriceService`, instrument rules, ticker, candles, L1 bid/ask, funding and current OI exist. Public trades, liquidation stream, options and per-feed health states are missing. |
| 3 | 24/7 architecture | NOT STARTED | Timers, WebSocket, analysis, journal and alerts run inside Flutter. There are no collector/analysis/research/audit worker processes. |
| 4 | Historical database | PARTIAL | `HistoricalDataStore` paginates, validates, deduplicates and caches candles. There are no A/B/C tiers, retention/rotation, or historical trades/OI/funding/order-book datasets. |
| 5 | Market Structure / SMC desk | PARTIAL | HH/HL/LH/LL, BOS/CHOCH, trend/correction annotations, FVG, OB, S/R and sweep/reclaim foundations exist. HTF/local separation, breaker/mitigation, premium/discount and full event semantics are incomplete. |
| 6 | Liquidity / Big Player desk | PARTIAL | Basic liquidity levels, sweep/false-breakout, overshoot, reclaim and reaction tracking exist. There is no real cluster map, aggressive-trade evidence, liquidation map or OI/volume-zone history. |
| 7 | Order Flow desk | NOT STARTED | The workspace is an honest placeholder; no trades/delta/CVD/imbalance/absorption engine exists. |
| 8 | Derivatives desk | PARTIAL | Current funding and OI are displayed. OI change history, price/OI state classification, liquidation data and futures-activity evidence are missing. |
| 9 | Options / Gamma desk | NOT STARTED | No Bybit option adapter or estimated gamma model exists. |
| 10 | Classical Technical desk | DONE | EMA20/50/200, RSI, MACD, ATR, Fibonacci, Ichimoku, RVOL, support/resistance, momentum and volatility are deterministic evidence inputs. |
| 11 | Macro / Cross-market desk | NOT STARTED | No DXY/equities/gold/VIX/yields/FX feeds or rolling/lag correlation engine exists. |
| 12 | News / Event Risk | NOT STARTED | The screen explicitly reports `NOT_CONNECTED`; news does not yet veto trades. |
| 13 | Market Regime Engine | PARTIAL | `trendUp`, `trendDown`, `range`, `mixed` exist. BREAKOUT, high/low volatility, CHAOS, central NO_TRADE and regime confidence are missing. |
| 14 | Strategy Selector | PARTIAL | Standard/scalp signals and fixed execution profiles exist, but there is no strategy-family permission selector driven by regime. |
| 15 | Trading Mode / Horizon | PARTIAL | Standard and 1m scalp are distinct. Momentum, Intraday, Swing, Spot, Grid and Custom are not independent profiles with their own logic/UI contract. |
| 16 | Market Scanner | PARTIAL | Dynamic universe, categories, search, sorting and fast liquidity/volatility views work. There is no 24/7 four-level cascade or deep-analysis candidate queue. |
| 17 | Top Opportunities | NOT STARTED | No mode-specific, signal-quality-ranked 3–8 opportunity board exists. Current scanner lists market categories, not READY quality. |
| 18 | Near Ready watchlist | NOT STARTED | No persisted/ranked candidates with one missing condition exist. |
| 19 | Entry state machine | PARTIAL | SETUP_FOUND, WAIT_FOR_ZONE, WAIT_FOR_TRIGGER, ENTRY_CONFIRMED, position/TP/stop/cancel/expire exist. Zone/liquidity/reclaim/candidate/READY/missed/too-late/invalidated states are incomplete; READY is currently derived, not persisted. |
| 20 | Next Action | PARTIAL | Home clearly displays DO NOT ENTER / WAIT / ENTRY READY and the main reason. The complete typed action set is not implemented. |
| 21 | Setup Quality | BROKEN | Direction/location/liquidity/entry/stop/risk/data/setup scores exist, but dormant `RadarSignal.riskRewardEstimates` fabricates a percentage from hardcoded coefficients and the unused `RiskRewardTable` calls it “Вероятность”. This violates V3 even though it is not currently mounted. Historical Evidence and contradiction level are absent. |
| 22 | Contradiction Engine | NOT STARTED | Warnings exist, but no severity-aware independent-evidence contradiction model or major-conflict veto exists. |
| 23 | Meta / Quality Gate | PARTIAL | Data integrity, Phase A quality checks, stop safety, account risk and `EntryReadinessGate` exist. They are not yet one immutable gate applied identically to every live/backtest/paper path. |
| 24 | Stop Engine 2.0 | DONE | Structural invalidation precedes ATR/wick/tick/overshoot buffers; poor stop safety or R:R can veto. Tests cover long/short and stop-then-target behavior. |
| 25 | Leverage | PARTIAL | Position sizing occurs after stop/risk; safe and personal caps are separate and never exceed 10x. Mode-specific allowed ranges and portfolio/account execution context are incomplete. |
| 26 | Risk Committee | PARTIAL | `AccountRiskEngine` covers per-trade/open/daily/weekly risk, losses, trades/day, positions, duplicate/conflicting setup and leverage. It is calculator-scoped, not an absolute central veto; news, correlation and full exposure are missing. |
| 27 | Portfolio Risk | NOT STARTED | No correlation/beta/concentration exposure model exists. |
| 28 | Opportunity Cost | NOT STARTED | There is no capital-aware ranking of simultaneously READY setups. |
| 29 | Signal Expiration | PARTIAL | Cancelled/expired and dedupe/cooldown exist. `validUntil`, explicit cancel conditions, MISSED and TOO_LATE lifecycle are incomplete. |
| 30 | BTC context for alts | NOT STARTED | Selected assets are isolated; BTC shock/structure/liquidity context is not injected into alt decisions. |
| 31 | Futures Grid mode | NOT STARTED | No grid detector/configuration/risk/paper engine exists. |
| 32 | Grid backtest | NOT STARTED | No grid-specific simulator or metrics exist. |
| 33 | Black Box Recorder | PARTIAL | Signals/trades retain many context fields, engine versions and canonical calculations. There is no complete immutable pre-outcome snapshot of all evidence, settings and source health. |
| 34 | Journal | PARTIAL | Manual trades, notes/tags/reviews, calendar, reports, equity and breakdowns work. Paper/Demo ingestion, screenshot/replay artifacts and fully immutable decision snapshots are incomplete. |
| 35 | Trade Auditor | PARTIAL | `TradeOutcomeClassifier` and positive/error flags cover most requested labels; the full post-trade evidence audit and review workflow are not unified. |
| 36 | Stop-then-target | DONE | Tracker persists stop time, overshoot/ATR, reclaim, post-stop TP1/TP2, MFE and MAE; research reports expose the rate. |
| 37 | Backtest | PARTIAL | It reuses `SignalEngine`, Phase A and tracker chronologically with no lookahead and conservative same-candle ordering; costs are simulated. History is short, funding/microstructure are not fully historical, and full rolling walk-forward is absent. |
| 38 | Research Engine | PARTIAL | Execution-profile comparison, factors and guarded learning exist. There is no hypothesis registry, reproducible experiment catalog or automatic report workflow. |
| 39 | Champion / Challenger | PARTIAL | Guarded profile learning has validation/OOS gates, but there is no explicit immutable Champion, shadow Challenger or promotion workflow. |
| 40 | Factor Value Research | PARTIAL | Factor sample/WR/Avg R is shown. Ablation, incremental value, factor correlation and redundancy analysis are missing. |
| 41 | Contextual Weights | NOT STARTED | No regime/symbol/timeframe/strategy-conditioned evidence weighting research exists. |
| 42 | Concept Drift | NOT STARTED | No rolling degradation detector or UNDER REVIEW lifecycle exists. |
| 43 | Sample Size / Confidence | PARTIAL | Learning and factor reports show sample sizes and readiness. Similar-setup evidence confidence is not part of each live decision. |
| 44 | Performance Metrics | PARTIAL | WR, Avg R, PF, drawdown, MFE/MAE, duration, stop-then-target, equity, period/asset/strategy/side breakdowns exist. Median R, recovery factor, stability and regime/OOS reporting need completion. |
| 45 | Replay | NOT STARTED | Reference fields are reserved; there is no time-stepped trade/backtest replay. |
| 46 | Paper / Demo / Live | PARTIAL | Mode/broker boundaries exist; Paper and Demo are unconfigured and LIVE is immutably blocked. PAPER is not yet the active default execution simulator and RESEARCH is not a first-class mode. |
| 47 | Security | DONE | Flutter stores no Bot Token/API secret, Telegram uses loopback relay, no private Bybit client exists and LIVE broker cannot place orders. Future Demo credentials still need a secure gateway. |
| 48 | Telegram | PARTIAL | ENTRY READY delivery has dedupe/cooldown and no order permission. Cancel/TP/stop/news/connection events and a 24/7 host are missing. |
| 49 | Main UI design | DONE | Adaptive professional shell, dark/light/system themes, semantic colors, focus hierarchy and restrained status markers exist. |
| 50 | Main screen | PARTIAL | Selected-asset decision/action/quality/risk are strong. System status strip, trading-mode selector, Top Opportunities and Near Ready are missing. |
| 51 | Table design | PARTIAL | Responsive signal/journal/research tables emphasize core fields. Hide/show/resize/reorder and saved layouts are not implemented. |
| 52 | Focus workspace | PARTIAL | Overview/chart/structure/levels/volume/signal/why/journal/news sections exist. Order Flow, derivatives, gamma and contextual statistics are absent/placeholders. |
| 53 | Why? | DONE | Deterministic snapshot-based explanation covers market state, support/opposition, wait/entry/stop/target/invalidation and risk; it does not alter decisions. |
| 54 | Fail Safe | PARTIAL | Integrity checks catch stale/missing/bad candles, bid/ask and rules and force NO TRADE. Database errors can still degrade silently; abnormal-move/provider-health and global fail-safe state need expansion. |
| 55 | Backup | NOT STARTED | No user-facing or scheduled journal/settings/research backup exists. |
| 56 | Performance architecture | PARTIAL | Price ticks are throttled and do not rerun full analysis; full analysis uses slower intervals. All work still shares the Flutter process and a heavy backtest can occupy the web isolate. |
| 57 | Human Control | NOT STARTED | No global PAUSE / NO NEW ENTRIES / CLOSE ONLY or per-asset/strategy kill controls exist. |
| 58 | Local-first / Cost | DONE | Local stores, public/free Bybit data and deterministic engines are used; no paid AI/API dependency or LLM decision maker exists. |
| 59 | Do-not-build-now rules | DONE | No auto-live, commercial system, customer accounts or self-modifying production strategy exists. |
| 60 | Development rule | PARTIAL | Small commits, tests and docs are used, but architecture boundaries and roadmap/status documents need consolidation before more features. |
| 61 | Proposed phases | PARTIAL | Existing phases overlap V3; the revised safe order below should supersede feature-first expansion. |
| 62 | Current audit | DONE | This document, Git checkpoint, analyzer/test results and safe next phase complete the requested audit. |

No runtime module is currently confirmed broken by automated tests. The single
**BROKEN** classification above is a product/decision-integrity violation, not a
compiler failure.

## 5. ARCHITECTURAL PROBLEMS

1. Flutter is both UI and runtime host. Closing the app stops deep analysis,
   tracking and Telegram delivery.
2. `SignalEngine` is still a large multi-domain engine. Adding nine desks to it
   would recreate the monolith prohibited by V3.
3. `radar_screen.dart` is a composition root, refresh scheduler, live-data
   coordinator, alert dispatcher and navigation host at once.
4. `SignalStage` and `SignalStatus` duplicate lifecycle concepts and can drift.
   ENTRY READY is currently a derived gate, not a durable state transition.
5. Live UI preview, journal updates and alert evaluation reconstruct decisions
   through adjacent paths. A single immutable analysis result should feed all
   consumers.
6. Historical candles are stored, but historical spread, trades, OI, funding and
   source-health provenance are not. Backtest realism is therefore limited.
7. Local JSON/IndexedDB stores have no explicit backup/restore, retention policy,
   transaction boundary or surfaced corruption status.
8. Scanner ranking is based on inexpensive market properties, not an evidence
   cascade and READY state.
9. `pubspec.yaml` still has the template description/version (`1.0.0+1`), so
   About/build identity is not yet a reliable release contract.

## 6. TECHNICAL DEBT

- Remove the hardcoded “probability” calculation before it can re-enter UI.
- Introduce typed `Evidence`, `DeskResult`, `NextAction`, `Veto` and
  `HistoricalEvidence` contracts without changing current signal behavior.
- Split orchestration out of `radar_screen.dart` into an application controller.
- Add schema versions/migrations and explicit storage error health.
- Add tests for `EntryReadinessGate` and the real ENTRY READY Telegram payload.
- Add a deterministic clock/source timestamp boundary to all engines.
- Make 4h a real analysis input only after historical/live sufficiency is proven.
- Move CPU-heavy research off the Flutter web isolate before expanding history.
- Add structured local diagnostics with secret redaction.

## 7. TEST RESULTS

- `flutter analyze`: **PASS — No issues found**.
- `flutter test`: **PASS — 105 tests**.
- Tests cover no-lookahead windows, conservative stop-before-target ordering,
  market integrity, decimal/exchange rounding, fees/slippage, long/short,
  account risk, journal serialization/statistics, chart behavior and UI shell.
- Missing high-value coverage: EntryReadinessGate truth table, ENTRY READY
  Telegram payload/relay formatting, multi-source staleness, long-running
  reconnect, storage corruption surfaced to UI, and 24/7 process recovery.
- Chrome visual run: **NOT VERIFIED in this audit** because the managed Chrome
  connection is unavailable. Analyzer and widget tests are not presented as a
  substitute for visual inspection.

## 8. GIT STATUS

- Branch: `master`.
- Checkpoint: `60daacf checkpoint entry ready notifications`.
- Working tree after checkpoint: clean.
- Previous checkpoints include market integrity/cost research, UI focus/action,
  calculation hardening, journal, dynamic universe and Telegram launcher fixes.

## 9. SAFE IMPLEMENTATION ORDER

1. **A1 — Decision Integrity Stabilization.** Remove fabricated probability,
   introduce Historical Evidence as unavailable-by-default, test one shared
   ENTRY READY/NO TRADE gate, and reconcile lifecycle terminology.
2. **A2 — Domain Contracts.** Add immutable Evidence/Desk/Veto/NextAction and a
   single analysis result. Adapt current engines without changing outputs.
3. **B — Trading Modes + Regime/Strategy contracts.** Start with Quick Scalp
   and Intraday as genuinely different profiles; validate each separately.
4. **C — Structure/Liquidity 2.0.** Extract current SMC/liquidity logic into
   desks and improve event state semantics before adding more indicators.
5. **D — Central Meta Gate + Risk Committee.** Make every live/paper/backtest
   candidate pass the same veto pipeline.
6. **E — Scanner cascade + Top/Near Ready.** Rank only after modes and gates are
   deterministic; READY: 0 remains valid.
7. **F — Black Box/Journal/Research.** Freeze pre-outcome snapshots, add
   migrations/backups, longer walk-forward/OOS and factor ablation.
8. **G — 24/7 local service.** Move collector/analysis/tracker/alerts outside
   Flutter; keep the UI a client. This unlocks reliable phone alerts.
9. **H — Order Flow/Derivatives/BTC context**, then **News/Macro/Options**, only
   with real timestamped data and measurable incremental value.
10. **I — Paper trading**, then manual-confirmation Bybit Demo through a secure
    gateway. LIVE remains locked.
11. **J — Grid research/paper engine** as a separate strategy family, not an
    extension of directional signals.

## 10. FIRST SMALL IMPLEMENTATION PHASE

**Phase A1: Decision Integrity Stabilization** should be the next and only
implementation phase:

1. Delete/retire heuristic `probabilityPercent` and `recommendedRiskReward` as
   decision inputs. Do not replace them with another guessed percentage.
2. Add `HistoricalEvidence` with `sampleSize`, `averageR`, `profitFactor`,
   `oosResult` and confidence; default to `NOT_AVAILABLE` until real matching
   samples exist.
3. Make `EntryReadinessGate` return a typed `NextAction` and explicit veto
   reasons and use the same result in Home, alerts and future execution.
4. Add gate tests for stale data, missing rules, outside Entry Zone, missing
   liquidity, weak Stop/Risk, duplicate transition and valid ENTRY READY.
5. Add Telegram payload/relay tests; keep orders impossible.

Acceptance gate: no strategy-weight changes, no new data source, no UI redesign,
`flutter analyze` clean, all tests pass, Chrome visual smoke-check completed, and
one dedicated Git commit.
