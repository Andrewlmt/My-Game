# ConfirmedTrendEA — Strategy & Operating Manual

## 1. What the strategy actually does

ConfirmedTrendEA is a **trend-pullback** system, not a breakout or a
scalper. It never trades on its own opinion of "up" or "down" — it needs
three independent things to agree before it risks money:

| Layer | Timeframe | Question it answers | Tool |
|---|---|---|---|
| **Trend** | Higher TF (default H1) | Is there a real trend right now? | EMA(50) vs EMA(200) for direction, ADX(14) > 25 to confirm strength |
| **Location** | Trading TF (chart TF) | Has price pulled back to a sane entry point? | EMA(20) — price must be back at/through it, not chasing an extended move |
| **Momentum** | Trading TF | Has the pullback actually turned back in the trend's favor? | RSI(14) crossing back through 50 in the trend direction |

Only when all three line up on the **same side** does it open a trade —
and only during the allowed days/hours, and only on the seven major pairs.

**Why this shape:** EMA50/EMA200 alone gives you direction but trades every
crossover including chop; adding ADX filters out the "no real trend"
periods where trend-following gets chopped up. Entering on an EMA(20)
pullback instead of the breakout itself means you're not paying for the
move that already happened — you're joining the *continuation*. The RSI-50
cross is the trigger that says the pullback is over and momentum has
resumed, rather than guessing the exact bottom/top of the pullback.

## 2. Exit logic

- **Stop-loss:** entry price ± `ATR(14) × 1.5` (default). ATR-based, not a
  fixed pip count, so the stop automatically widens in volatile conditions
  and tightens in quiet ones — same distance in "how unusual is this move"
  terms, in every market condition.
- **Take-profit:** entry price ± `ATR(14) × 3.0` (default) — a 2:1
  reward:risk ratio, meaning it only needs to win roughly 34%+ of trades to
  break even before costs, and more than that to be profitable.
- **Trailing stop (optional, on by default):** once a position is open,
  the stop trails behind price by `ATR(14) × 1.0`, locking in gains as a
  trend extends beyond the original take-profit distance without needing
  to guess where the trend ends.
- **Account-level circuit breaker:** once floating + closed profit since
  the EA started reaches **$75**, it stops opening new trades and (by
  default) closes what's open — it will not try to "give it back" chasing
  more.

## 3. Trading calendar & session (Malaysia time, GMT+8)

- **Days:** Tuesday, Wednesday, Thursday only.
  - Monday is skipped — the weekend gap and thin early liquidity make
    stops and fills less reliable right after the market reopens.
  - Friday is skipped — positions held into the weekend carry gap risk on
    Monday's open with no way to react; the EA would rather sit out than
    hold that risk on a $100 account.
- **Session:** 3:30pm–11:00pm Malaysia time by default. In UTC that's
  roughly 07:30–15:00, which spans the **London session opening through
  the London/New York overlap** — historically where major-pair volume,
  volatility, and trend persistence are highest. Outside this window
  (Asian session, late NY, weekends) the EA does nothing, even if a signal
  technically fires.
- The EA converts your broker's server clock to Malaysia time internally
  (`InpBrokerGMTOffset`), so this holds regardless of what timezone your
  broker's server runs on — see the README for how to set that input.

## 4. Occurrence of trade — how often should you expect a signal?

