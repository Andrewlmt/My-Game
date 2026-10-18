# Running ConfirmedTrendEA on a VPS

I could not connect to your MT5 from the cloud session I work in, so none of
this has been tried on your terminal. The EA now checks itself on start-up and
every 30 seconds; use that to confirm each step below, and paste the Experts log
back if anything looks off.

## 0. Before you move it

1. Compile `ConfirmedTrendEA.mq5` in MetaEditor (F7) with 0 errors.
2. Strategy Tester on real ticks, a year or more, for the symbols you will use.
3. Run it on a demo account for a few weeks first.
4. Attach it once, set the inputs, and read the **Experts** tab. The start-up
   health check prints, for example:

   ```
   ---- ConfirmedTrendEA health check ----
   Terminal build 5200 | connected yes | algo trading yes | MetaQuotes VPS no | ping 45 ms
   Account 5012345 @ Broker-Server | demo | leverage 1:500 | hedging | currency USD | balance 100.00
   EURUSD (forex) | trading allowed | lot min 0.0100 step 0.0100 | ... | bars 5000 / 5000
   WARNING: ...
   ---- health check finished: 0 warning(s) ----
   SIZING EURUSD: a typical 1.5 ATR stop (0.00250) would trade 0.0100 lot, risking 2.50 (2.3% of balance).
   ```

   The `SIZING` lines appear within about 30 seconds once indicator data loads.
   They show what lot each symbol would really get, and which symbols would be
   skipped (BTC on a $100 account, for instance).
5. The dashboard's Broker / Algo / Account / Ping / Mode / Health row shows the
   same checks live. A red item is something to fix before you rely on it.

What the health check warns about: no broker connection, algo trading switched
off, the account blocking EAs (investor password), a non-USD account currency
(the $75 target is in account currency), counter-trades enabled on a netting
account, a broker clock that does not match `InpBrokerGMTOffset`, symbols the
account cannot trade or whose minimum lot exceeds your fixed lot, margin that
exceeds the margin cap, and too little loaded history.

## 1. Two ways to run on a VPS

| | MetaQuotes VPS (built into MT5) | Windows VPS (remote desktop) |
|---|---|---|
| Setup | Subscribe from MT5, then migrate | Rent a Windows server, install MT5 |
| You can see the chart | No (only the journal log) | Yes, over remote desktop |
| Dashboard useful | Not really | Yes |
| Cost / control | Cheap, limited resources | More control, more upkeep |

### MetaQuotes VPS

1. Log in to your MQL5.community account in MT5 (Tools > Options > Community).
2. Subscribe to a Virtual Hosting plan (menu wording varies by build: in the
   Navigator, right-click your account and choose to register a virtual server).
3. Attach the EA to a chart with the inputs you want, with algo trading on.
4. Right-click the account again and choose to synchronise or migrate experts,
   indicators and chart settings. Only compiled `.ex5` files run there; this EA
   uses no DLLs.
5. Check the VPS journal for the same start-up health check.
6. Before migrating, consider setting `InpShowDashboard = false` and
   `InpShowCalendar = false` in the inputs: you cannot see the chart on that
   VPS, and it removes 8 extra indicators per symbol.

### Windows VPS

1. Install MT5 from your broker and log in; tick save password.
2. File > Open Data Folder, copy the `.mq5` into `MQL5\Experts`, compile it.
3. Attach it once, enable Algo Trading, and allow algorithmic trading in the EA
   properties.
4. Set Windows to auto-login and start MT5 at start-up, and turn off sleep, so a
   reboot recovers by itself.
5. Pick a VPS close to your broker's server (low ping; the dashboard shows it).

## 2. Do not run it twice

Only one machine may trade a given account with this EA. The EA's lock protects
one terminal only. After moving to a VPS, remove the EA from your home
terminal (or close it), otherwise both will trade the same signals.

## 3. What survives a restart

- Open positions and their stops live at the broker, so they are safe.
- The EA rebuilds its state from the positions' comments, the deal history and
  terminal global variables: daily counters, loss streak, the profit-target
  baseline and counter-trade bookkeeping all recover.
- The per-symbol cooldown restarts, so one extra entry right after a restart is
  possible.
- The profit-target baseline is stored in the terminal. A fresh VPS terminal may
  start it again from the current balance; set `InpResetBaseline` once if you
  want that deliberately.

## 4. Resources

Each symbol uses 7 indicators, plus 8 more when the dashboard is on. Ten symbols
is about 150 indicators with the dashboard and 70 without. If the VPS is small,
trim `InpSymbols` or switch the dashboard off.

## 5. First-week checklist

- Experts tab shows the health check with 0 warnings (or only ones you accept).
- `InpBrokerGMTOffset` matches the broker clock (the check warns if not).
- Spreads: the dashboard's SPR%ATR column stays below the limit most of the day.
- Entries happen only between 3:30pm and 11:00pm Malaysia time, on the right days.
- Nothing trades after the daily-loss or loss-streak pause.
- Compare the first trades with what you expect from `MANUAL.md` before adding
  size.
