# ConfirmedTrendEA (MetaTrader 5)

A trend-confirmation Expert Advisor built for a small, high-leverage account,
trading only on the days and pairs where liquidity is typically best.

## Strategy logic

1. **Trend filter (higher timeframe, default H1):** EMA(50) vs EMA(200)
   defines direction; ADX(14) above a threshold (default 25) confirms the
   move is actually trending rather than ranging. No trend confirmation, no
   trade.
2. **Entry trigger (chart timeframe):** price pulls back to/through EMA(20)
   in the trend direction, and RSI(14) crosses back through 50 in that same
   direction (filtered so it won't chase an already-overbought/oversold
   move). Signals are evaluated once per closed bar, not every tick.
3. **Exit:** ATR-based stop-loss and take-profit (defaults 1.5x / 3x ATR),
   plus an optional ATR trailing stop once in profit.
4. **Position sizing:** fixed lot size (default 0.02) — matched to a ~$100
   account at 1:500 leverage. This is not risk-% based sizing; adjust
   `InpLotSize` if your balance changes materially.
5. **Trading calendar:** Tuesday–Thursday only by default (skips Monday
   gaps/low liquidity and Friday's weekend-close risk), within a **Malaysia
   time (GMT+8)** session window — default 3:30pm–11:00pm, which covers the
   London/New York overlap where major-pair trends are usually strongest.
   The EA converts the broker's server clock to Malaysia time using
   `InpBrokerGMTOffset` (set this to your broker's GMT offset — check your
   platform or ask your broker; commonly +2 or +3), so the day-of-week and
   session-hour checks stay correct in Malaysia time no matter what
   timezone the server runs on.
6. **Instrument filter:** restricted to the seven major USD pairs
   (EURUSD, GBPUSD, USDJPY, USDCHF, AUDUSD, USDCAD, NZDUSD) unless disabled.
7. **Profit target:** tracks equity minus the balance recorded at `OnInit`.
   Once floating + realized profit reaches `InpProfitTargetUSD` (default
   $75), the EA stops opening new trades and, if enabled, closes any open
   position — locking in gains rather than giving them back.

Only one position is held at a time per symbol/magic number.

## Installation

1. Copy `ConfirmedTrendEA.mq5` into your terminal's
   `MQL5/Experts/` folder.
2. Compile it in MetaEditor (F7).
3. Attach it to a chart of a major pair, on the timeframe you want it to
   trigger entries on (M15–H1 is reasonable given the H1 trend filter).
4. Set `InpLotSize`, `InpProfitTargetUSD`, and the trading-day/session
   inputs to match your broker's server time.

## Before running live

- **Backtest and forward-test on a demo account first.** No EA, including
  this one, guarantees consistent profit — markets change regime, and a
  trend-following system will have losing streaks in choppy conditions.
- Confirm your broker's minimum lot/step size accepts 0.02 lots on the
  pairs you intend to trade.
- Set `InpBrokerGMTOffset` correctly for your broker before relying on the
  session window — an incorrect offset shifts both the Tuesday–Thursday
  and 3:30pm–11:00pm (Malaysia time) filters by however many hours you're
  off. Most brokers publish their server's GMT offset, or you can compare
  a chart's timestamp against a known GMT+8 clock.
- Malaysia doesn't observe daylight saving, but many brokers' servers do
  (shifting by ±1 hour), so `InpBrokerGMTOffset` may need updating twice a
  year for those brokers.
- The profit target resets only when the EA is reloaded/reattached (it
  measures profit since `OnInit`, i.e. since the EA last started). If you
  want a strict daily reset, restart the EA each trading day or extend it
  to track balance at the start of each calendar day.
