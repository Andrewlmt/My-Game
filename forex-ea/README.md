# ConfirmedTrendEA v2 (MetaTrader 5)

A trend-pullback Expert Advisor for major forex pairs and crypto. It waits for
a confirmed trend, a volatility expansion and a pullback that resumes, takes a
small fixed-risk position, and lets a trailing stop run the winners.

**Read this first:** the evidence is modest. On data not used in design, crypto
showed a small edge (profit factor about 1.26, interval 0.9 to 1.7) and forex
was inconclusive (1.11, interval 0.6 to 1.9). Most entries lose; profit comes
from a minority of large winners. See `research/RESULTS.md` and the
"Before running live" list below.

## What changed from v1

A cross-check of v1 against hourly data found:

- It fired about once a month per pair and lost $70 over four EURUSD windows
  (one window alone lost $61 of a $100 account).
- The "pullback" was never verified, the trend filter was too fast, and a fixed
  point-based spread cap could not work on crypto.
- It allowed only one position, could not size crypto safely, and tracked the
  profit target per chart.

v2 adds a volatility-expansion filter, a real pullback test, per-symbol and
account-wide risk limits, risk-based position sizing, a chandelier trailing
stop, scale-in only when earlier positions are protected, crypto support and a
shared profit-target baseline.

## Strategy in one paragraph

On closed H1 bars: the trend is up when EMA50 > EMA200, price is above EMA200
and ADX(14) >= 20 (mirrored for down). ATR(14) must be at least 1.2x its
100-bar average. Price must have touched the EMA20 zone within the last 6 bars,
and the latest bar must close back through EMA20 in the trend direction with
RSI(14) above 50 and rising. The stop is 1.5 ATR; there is no fixed target. A
chandelier stop trails 3.0 ATR behind the best price since entry.

## Schedule (Malaysia time, GMT+8)

- Entries only on bars opening 3:30pm-11:00pm Malaysia time, which covers the
  London open through the London/New York overlap. Trading all 24 hours and
  trading only the US afternoon were both consistently worse in testing.
- Forex: Tuesday-Thursday only by default (Monday/Friday toggles available).
  Crypto: every day.
- Set `InpBrokerGMTOffset` to your broker's server offset (or enable
  `InpAutoGMTOffset` for live trading). A wrong offset shifts every filter.

## Position sizing and risk

- Default is the fixed 0.02 lot you asked for, with a hard cap: if the loss at
  the stop would exceed `InpMaxRiskPerTradePct` (5%) of balance, the lot is
  reduced, or the trade skipped if even the minimum lot is too big. On a $100
  account BTC will usually be skipped for this reason.
- `LOT_RISK_PERCENT` sizes each trade to `InpRiskPercent` of balance instead.
  For a $100 account, 1-2% is a more survivable choice than 4-5%.
- Account-wide limits (by magic number, so they cover every chart): total open
  risk 10% of equity, 4 positions, 6 entries per Malaysia day, stop for the day
  after an 8% daily loss or 3 consecutive losing closes.
- Profit target $75 (since the baseline by default, or daily). Reaching it
  stops new entries and closes open positions.

## Installation

1. Copy `ConfirmedTrendEA.mq5` into `MQL5/Experts/` and compile in MetaEditor
   (F7). It has been syntax-checked only against a compatibility shim, not
   compiled in MetaEditor, so confirm there are no errors.
2. Attach one instance per symbol on any timeframe (it uses `InpEntryTF`, H1 by
   default, regardless of the chart). Use the same magic number so the
   account-wide limits work.
3. Set `InpBrokerGMTOffset`. Enable AutoTrading.
4. Add the symbols your broker offers, e.g. EURUSD, GBPUSD, BTCUSD, ETHUSD.
   Symbols are recognised by name; use `InpAssetOverride` for unusual names.

## Before running live

- Run the Strategy Tester on your broker's real tick data over at least a year,
  for each symbol you plan to trade, and then forward-test on a demo account.
- Expect long flat and losing stretches: only 30-44% of entries win.
- The profit factor fell from 2.16 (development) to 1.26 (unseen) for crypto.
  Plan on the lower figure, then subtract your real costs.
- Crypto CFDs often charge overnight swaps; holds are typically 7-12 hours but
  can run for days with the trailing stop.
- Confirm your broker accepts 0.02 lots (or the minimum lot) on each symbol.
- The EA has no news filter.
