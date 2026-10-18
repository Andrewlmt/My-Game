# ConfirmedTrendEA v2.20 - Strategy & Operating Manual

## 1. What it does

The EA looks for a trending market that is moving more than usual, waits for a
pullback, and enters when the pullback ends. It does not predict reversals and
it does not use a fixed profit target: losing trades are cut at a fixed
distance and winners are allowed to run behind a trailing stop.

One instance, attached to any chart, watches every symbol in `InpSymbols` and
applies the same rules to major forex pairs and crypto. Every condition is
checked on closed H1 bars.

| Step | Rule (buy side; sell is the mirror) |
|---|---|
| 1. Trend | EMA50 above EMA200, price above EMA200, ADX(14) at least 20 |
| 2. Volatility expansion | ATR(14) at least 1.2 times its own 100-bar average |
| 3. Pullback | Within the last 6 bars price came within 0.25 ATR of EMA20, and EMA20 is above EMA50 |
| 4. Resume | The latest closed bar is bullish, closes above EMA20, and RSI(14) is above 50 and rising |
| 5. Session | The bar opened between 3:30pm and 11:00pm Malaysia time on an allowed day |
| 6. Risk checks | Position, daily and open-risk limits, spread, margin and cooldown all pass |

Why these pieces: the trend and ADX tests avoid chop; the volatility test was
the one filter that consistently improved results; the pullback-and-resume test
avoids buying an extended move; the session test keeps trading to the hours
with the most liquidity.

## 2. Exits

- **Stop-loss:** 1.5 ATR from entry, placed on the order.
- **Trailing stop:** after each new bar the stop moves to 3.0 ATR behind the best
  price since entry, and only ever tightens. This produces the large winners.
- **No fixed target** by default (`InpTPR` can add one). Taking profit early
  lowered results in testing, including a 50%-at-TP1 split on main trades, so
  TP1/TP2 is used only for counter-trades.
- **Scaling in:** a second position in the same direction is allowed only when
  every existing main position on that symbol already has its stop at or beyond
  its entry price. Netting accounts are limited to one position per symbol.
- **Profit target:** when profit reaches `InpProfitTargetUSD` (default $75,
  measured from a shared baseline) the EA stops entering and closes everything.

## 3. Counter-trade (optional, off by default)

Switch on with `InpCounterEnabled` on a **hedging** account.

1. A main position is down `InpCounterTriggerR` (0.6) times its initial stop
   distance.
2. The EA opens an opposite trade sized `InpCounterVolPct` (50%) of it. Its stop
   sits at the losing position's entry price; its TP1 and TP2 are 1.0x and 2.5x
   its own stop distance.
3. At TP1 half of the counter is closed and its stop moves to break-even; the
   remainder runs to TP2.
4. One counter per position, never a counter of a counter, never larger than the
   position it hedges, and counters do not use up your daily entry allowance.
   Their risk still counts toward the open-risk cap.

**Evidence:** in the simulations it was neutral to slightly negative in every
pool (see `research/RESULTS.md`): it paid the spread twice, cut winners that
began with a dip, and did not reduce drawdown. A hedge locks in a loss; it does
not remove it. It is built because you asked for it, but it is off unless you
decide to test it yourself.

**What reduces loss and protects capital** (and is on by default): the hard
per-trade risk cap, risk-% sizing, the open-risk cap, the daily-loss stop, the
loss-streak pause, the profit target, trading only the Malaysia session, and
keeping size small relative to the account.

## 4. When it trades (Malaysia time, GMT+8)

- Forex: Tuesday-Thursday, 3:30pm-11:00pm. Monday and Friday are switches; adding
  them made results worse in testing.
- Crypto: every day, same hours (`InpCryptoAllDays`).
- The hours are judged by the time the H1 bar opened, so a bar opening at 3:00pm
  is skipped and one opening at 4:00pm is allowed.
- The EA converts broker server time with `InpBrokerGMTOffset`; brokers that
  change their clock for daylight saving need it updated twice a year, or turn
  on `InpAutoGMTOffset` (live only).

## 5. How often it trades - measured

From the simulations (hourly data, modelled costs):

| What you run | Entries |
|---|---|
| One crypto symbol | about 0.15 per day |
| A basket of 7-8 coins together | about 1 per day; two or more on 60-70% of active days |
| One forex pair | about 1.3 per month |
| All seven forex majors together | about 0.3 per day |