I have not yet been able to run this against real historical price data —
the market-data tools in this environment are hitting a platform-side
outage right now (their safety-classifier service isn't returning a
verdict, so calls to it are failing regardless of what's being asked for).
I'll run the actual 5-year backtest and give you measured numbers as soon
as that clears. In the meantime, here's a reasoned estimate from the rules
themselves, so you know what to expect and aren't surprised by how quiet
it is:

- **ADX > 25 on H1** typically holds maybe 25–40% of the time on a major
  pair — trending conditions are the minority, which is the point of the
  filter.
- Within that trending window, a **fresh EMA(20) pullback + RSI-50 cross**
  is an occasional event, not a per-bar one — realistically a handful of
  times per week per pair when a trend is actually in place, fewer in a
  quiet trend, more in a choppy-but-still-"trending-by-ADX" one.
- Restricting to **Tuesday–Thursday, 3:30pm–11:00pm MYT** cuts the
  available window to roughly 22.5 hours a week (3 days × 7.5 hours) out
  of the ~120 hours/week forex majors trade — about **19%** of total
  market time.
- **Net estimate:** roughly **1–4 trades per week per pair** under normal
  trending conditions, and **weeks with zero trades** when majors are
  range-bound (which happens often — this system is designed to sit out
  rather than force a trade). Running it on more than one major pair
  independently increases the number of *opportunities* seen, but each
  pair still only trades its own confirmed trend.
- This is a low-frequency, high-selectivity system by design — it is built
  to avoid overtrading a small account, not to generate constant activity.

I'll replace this section with real measured trade counts, win rate, and
drawdown once I can pull 5 years of price history.

## 5. Inputs reference

| Input | Default | Meaning |
|---|---|---|
| `InpLotSize` | 0.02 | Fixed lot size per trade |
| `InpProfitTargetUSD` | 75.0 | Stops new trades once profit since EA start reaches this |
| `InpStopAtProfitTarget` | true | Whether the profit target halts trading at all |
| `InpCloseAllAtTarget` | true | Whether to also close open trades when the target hits |
| `InpMagicNumber` | 20260928 | Identifies this EA's own trades |
| `InpMaxSpreadPoints` | 30 | Skips new entries if current spread exceeds this |
| `InpTradeTuesday/Wednesday/Thursday` | true | Toggle each day on/off individually |
| `InpMajorPairsOnly` | true | Refuses to trade anything outside the 7 majors list |
| `InpBrokerGMTOffset` | 2.0 | Your broker server's GMT offset — **must be set correctly** |
| `InpSessionStartHour/Minute` | 15 / 30 | Session start, Malaysia time (3:30pm) |
| `InpSessionEndHour/Minute` | 23 / 0 | Session end, Malaysia time (11:00pm) |
| `InpTrendTF` | H1 | Higher timeframe used for the trend filter |
| `InpTrendFastEMA` / `InpTrendSlowEMA` | 50 / 200 | Trend EMAs |
| `InpADXPeriod` / `InpADXThreshold` | 14 / 25.0 | Trend-strength filter |
| `InpEntryEMA` | 20 | Pullback reference EMA on the trading timeframe |
| `InpRSIPeriod` | 14 | Momentum trigger |
| `InpRSIOverbought` / `InpRSIOversold` | 70 / 30 | Avoids chasing an exhausted move |
| `InpATRPeriod` | 14 | Volatility measure for SL/TP/trailing |
| `InpSL_ATRMult` / `InpTP_ATRMult` | 1.5 / 3.0 | Stop-loss / take-profit distance in ATR multiples |
| `InpUseTrailing` / `InpTrail_ATRMult` | true / 1.0 | Trailing stop toggle and distance |

## 6. How to run it — step by step

1. Copy `ConfirmedTrendEA.mq5` into your MT5 terminal's `MQL5/Experts/`
   folder and compile it in MetaEditor (F7) — confirm 0 errors, 0 warnings.
2. Open a chart of a major pair (e.g. EURUSD), pick a trading timeframe
   (M15–H1 recommended, since the trend filter is H1).
3. Drag the EA onto the chart. In the Inputs tab:
   - Set `InpBrokerGMTOffset` to your broker's actual GMT offset.
   - Leave `InpLotSize` at 0.02 for a ~$100 account, or scale it if your
     balance is different.
   - Leave the day/session inputs as-is unless you want a different window.
4. Enable AutoTrading in the toolbar. The EA will now do nothing until a
   Tuesday–Thursday, 3:30pm–11:00pm-MYT bar closes with all three
   confirmation layers aligned.
5. Watch the **Experts** log tab — it prints when the profit target is hit
   and when a pair isn't in the major-pairs list; trade opens/closes show
   up as normal order events in the **Trade**/**History** tabs.

## 7. What one trade looks like end to end

1. On H1, EMA50 crosses/holds above EMA200 and ADX(14) is above 25 →
   uptrend confirmed.
2. On the chart timeframe, price dips back down to touch/cross EMA(20)
   (a pullback within the uptrend, not a reversal).
3. RSI(14), which had dipped toward/below 50 during the pullback, closes a
   bar back above 50 → momentum has turned back up.
4. If it's Tuesday–Thursday, within the 3:30pm–11:00pm MYT window, spread
   is acceptable, and there's no existing position on this pair/magic
   number: the EA buys `InpLotSize` lots, with SL at `entry − 1.5×ATR` and
   TP at `entry + 3.0×ATR`.
5. From there: either price hits SL (loss ≈ 1.5×ATR in pips), hits TP
   (gain ≈ 3.0×ATR), or the trailing stop locks in a smaller gain if price
   reverses after moving favorably but before reaching TP.
6. If, at any point, cumulative profit since the EA started reaches $75,
   any open trade is closed immediately and no new ones open, regardless
   of what step 1–3 say.

## 8. Honest limitations

- This is a **fixed-lot, fixed-rule** system — it doesn't adapt lot size to
  balance, and it doesn't learn from past trades. Its edge (if any) comes
  entirely from the trend/pullback/momentum logic being sound over time.
- ADX-based trend filters lag — they confirm a trend after it's already
  moved, which is the trade-off for avoiding chop. It will occasionally
  enter late in a trend that then reverses shortly after.
- A $100 account at 0.02 lots on majors is thin margin for error: a short
  losing streak (a handful of stopped-out trades) is a meaningful hit to a
  $100 balance in percentage terms even though each individual loss is
  small in dollars. Treat the $75 target and the Tue–Thu/session
  restriction as risk controls, not profit guarantees.
- Nothing here has been validated against real historical prices yet —
  that's next, once the data tools are back.
