# Crypto Radar — Implementation Status

Last updated: 2026-08-25

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

## TODO

- Phase 3: Market Structure Engine 2.0 and correction/BOS/CHOCH events.
- Phase 4: scored Heavy Levels, OB, FVG and Liquidity engines.
- Phase 5: breakout/rejection and candle/volume behaviour.
- Phase 6: full Market Regime, Strategy Selector and explicit NO TRADE.
- Phases 7–15: see `CRYPTO_RADAR_ROADMAP.md`.

## Safety notes

- Current market-regime and entry-state labels in Phase 2 are preliminary summaries of existing engine outputs, not the future Phase 6 classifier.
- Scores and R:R target estimates are not guarantees or financial advice.
- Bybit remains market-data-only; no order, balance or position APIs are used.
