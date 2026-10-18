# Backtest evidence for ConfirmedTrendEA v2

This is the record behind the claims in `README.md` and `MANUAL.md`. It is a
bar-level simulation, not MetaTrader's Strategy Tester, so treat the numbers as
a screening result and re-run the EA in the Strategy Tester on your own
broker's data before risking money.

## Method

- Engine: `sim.py` in this folder. Decisions are made at the open of a bar from
  the previous closed bar. Prices are bid-based with a modelled spread
  (buys fill at the ask). If a bar touches both stop and target the stop is
  assumed to hit first. Trailing-stop updates apply from the next bar.
- Sizing: every trade risks a fixed amount (1R) so instruments are comparable.
  Results are in R; for a 0.02-lot EURUSD stop of 1.5 ATR, 1R is about $4.4.
- Data: hourly candles. Twelve Data (timestamps converted from Sydney time to
  UTC, fabricated weekend bars removed) plus a public EURUSD 2017 sample.
  - Forex: 7 majors Mar-Oct 2026 and Sep 2024-Jun 2025; EURUSD Apr-Oct 2022
    and Apr 2017-Feb 2018.
  - Crypto: BTC, ETH, SOL, XRP, DOGE, ADA, LTC, BNB for Mar-Oct 2026 and
    Dec 2024-Jun 2025; BTC also Dec 2023-Jun 2024.
- Spreads assumed: EURUSD 1.0 pip, GBPUSD 1.5, USDJPY 1.2, AUDUSD 1.2,
  NZDUSD 1.8, USDCAD/USDCHF 1.5; crypto 0.03%-0.10% of price. No commissions,
  swaps or funding fees.
- Design discipline: designs were chosen on the "development" sets, then scored
  on "holdout" sets. The crypto windows Dec 2024-Jun 2025 (all alts) and BTC
  Dec 2023-Jun 2024 were not looked at until the crypto design was frozen
  ("pristine"). The forex holdout (Sep 2024-Jun 2025) was scored before the
  final forex trend timeframe was picked, so it is no longer clean.

## v1 (old EA) on identical EURUSD windows, 0.02 lot

| Window | Trades | Win % | Net on $100 | Profit factor | Max drawdown |
|---|---|---|---|---|---|
| Apr 2017 - Feb 2018 | 12 | 42 | -$5 | 0.82 | $15 |
| Apr - Oct 2022 | 13 | 38 | -$9 | 0.80 | $39 |
| Sep 2024 - Jun 2025 | 12 | 17 | -$61 | 0.11 | $63 |
| Mar - Oct 2026 | 8 | 63 | +$6 | 1.77 | $8 |
| **Total** | **45** | | **-$70** | | |

v1 traded about once a month per pair, not 1-4 times a week as the first
manual estimated, and could lose most of a $100 account in one window.

## What the exploration showed

Aggregate profit factor (PF) across datasets. "Final config" means the
shipped defaults.

| Idea | Result |
|---|---|
| London/New York session (15:30-23:00 Malaysia) vs 24 hours | Better in every pool. Crypto 1.89 vs 1.45 (development). Forex final config: development 1.75 vs 1.24, holdout 1.11 vs 0.85 |
| US-afternoon window (12-20 UTC) | Worse than the Malaysia window: crypto 1.14 vs 1.89, forex holdout 0.50 vs 1.11 |
| Tue-Thu vs Mon-Fri (forex, final config) | Tue-Thu better: development 1.75 vs 1.57, holdout 1.11 vs 0.74. Earlier, before the volatility filter, Mon-Fri also had about double the drawdown |
| Closing forex positions on Friday | About neutral (1.66 vs 1.75 development, 1.11 vs 1.11 holdout); left off |
| Trend filter timeframe | Forex: H4 and H1 indistinguishable pooled (1.45 vs 1.50), H1 gives more trades. Crypto: H1 better on pristine data (1.26 vs 1.08) |
| Partial exit at 1R | Lowered PF in all four pools (e.g. crypto development 1.59 vs 2.16); dropped |
| Break-even stop at 1R | Mixed (crypto pristine 1.43 vs 1.26, but forex and crypto development lower); dropped |
| Breakout entries | Only 8-27 trades per pool, too few to judge; dropped |
| Wider chandelier trail (2.0 -> 3.5 ATR) | PF rose monotonically (crypto 1.52 -> 2.56); 3.0 chosen as a middle value |
| Trend-slope and EMA-separation filters | Tried on EURUSD 2017 only; no help; not used |

