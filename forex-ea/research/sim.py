"""Bar-level simulator used to test ConfirmedTrendEA v2 (see RESULTS.md).

Input is a pandas DataFrame of H1 OHLC candles in UTC; call prepare() then run().
The candle files used for RESULTS.md are not stored in this repository.

Decisions at the open of bar i from closed bar i-1; bid-based series; buys fill
at ask (open + spread); sells at bid. Stop-before-target when both touch in one
bar. Trail/partial/BE updates apply from the next bar. Sizing: fixed risk in USD
per trade (R) so instruments are comparable; PnL reported in USD and R.
"""
import numpy as np
import pandas as pd


def ema(s, n):
    return s.ewm(span=n, adjust=False).mean()


def rsi(c, n=14):
    d = c.diff()
    up = d.clip(lower=0).ewm(alpha=1 / n, adjust=False).mean()
    dn = (-d.clip(upper=0)).ewm(alpha=1 / n, adjust=False).mean()
    return 100 - 100 / (1 + up / dn.replace(0, np.nan))


def _tr(h, l, c):
    return pd.concat([h - l, (h - c.shift()).abs(), (l - c.shift()).abs()], axis=1).max(axis=1)


def atr_sma(h, l, c, n=14):
    return _tr(h, l, c).rolling(n).mean()


def adx(h, l, c, n=14):
    up, dn = h.diff(), -l.diff()
    pdm = pd.Series(np.where((up > dn) & (up > 0), up, 0.0), index=h.index)
    mdm = pd.Series(np.where((dn > up) & (dn > 0), dn, 0.0), index=h.index)
    a = 1 / n
    atr_w = _tr(h, l, c).ewm(alpha=a, adjust=False).mean()
    pdi = 100 * pdm.ewm(alpha=a, adjust=False).mean() / atr_w
    mdi = 100 * mdm.ewm(alpha=a, adjust=False).mean() / atr_w
    dx = 100 * (pdi - mdi).abs() / (pdi + mdi).replace(0, np.nan)
    return dx.ewm(alpha=a, adjust=False).mean()


def prepare(df, trend_tf="4h"):
    d = df.rename(columns=str.lower)[["open", "high", "low", "close"]].copy()
    d["ema20"], d["ema50"], d["ema200"] = ema(d.close, 20), ema(d.close, 50), ema(d.close, 200)
    d["rsi"], d["atr"], d["adx"] = rsi(d.close), atr_sma(d.high, d.low, d.close), adx(d.high, d.low, d.close)
    d["hh20"], d["ll20"] = d.high.rolling(20).max(), d.low.rolling(20).min()
    d["atr_ratio"] = d.atr / d.atr.rolling(100).mean()
    t = d[["open", "high", "low", "close"]].resample(trend_tf, label="left", closed="left").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}).dropna()
    t["t_ema50"], t["t_ema200"], t["t_adx"] = ema(t.close, 50), ema(t.close, 200), adx(t.high, t.low, t.close)
    t["t_close"] = t.close
    t["t_adx3"] = t.t_adx.shift(3)
    t["avail"] = t.index + pd.Timedelta(trend_tf)
    left = pd.DataFrame({"t": d.index}).sort_values("t")
    m = pd.merge_asof(left, t[["avail", "t_ema50", "t_ema200", "t_adx", "t_close", "t_adx3"]].sort_values("avail"),
                      left_on="t", right_on="avail", direction="backward")
    for col in ("t_ema50", "t_ema200", "t_adx", "t_close", "t_adx3"):
        d[col] = m[col].values
    return d


