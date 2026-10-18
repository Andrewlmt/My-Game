# ConfirmedTrendEA v2.20 (MetaTrader 5)

One Expert Advisor, attached once, that trades major forex pairs and crypto
with a trend-pullback strategy and shows an on-chart status dashboard.

**Read this first:** the evidence is modest. On data not used in design, crypto
showed a small edge (profit factor about 1.26, interval 0.9 to 1.7) and forex
was inconclusive (1.11, interval 0.6 to 1.9). Most entries lose; profit comes
from a minority of large winners. See `research/RESULTS.md`.

## What it does

- **Multi-symbol, one chart.** Attach a single instance to any chart. It trades
  every symbol in `InpSymbols` (default EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD,
  USDCAD, NZDUSD, BTCUSD, ETHUSD, XRPUSD). Symbols your broker lacks are
  skipped with a log message. Use `InpSymbolSuffix` for names like `EURUSD.a`.
- **Strategy** (closed H1 bars): EMA50 above EMA200, price above EMA200 and
  ADX >= 20 for an uptrend (mirrored for down); ATR at least 1.2x its 100-bar
  average; a pullback to the EMA20 zone followed by a bar that closes back
  through EMA20 with RSI above 50 and rising. Stop 1.5 ATR, trailing stop 3.0
  ATR, no fixed target.
- **Schedule (Malaysia time):** entries only on bars opening 3:30pm-11:00pm.
  Forex Tuesday-Thursday; crypto every day.
- **Risk:** fixed 0.02 lot by default, capped so no trade risks more than 5% of
  balance at its stop; optional risk-% sizing; account-wide limits on open risk,
  positions, entries per day, daily loss and loss streaks; $75 profit target.
- **Counter-trade (optional, OFF by default):** when a position is down 0.6R,
  open an opposite trade at 50% size with its stop at the losing position's
  entry; half is closed at TP1 (stop to break-even), the rest runs to TP2.
  Needs a hedging account. Testing found it neutral to slightly negative, so it
  is off unless you switch on `InpCounterEnabled`.

## Dashboard

Drawn on the chart where the EA runs (`InpShowDashboard`, dark or light):

- **Account and risk:** balance, equity, floating and today's P/L, progress to
  the profit target, margin level, free margin, open risk against its cap, daily
  loss used, entries today, loss streak, positions, session status for forex and
  crypto, and a status badge (ACTIVE, PAUSED, HALTED).
- **Pair table:** price, spread as % of ATR, trend on M15, H1, H4 and D1
  (UP/DN/--), volatility ratio, current state (waiting for pullback, signal,
  out of session, ...), open positions, net lots and P/L per pair.
- **Open positions:** pair, side, lots, entry, stop, P/L, R multiple and
  whether it is a main or counter-trade.
- **Next high-impact events** from MetaTrader's economic calendar, shown in
  Malaysia time with a countdown. This works in the live terminal only and
  depends on the broker providing calendar data.

## Installation

1. Copy `ConfirmedTrendEA.mq5` into `MQL5/Experts/` and compile in MetaEditor
   (F7). It was syntax-checked and run through a compatibility shim, never
   compiled in MetaEditor, so confirm there are no errors.
2. Attach it **once** to any chart and enable AutoTrading. A second instance
   with the same magic number refuses to start.
3. Set `InpBrokerGMTOffset` for your broker. Check the Experts tab: it lists the
   active symbols, asset classes and the counter-trade state.

## Before running live

- Run the Strategy Tester on your broker's real tick data over at least a year
  for the symbols you plan to trade, then forward-test on a demo account.
- Expect long flat and losing stretches: only 30-44% of entries win.
- The profit factor fell from 2.16 (development) to 1.26 (unseen) for crypto.
  Plan on the lower figure, then subtract your real costs.
- On a $100 account the fixed 0.02 lot is aggressive and BTC will usually be
  skipped by the risk cap. Risk-% sizing at 1-2% is more survivable.
- Crypto CFDs often charge overnight swaps; the EA has no news filter.