So "multiple entries per day" is realistic only across a basket of crypto
symbols, and many days have none. Only 30-44% of entries win, 35-38% of trading
days finish positive, and the profit comes from a minority of large winners.

## 6. Risk and position size

- **Default lot:** fixed 0.02. On a $100 account that risks roughly $4-5 per forex
  trade. The worst simulated single-symbol drawdown was about 10 times the
  per-trade risk, so expect a drawdown near 40-50% of $100 at that size.
  Entries happen when volatility is above average, so stops are often wider than
  usual and the 5% cap may shrink 0.02 to 0.01 lots.
- **Safer option:** `LOT_RISK_PERCENT` with 1-2%. If even the minimum lot risks
  more than the cap, the trade is skipped.
- **Hard cap:** `InpMaxRiskPerTradePct` (5%) always applies. This is why BTC is
  often skipped on a $100 account.
- **Account-wide limits** (every symbol, same magic number): 4 main positions,
  open risk of unprotected positions at most 10% of equity, 6 entries per
  Malaysia day, no new entries after an 8% daily loss or 3 consecutive losing
  closes, and margin use at most 50% of free margin.
- **Spread:** entries wait while the spread is above 20% of ATR, then retry on
  later ticks of the same bar.

## 7. The dashboard

- **Header:** version, Malaysia time, status badge (ACTIVE, PAUSED - DAILY LOSS,
  PAUSED - LOSS STREAK, LIMIT - ENTRIES TODAY, HALTED - PROFIT TARGET) and
  whether the forex and crypto sessions are open.
- **Account rows:** balance, equity, floating and today's P/L, target progress,
  margin level, free margin, open risk against its cap, daily loss used,
  entries, loss streak, positions, counter state, sizing and stops.
- **Pair table:** price, spread as % of ATR (amber above the limit), trend arrows
  for M15/H1/H4/D1 (UP/DN when EMA50 vs EMA200 and price vs EMA200 agree, `--`
  when mixed), volatility ratio (green when the filter is met), state, open
  positions, net lots and P/L. `*` marks crypto.
- **Open positions:** each position with side, lots, entry, stop, P/L, R multiple
  and MAIN or COUNTER. R shows `prot.` once the stop is at or beyond entry.
- **Economic calendar:** the next high-impact events for the currencies of your
  symbols, in Malaysia time with a countdown, refreshed every 10 minutes. It
  needs the live terminal and calendar data from the broker; it is empty in the
  Strategy Tester.
- Turn off with `InpShowDashboard`, change colours with `InpDashDark`, and move
  it with `InpDashX/Y`.

## 8. Health check

Printed in the Experts tab when the EA starts, and re-checked every 30 seconds
(live terminal only):

- Terminal: build, broker connection, algo-trading switch, ping, whether it is
  the MetaQuotes VPS terminal.
- Account: number, server, demo or real, leverage, hedging or netting, currency
  and balance.
- Warnings: no connection, algo trading off, the account blocking EAs, non-USD
  account currency, counter-trades on a netting account, a broker clock that
  does not match `InpBrokerGMTOffset`, symbols that are restricted, a minimum lot
  above your fixed lot, margin above the margin cap, and too little history.
- Per symbol: lot limits, contract size, margin for your lot, bars loaded.
- Sizing preview (about 30 seconds in): the lot a typical trade would get on
  each symbol, or why it would be skipped.
- Later: a warning when the connection or algo trading drops or returns, and an
  "alive" line every 6 hours with balance, equity and floating P/L.

## 9. Inputs reference