BASE = dict(
    risk_usd=4.4, spread_abs=None, spread_pct=None, quote_usd=True,
    days=(1, 2, 3), sess=(7.5, 15.0),                      # UTC hours (= 15:30-23:00 MYT)
    trend="h4", adx_min=20.0, modes=("pb",),
    pb_lookback=6, pb_zone=0.25, pb_rsi=50, bo_adx=22, bo_ext=2.0,
    sl_mode="atr", sl_atr=1.5, sw_n=8, sw_buf=0.25, sl_min=1.0, sl_max=2.5,
    partial=False, partial_r=1.0, partial_frac=0.5, be_r=None, chandelier=2.5, tp_r=None,
    max_pos=3, add_if_protected=True, cooldown=2, max_trades_day=6, daily_loss_r=1.4, consec_pause=3,
    warmup=260, pb_ref="ema20", vol_min=None, flat_end=False, adx_rising=False, flat_fri=False, counter=False, c_trigger=0.6, c_vol=0.5, c_tp1=1.0, c_tp2=2.5, c_tp1_frac=0.5,
)


def run(d, p):
    idx = d.index
    o, h, l, c = d.open.values, d.high.values, d.low.values, d.close.values
    ema20, ema50, ema200 = d.ema20.values, d.ema50.values, d.ema200.values
    rsi_, atr_, adx_ = d.rsi.values, d.atr.values, d.adx.values
    hh20, ll20 = d.hh20.values, d.ll20.values
    atrr, tadx3 = d.atr_ratio.values, d.t_adx3.values
    t50, t200, tadx, tcl = d.t_ema50.values, d.t_ema200.values, d.t_adx.values, d.t_close.values
    dow, hod = idx.dayofweek.values, (idx.hour + idx.minute / 60).values
    day_id = idx.floor("D").values
    pos, trades = [], []
    last_entry_i, day_r, day_n, day_consec, cur_day = -10**9, 0.0, 0, 0, None

    def conv(price):
        return 1.0 if p["quote_usd"] else 1.0 / price

    def settle(pz, price, frac):
        qty = pz["qty"] * frac
        pnl = (price - pz["entry"]) * pz["dir"] * pz["units"] * qty * conv(price)
        pz["qty"] -= qty
        pz["pnl"] += pnl

    for i in range(p["warmup"], len(d)):
        if cur_day != day_id[i]:
            cur_day, day_r, day_n, day_consec = day_id[i], 0.0, 0, 0
        k = i - 1
        sig, mode = 0, None
        ok_time = (dow[i] in p["days"]) and (p["sess"][0] <= hod[i] < p["sess"][1])
        if ok_time and not np.isnan(atr_[k]) and not np.isnan(tadx[k]) and not np.isnan(t200[k]):
            if p["trend"] == "h4":
                up, dn_ = (t50[k] > t200[k] and tcl[k] > t200[k]), (t50[k] < t200[k] and tcl[k] < t200[k])
                strength = tadx[k]
            else:
                up, dn_ = (ema50[k] > ema200[k] and c[k] > ema200[k]), (ema50[k] < ema200[k] and c[k] < ema200[k])
                strength = adx_[k]
            vol_ok = (p["vol_min"] is None) or (not np.isnan(atrr[k]) and atrr[k] >= p["vol_min"])
            rise_ok = (not p["adx_rising"]) or (p["trend"] == "h4" and tadx[k] > tadx3[k])
            if strength >= p["adx_min"] and (up or dn_) and vol_ok and rise_ok:
                dr = 1 if up else -1
                cl = c[k]
                if "pb" in p["modes"] and dr * ema20[k] > dr * ema50[k]:
                    K, zone = p["pb_lookback"], p["pb_zone"] * atr_[k]
                    ref = ema20[k] if p["pb_ref"] == "ema20" else ema50[k]
                    if dr == 1:
                        touched = min(l[k - K + 1:k + 1]) <= ref + zone
                        resume = cl > ema20[k] and cl > o[k] and rsi_[k] > p["pb_rsi"] and rsi_[k] > rsi_[k - 1]
                    else:
                        touched = max(h[k - K + 1:k + 1]) >= ref - zone
                        resume = cl < ema20[k] and cl < o[k] and rsi_[k] < 100 - p["pb_rsi"] and rsi_[k] < rsi_[k - 1]
                    if touched and resume:
                        sig, mode = dr, "pb"
                if sig == 0 and "bo" in p["modes"]:
                    ext = abs(cl - ema20[k]) <= p["bo_ext"] * atr_[k]
                    if dr == 1 and cl > hh20[k - 1] and ext and rsi_[k] < 80 and adx_[k] >= p["bo_adx"]:
                        sig, mode = 1, "bo"
                    elif dr == -1 and cl < ll20[k - 1] and ext and rsi_[k] > 20 and adx_[k] >= p["bo_adx"]:
                        sig, mode = -1, "bo"
        if sig != 0:
            mains = [z for z in pos if not z.get("is_c")]
            same = all(z["dir"] == sig for z in mains)
            prot = all(z["be"] for z in mains) if p["add_if_protected"] else True
            blocked = (len(mains) >= p["max_pos"] or not same or (mains and not prot)
                       or i - last_entry_i < p["cooldown"] or day_n >= p["max_trades_day"]
                       or (p["daily_loss_r"] is not None and day_r <= -p["daily_loss_r"])
                       or (p["consec_pause"] is not None and day_consec >= p["consec_pause"]))
            if not blocked:
                spread = p["spread_abs"] if p["spread_abs"] else p["spread_pct"] * o[i]
                fill = o[i] + spread if sig == 1 else o[i]
                a = atr_[k]
                if p["sl_mode"] == "swing":
                    n = p["sw_n"]
                    ref = min(l[k - n + 1:k + 1]) - p["sw_buf"] * a if sig == 1 else max(h[k - n + 1:k + 1]) + p["sw_buf"] * a
                    dist = abs(fill - ref)
                    dist = min(max(dist, p["sl_min"] * a), p["sl_max"] * a)
                else:
                    dist = p["sl_atr"] * a
                units = p["risk_usd"] / (dist * conv(fill))
                pos.append(dict(dir=sig, entry=fill, sl=fill - sig * dist, r=dist, qty=1.0, pnl=0.0, be=False,
                                pdone=False, ext=fill, units=units, mode=mode, t0=idx[i]))
                last_entry_i, day_n = i, day_n + 1
        spread_b = p["spread_abs"] if p["spread_abs"] else p["spread_pct"] * o[i]
        if p["counter"]:
            for pz in list(pos):
                if pz.get("is_c") or pz.get("hedged"):
                    continue
                dr0 = pz["dir"]
                px_now = o[i] if dr0 == 1 else o[i] + spread_b
                if dr0 * (px_now - pz["entry"]) / pz["r"] <= -p["c_trigger"]:
                    cdir = -dr0
                    cfill = (o[i] + spread_b) if cdir == 1 else o[i]
                    rc = abs(pz["entry"] - cfill)
                    if rc <= 0:
                        continue
                    pos.append(dict(dir=cdir, entry=cfill, sl=pz["entry"], r=rc, qty=1.0, pnl=0.0, be=False, pdone=False, ext=cfill,
                                    units=pz["units"] * p["c_vol"], mode="counter", t0=idx[i], is_c=True,
                                    tp1=cfill + cdir * p["c_tp1"] * rc, tp2=cfill + cdir * p["c_tp2"] * rc))
                    pz["hedged"] = True
        fri_flat = p["flat_fri"] and dow[i] == 4 and hod[i] >= p["sess"][1] and hod[i - 1] < p["sess"][1]
        if pos and ((p["flat_end"] and hod[i] >= p["sess"][1] and hod[i - 1] < p["sess"][1]) or fri_flat):
            for pz in list(pos):
                settle(pz, o[i] if pz["dir"] == 1 else o[i] + spread_b, 1.0)
                trades.append(dict(t0=pz["t0"], t1=idx[i], dir=pz["dir"], mode=pz["mode"], pnl=pz["pnl"], r=pz["pnl"] / p["risk_usd"]))
                pos.remove(pz)
        for pz in list(pos):
            dr = pz["dir"]
            fav = h[i] if dr == 1 else l[i] + spread_b
            adv = l[i] if dr == 1 else h[i] + spread_b
            done = False
            if (adv <= pz["sl"]) if dr == 1 else (adv >= pz["sl"]):
                opx = o[i] if dr == 1 else o[i] + spread_b
                px = pz["sl"] if ((opx > pz["sl"]) if dr == 1 else (opx < pz["sl"])) else opx
                settle(pz, px, 1.0)
                done = True
            elif pz.get("is_c"):
                if not pz["pdone"] and ((fav >= pz["tp1"]) if dr == 1 else (fav <= pz["tp1"])):
                    settle(pz, pz["tp1"], p["c_tp1_frac"])
                    pz["pdone"], pz["sl"] = True, pz["entry"]
                if pz["pdone"] and ((fav >= pz["tp2"]) if dr == 1 else (fav <= pz["tp2"])):
                    settle(pz, pz["tp2"], 1.0)
                    done = True
            else:
                if p["tp_r"]:
                    tgt = pz["entry"] + dr * p["tp_r"] * pz["r"]
                    if (fav >= tgt) if dr == 1 else (fav <= tgt):
                        settle(pz, tgt, 1.0)
                        done = True
                if not done and p["partial"] and not pz["pdone"]:
                    tgt = pz["entry"] + dr * pz["r"] * p["partial_r"]
                    if (fav >= tgt) if dr == 1 else (fav <= tgt):
                        settle(pz, tgt, p["partial_frac"])
                        pz["pdone"], pz["sl"], pz["be"] = True, pz["entry"], True
                if not done and p["be_r"] and not pz["be"]:
                    tgt = pz["entry"] + dr * pz["r"] * p["be_r"]
                    if (fav >= tgt) if dr == 1 else (fav <= tgt):
                        pz["sl"], pz["be"] = pz["entry"], True
            if done or pz["qty"] <= 1e-9:
                day_r += pz["pnl"] / p["risk_usd"]
                day_consec = day_consec + 1 if pz["pnl"] < 0 else 0
                trades.append(dict(t0=pz["t0"], t1=idx[i], dir=dr, mode=pz["mode"], pnl=pz["pnl"], r=pz["pnl"] / p["risk_usd"]))
                pos.remove(pz)
                continue
            if pz.get("is_c"):
                continue
            pz["ext"] = max(pz["ext"], fav) if dr == 1 else min(pz["ext"], fav)
            a = atr_[i]
            if p["chandelier"] and (pz["pdone"] or not p["partial"]) and not np.isnan(a):
                ns = pz["ext"] - dr * p["chandelier"] * a
                if (dr == 1 and ns > pz["sl"]) or (dr == -1 and ns < pz["sl"]):
                    pz["sl"] = ns
            if (dr == 1 and pz["sl"] >= pz["entry"]) or (dr == -1 and pz["sl"] <= pz["entry"]):
                pz["be"] = True
    for pz in pos:
        spread_b = p["spread_abs"] if p["spread_abs"] else p["spread_pct"] * c[-1]
        settle(pz, c[-1] if pz["dir"] == 1 else c[-1] + spread_b, 1.0)
        trades.append(dict(t0=pz["t0"], t1=idx[-1], dir=pz["dir"], mode=pz["mode"], pnl=pz["pnl"], r=pz["pnl"] / p["risk_usd"]))
    return pd.DataFrame(trades)


def stats(tr, label="", span_days=None):
    if tr is None or tr.empty:
        return dict(label=label, n=0, net_R=0.0, pf=np.nan, win=np.nan, avgR=np.nan, maxdd_R=0.0, tpd=0.0)
    tr = tr.sort_values("t1")
    eq = tr.r.cumsum().values
    peak = np.maximum.accumulate(np.concatenate([[0], eq]))[1:]
    gw, gl = tr.r[tr.r > 0].sum(), -tr.r[tr.r < 0].sum()
    ad = tr.t0.dt.normalize().nunique()
    return dict(label=label, n=len(tr), win=round((tr.r > 0).mean() * 100, 1), net_R=round(tr.r.sum(), 1),
                pf=round(gw / gl, 2) if gl > 0 else np.inf, avgR=round(tr.r.mean(), 2),
                maxdd_R=round((peak - eq).max(), 1), tpd=round(len(tr) / max(ad, 1), 2))