Volatility filter (ATR over its 100-bar average), crypto development pool:

| Min ratio | none | 0.9 | 1.0 | 1.1 | 1.2 | 1.3 | 1.5 |
|---|---|---|---|---|---|---|---|
| PF | 1.12 | 1.16 | 1.38 | 1.64 | 1.89 | 2.28 | 3.31 |
| Trades | 659 | 397 | 323 | 251 | 191 | 134 | 79 |

The relationship is monotonic, which is more convincing than a single good
setting, but every threshold shrinks the number of trades. 1.2 is the default.

## Final configuration results

Both asset classes: H1 trend filter, H1 entries, volatility ratio >= 1.2, 1.5
ATR stop, 3.0 ATR chandelier trail, up to 2 positions, Malaysia session.
Forex also Tue-Thu only. The 90% interval is a bootstrap over trades and is
optimistic because trades cluster in time.

| Pool | Trades | Win % | Profit factor | 90% interval | Avg R |
|---|---|---|---|---|---|
| Forex development (9 sets) | 91 | 41 | 1.75 | 1.10 - 2.62 | +0.36 |
| Forex holdout, Sep 2024 - Jun 2025 (7 pairs) | 61 | 38 | 1.11 | 0.60 - 1.92 | +0.05 |
| Forex all (16 sets) | 152 | 40 | 1.50 | 1.04 - 2.06 | +0.23 |
| Crypto development (9 sets) | 270 | 43 | 2.16 | 1.58 - 2.85 | +0.56 |
| **Crypto pristine (8 sets)** | 239 | 33 | **1.26** | 0.90 - 1.68 | +0.15 |
| Crypto all (17 sets) | 509 | 38 | 1.69 | 1.35 - 2.09 | +0.36 |

Takeaways:

- Crypto: the volatility filter turned a losing pristine result (PF 0.93 for
  the earlier design without it) into PF 1.26, with 6 of 8 sets profitable.
  Development to pristine shrank PF from 2.16 to 1.26, so plan on the low end,
  not the high end. The pristine interval still includes 0.90.
- Forex: positive on development data, near break-even on the holdout
  (PF 1.11, interval 0.6 to 1.9). That is inconclusive, not proof of an edge.
  Five of the 16 forex sets lost money, and each set has only 3-18 trades.
- Costs: at 3x the assumed spread the pristine crypto PF is 1.18 and the
  all-forex PF is 1.24, so the result is not just a thin-spread artefact.
- EURUSD alone, same four windows as the v1 table: PF 1.30 / 1.95 / 2.08 / 1.85
  and +$78 net on 53 trades at about $4.4 per R (v1: -$70 on 45 trades). Those
  windows were partly used in design, so this is not an out-of-sample figure.

## Trade frequency and shape

- Crypto basket (7-8 coins together): about 1.0-1.2 entries per calendar day,
  two or more entries on 60-70% of active days, median hold 7-10 hours.
- Forex basket (7 pairs together, Mar-Oct 2026): about 0.30 entries per day;
  two or more on 17 of 26 active days.
- One symbol on its own: roughly 0.15 entries per day (crypto) or 1.3 per
  month (forex).
- Only 30-44% of entries win. Profit comes from a minority of large winners
  (the trailing stop), and only 35-38% of days that closed trades were net
  positive. Expect long flat or losing stretches.
- Worst single-symbol drawdown on pristine crypto was 10.6R. At 1R = 2% of the
  account that is roughly a 21% drawdown; at 1R = 4.4% (0.02-lot EURUSD on a
  $100 account) it is roughly 47%.

## Not tested

- M15/M5 entries, or entry timeframes other than H1.
- Real tick data, commissions, slippage beyond the modelled spread, overnight
  swaps and crypto funding.
- Economic-news events; the EA has no news filter.
- ADX smoothing in MetaTrader differs slightly from the simulator's Wilder
  implementation, which can shift trade counts a little.
- Independence: all coins move with the broader crypto market, so eight coins
  are far fewer than eight independent samples.