| Input | Default | Meaning |
|---|---|---|
| `InpSymbols` / `InpSymbolSuffix` | 7 majors + BTC, ETH, XRP / none | Symbols to trade; empty = chart symbol only |
| `InpUnknownSymbols` | skip | Treat unrecognised names as forex or crypto |
| `InpLotMode` / `InpFixedLot` / `InpRiskPercent` | fixed / 0.02 / 2.0 | How lots are chosen |
| `InpMaxRiskPerTradePct` | 5.0 | Hard cap on loss at the stop, % of balance |
| `InpMaxOpenRiskPct` | 10.0 | Cap on summed risk of unprotected positions |
| `InpMaxMarginUsePct` | 50.0 | Max share of free margin for one new trade |
| `InpMaxPositionsPerSymbol` / `InpMaxPositionsTotal` | 2 / 4 | Main-position limits |
| `InpMaxEntriesPerDay` | 6 | Entries per Malaysia day, all symbols |
| `InpDailyLossPct` / `InpPauseAfterLosses` | 8.0 / 3 | Daily stop-outs |
| `InpMagicNumber` | 20260928 | One EA instance per magic number |
| `InpCounterEnabled` | false | Master switch for counter-trades |
| `InpCounterTriggerR` / `InpCounterVolPct` | 0.6 / 50 | When to hedge and how big |
| `InpCounterTP1R` / `InpCounterTP2R` / `InpCounterTP1Pct` | 1.0 / 2.5 / 50 | Counter targets and the share closed at TP1 |
| `InpProfitTargetUSD` / `InpTargetScope` | 75 / since start | Profit target and its scope |
| `InpStopAtProfitTarget` / `InpCloseAllAtTarget` | true / true | What the target does |
| `InpResetBaseline` | false | Re-take the since-start baseline (turn off again) |
| `InpAllowForex` / `InpAllowCrypto` | true / true | Class switches |
| `InpBrokerGMTOffset` / `InpAutoGMTOffset` | 2.0 / false | Server clock offset |
| `InpSessionStart*` / `InpSessionEnd*` | 15:30 / 23:00 | Malaysia session |
| `InpTradeMonday` ... `InpTradeFriday` | Tue-Thu | Forex days |
| `InpCryptoAllDays` | true | Crypto ignores the day switches |
| `InpForexTrendTF` / `InpCryptoTrendTF` | H1 / H1 | Trend timeframe per class |
| `InpTrendFastEMA` / `InpTrendSlowEMA` | 50 / 200 | Trend EMAs |
| `InpADXPeriod` / `InpADXMin` | 14 / 20 | Trend strength |
| `InpEntryTF` | H1 | Entry timeframe (other values untested) |
| `InpEntryFastEMA` / `InpEntryMidEMA` | 20 / 50 | Pullback EMAs |
| `InpRSIPeriod` / `InpRSIGate` | 14 / 50 | Resume momentum test |
| `InpPullbackLookback` / `InpPullbackZoneATR` | 6 / 0.25 | Pullback touch test |
| `InpATRPeriod` / `InpVolLookback` / `InpMinVolRatio` | 14 / 100 / 1.2 | Volatility expansion; 0 disables |
| `InpCooldownBars` | 2 | Bars between entries on a symbol |
| `InpMaxSpreadPctATR` | 20 | Spread limit as % of ATR |
| `InpSLATR` / `InpTrailATR` / `InpTPR` | 1.5 / 3.0 / 0 | Exit settings |
| `InpShowDashboard` / `InpDashX` / `InpDashY` / `InpDashFont` / `InpDashDark` | true / 10 / 20 / 9 / true | Dashboard |
| `InpDashPositionRows` / `InpShowCalendar` / `InpCalendarRows` / `InpCalendarHours` | 6 / true / 5 / 72 | Dashboard sections |
| `InpVerbose` | false | Log why signals are skipped |

## 10. Running it

1. Compile in MetaEditor and fix anything it reports. The source was checked
   only against a compatibility shim, never in MetaEditor.
2. Attach **one** instance to any chart, set `InpBrokerGMTOffset`, enable
   AutoTrading. A second instance with the same magic number will not start.
3. Check the Experts tab at start-up: it lists the active symbols, timeframes,
   per-symbol position limit, GMT offset and counter-trade state. Turn on
   `InpVerbose` for the first days to see why signals are skipped.
4. Run the Strategy Tester first (real ticks, a year or more, each symbol you
   plan to trade), then a demo forward-test. `VPS.md` covers moving it to a VPS.

## 11. Honest limitations

- The evidence is a bar-level simulation over a limited set of periods. Crypto
  held a modest edge on data not used in design; the forex result was
  inconclusive. Profit factor shrank from 2.16 to 1.26 between development and
  unseen crypto data.
- Only H1 entries were tested. M15 would trade more often but was not validated.
- The counter-trade did not help in testing.
- No news filter, no commission or funding modelled, and ADX smoothing differs
  slightly in MetaTrader.
- The EA logic was verified against the simulator through a shim, but the
  dashboard's real appearance, the economic calendar and MetaEditor compilation
  have not been tested.
- A $100 account is very small for this system. The default fixed 0.02 lot is
  aggressive for it; consider risk-percent sizing at 1-2% or a larger balance.
- Nothing here guarantees profit. Forward-test before risking real money.
