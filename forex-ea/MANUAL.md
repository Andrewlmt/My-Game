# ConfirmedTrendEA v2 - Strategy & Operating Manual

## 1. What it does

The EA looks for a trending market that is moving more than usual, waits for a
pullback, and enters when the pullback ends. It does not predict reversals and
it does not use a fixed profit target: losing trades are cut at a fixed
distance and winners are allowed to run behind a trailing stop.

Every condition below is checked on closed H1 bars, and the same rules apply to
major forex pairs and crypto.

| Step | Rule (buy side; sell is the mirror) |
|---|---|
| 1. Trend | EMA50 above EMA200, price above EMA200, ADX(14) at least 20 |
| 2. Volatility expansion | ATR(14) at least 1.2 times its own 100-bar average |
| 3. Pullback | Within the last 6 bars, price came within 0.25 ATR of EMA20, and EMA20 is above EMA50 |
| 4. Resume | The latest closed bar is bullish, closes above EMA20, and RSI(14) is above 50 and rising |
| 5. Session | The bar opened between 3:30pm and 11:00pm Malaysia time on an allowed day |
| 6. Risk checks | Position, daily and open-risk limits, spread, margin and cooldown all pass |

Why these pieces: the trend and ADX tests avoid trading chop; the volatility
test was the one filter that consistently improved results (crypto profit
factor rose steadily as the minimum ratio rose); the pullback-and-resume test
avoids buying an extended move; the session test keeps trading to the hours with
the most liquidity.

## 2. Exits

- **Stop-loss:** 1.5 ATR from entry, placed on the order.
- **Trailing stop:** after each new bar the stop moves to 3.0 ATR behind the
  best price since entry, and only ever tightens. This is what produces the
  large winners.
- **No fixed target** by default. `InpTPR` can add one in R multiples, but
  testing suggested taking profit early reduces results.
- **Scaling in:** a second position in the same direction is allowed only when
  every existing position on that symbol already has its stop at or beyond
  its entry price, so adding does not add risk. Netting accounts are limited to
  one position per symbol.
- **Profit target:** when profit reaches `InpProfitTargetUSD` (default $75,
  measured from a shared baseline) the EA stops entering and closes open
  positions.

## 3. When it trades (Malaysia time, GMT+8)

- Forex: Tuesday-Thursday, 3:30pm-11:00pm. Monday and Friday are switches
  (`InpTradeMonday`, `InpTradeFriday`); adding them made results worse in
  testing.
- Crypto: every day, same hours (`InpCryptoAllDays`).
- The hours are judged by the time the H1 bar opened, so a bar opening at
  3:00pm is skipped and one opening at 4:00pm is allowed.
- The EA converts broker server time with `InpBrokerGMTOffset`. Brokers that
  change their clock for daylight saving need the value updated twice a year,
  or turn on `InpAutoGMTOffset` (live only).

## 4. How often it trades - measured

From the simulations in `research/RESULTS.md` (hourly data, modelled costs):

| What you run | Entries |
|---|---|
| One crypto symbol | about 0.15 per day |
| A basket of 7-8 coins together | about 1 per day; two or more on 60-70% of active days |
| One forex pair | about 1.3 per month |
| All seven forex majors together | about 0.3 per day |

So "multiple entries per day" is realistic only across a basket of crypto
symbols, and even then many days have none. The earlier manual's estimate of
1-4 trades a week per pair was wrong; v1 actually traded about once a month.

Results shape to expect: only 30-44% of entries win, 35-38% of trading days
finish positive, and the profit comes from a minority of large winners. A run
of ten losses is normal.

## 5. Risk and position size

- **Default lot:** fixed 0.02 (`InpLotMode = LOT_FIXED`). For a $100 account
  that risks roughly $4-5 per forex trade, about 4-5% of the balance. The
  simulations' worst single-symbol drawdown was about 10 times the per-trade
  risk, so expect a drawdown near 40-50% of a $100 account at that size.
  Entries happen when volatility is above average, so stops are often wider
  than usual and the 5% cap below may shrink 0.02 to 0.01 lots on a $100
  account.
- **Safer option:** `LOT_RISK_PERCENT` with `InpRiskPercent` of 1-2%.
  With very small balances the minimum lot can still exceed that, in which case
  the trade is skipped.
- **Hard cap:** `InpMaxRiskPerTradePct` (default 5%) always applies. If the
  planned lot would lose more than that at the stop, the lot is reduced or the
  trade skipped. This is why BTC is often skipped on a $100 account.
- **Account-wide limits** (all charts sharing the magic number): 4 open
  positions, open risk of unprotected positions at most 10% of equity, 6
  entries per Malaysia day, no new entries after an 8% daily loss or 3
  consecutive losing closes, and margin use at most 50% of free margin.
- **Spread:** entries wait while the spread is above 20% of ATR, then retry on
  later ticks of the same bar.

## 6. Inputs reference

| Input | Default | Meaning |
|---|---|---|
| `InpLotMode` / `InpFixedLot` / `InpRiskPercent` | fixed / 0.02 / 2.0 | How lots are chosen |
| `InpMaxRiskPerTradePct` | 5.0 | Hard cap on loss at the stop, % of balance |
| `InpMaxOpenRiskPct` | 10.0 | Cap on summed risk of unprotected positions |
| `InpMaxMarginUsePct` | 50.0 | Max share of free margin for one new trade |
| `InpMaxPositionsPerSymbol` / `InpMaxPositionsTotal` | 2 / 4 | Position limits |
| `InpMaxEntriesPerDay` | 6 | Entries per Malaysia day, all symbols |
| `InpDailyLossPct` / `InpPauseAfterLosses` | 8.0 / 3 | Daily stop-outs |
| `InpMagicNumber` | 20260928 | Shared by all charts of this EA |
| `InpProfitTargetUSD` / `InpTargetScope` | 75 / since start | Profit target and its scope |
| `InpStopAtProfitTarget` / `InpCloseAllAtTarget` | true / true | What the target does |
| `InpResetBaseline` | false | Re-take the since-start baseline (turn off again) |
| `InpAssetOverride` | auto | Force forex or crypto for unusual symbol names |
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
| `InpVerbose` | false | Log why signals are skipped |

## 7. Running it

1. Compile in MetaEditor and fix anything it reports. The source was checked
   only against a compatibility shim, never in MetaEditor.
2. Attach one instance per symbol with the same magic number, set
   `InpBrokerGMTOffset`, enable AutoTrading.
3. Turn on `InpVerbose` for the first days to see why signals are skipped.
4. Check the Experts tab at start-up: it prints the detected asset class,
   timeframes, per-symbol position limit and GMT offset.
5. Run the Strategy Tester first (real ticks, a year or more, each symbol),
   then a demo forward-test.

## 8. Honest limitations

- The evidence is a bar-level simulation over a limited set of periods. Crypto
  held a modest edge on data not used in design; the forex result was
  inconclusive. Profit factor shrank from 2.16 to 1.26 between development and
  unseen crypto data.
- Only H1 entries were tested. M15 would trade more often but was not
  validated.
- No news filter, no commission or funding modelled, and ADX smoothing differs
  slightly in MetaTrader.
- A $100 account is very small for this system. The default fixed 0.02 lot is
  aggressive for it; consider risk-percent sizing at 1-2% or a larger balance.
- Nothing here guarantees profit. Forward-test before risking real money.
