//+------------------------------------------------------------------+
//|                                              ConfirmedTrendEA.mq5 |
//|  v2.00  Trend-pullback EA for major forex and crypto (MT5)        |
//|                                                                    |
//|  Logic (all evaluated on closed bars):                            |
//|   1. Trend: EMA50 vs EMA200 + price on the correct side + ADX.    |
//|      Trend timeframe is an input per asset class (default H1).    |
//|   2. Volatility expansion: ATR(14) >= 1.2 x its 100-bar average.  |
//|   3. Entry (H1): pullback touches the EMA20 zone, then a bar     |
//|      closes back through EMA20 with RSI > 50 and rising.          |
//|   4. Exit: ATR stop, ATR chandelier trail (no fixed target).      |
//|   5. Schedule in Malaysia time; account-wide risk governors.      |
//|                                                                    |
//|  Evidence and limits: see MANUAL.md and research/RESULTS.md.      |
//|  Crypto showed a modest edge on unseen data; the forex result is  |
//|  inconclusive out of sample. No result is a promise of profit.    |
//+------------------------------------------------------------------+
#property copyright "Andrew"
#property version   "2.00"
#property description "Trend-pullback EA with volatility-expansion filter for major forex and crypto"

#include <Trade\Trade.mqh>

enum ENUM_LOT_MODE      { LOT_FIXED = 0, LOT_RISK_PERCENT = 1 };
enum ENUM_TARGET_SCOPE  { TARGET_SINCE_START = 0, TARGET_DAILY = 1 };
enum ENUM_ASSET_CLASS   { ASSET_AUTO = 0, ASSET_FOREX = 1, ASSET_CRYPTO = 2, ASSET_NONE = 3 };

input group "=== Position sizing & risk ==="
input ENUM_LOT_MODE InpLotMode            = LOT_FIXED;
input double InpFixedLot                  = 0.02;     // used when LOT_FIXED
input double InpRiskPercent               = 2.0;      // used when LOT_RISK_PERCENT (% of balance)
input double InpMaxRiskPerTradePct        = 5.0;      // hard cap: loss at stop-loss as % of balance
input double InpMaxOpenRiskPct            = 10.0;     // cap on summed loss-at-SL of unprotected positions (% of equity)
input double InpMaxMarginUsePct           = 50.0;     // new trade margin <= this % of free margin
input int    InpMaxPositionsPerSymbol     = 2;        // hedging accounts only; netting forces 1
input int    InpMaxPositionsTotal         = 4;        // all symbols using this magic number
input int    InpMaxEntriesPerDay          = 6;        // account-wide, Malaysia day
input double InpDailyLossPct              = 8.0;      // no new entries once the day is down this % of start-of-day balance
input int    InpPauseAfterLosses          = 3;        // consecutive losing closes today -> pause until tomorrow (0 = off)
input ulong  InpMagicNumber               = 20260928;

input group "=== Profit target ==="
input double InpProfitTargetUSD           = 75.0;
input ENUM_TARGET_SCOPE InpTargetScope    = TARGET_SINCE_START;
input bool   InpStopAtProfitTarget        = true;
input bool   InpCloseAllAtTarget          = true;
input bool   InpResetBaseline             = false;    // true: re-take the since-start baseline from the current balance (set back to false afterwards)

input group "=== Instruments & schedule (Malaysia time, GMT+8) ==="
input ENUM_ASSET_CLASS InpAssetOverride   = ASSET_AUTO;
input bool   InpAllowForex                = true;
input bool   InpAllowCrypto               = true;
input double InpBrokerGMTOffset           = 2.0;      // broker server clock offset from GMT, hours
input bool   InpAutoGMTOffset             = false;    // live only: derive the offset from TimeTradeServer() - TimeGMT()
input int    InpSessionStartHour          = 15;
input int    InpSessionStartMinute        = 30;
input int    InpSessionEndHour            = 23;
input int    InpSessionEndMinute          = 0;
input bool   InpTradeMonday               = false;    // forex day filters (Malaysia days)
input bool   InpTradeTuesday              = true;
input bool   InpTradeWednesday            = true;
input bool   InpTradeThursday             = true;
input bool   InpTradeFriday               = false;
input bool   InpCryptoAllDays             = true;     // crypto ignores the day filters above

input group "=== Trend filter ==="
input ENUM_TIMEFRAMES InpForexTrendTF     = PERIOD_H1;
input ENUM_TIMEFRAMES InpCryptoTrendTF    = PERIOD_H1;
input int    InpTrendFastEMA              = 50;
input int    InpTrendSlowEMA              = 200;
input int    InpADXPeriod                 = 14;
input double InpADXMin                    = 20.0;

input group "=== Entry (pullback resume) ==="
input ENUM_TIMEFRAMES InpEntryTF          = PERIOD_H1;
input int    InpEntryFastEMA              = 20;
input int    InpEntryMidEMA               = 50;
input int    InpRSIPeriod                 = 14;
input double InpRSIGate                   = 50.0;
input int    InpPullbackLookback          = 6;
input double InpPullbackZoneATR           = 0.25;
input int    InpATRPeriod                 = 14;
input int    InpVolLookback               = 100;
input double InpMinVolRatio               = 1.2;      // ATR / average ATR; 0 disables the filter
input int    InpCooldownBars              = 2;        // min bars between entries on a symbol
input double InpMaxSpreadPctATR           = 20.0;     // skip while spread exceeds this % of ATR

input group "=== Exit ==="
input double InpSLATR                     = 1.5;
input double InpTrailATR                  = 3.0;      // chandelier distance, 0 = no trailing
input double InpTPR                       = 0.0;      // optional fixed target in R multiples, 0 = none

input group "=== Diagnostics ==="
input bool   InpVerbose                   = false;

CTrade   trade;

int      hTrF = INVALID_HANDLE, hTrS = INVALID_HANDLE, hTrADX = INVALID_HANDLE;
int      hEF = INVALID_HANDLE, hEM = INVALID_HANDLE, hRSI = INVALID_HANDLE, hATR = INVALID_HANDLE;

ENUM_ASSET_CLASS gClass = ASSET_NONE;
ENUM_TIMEFRAMES  gTrendTF = PERIOD_H4;
int      gMaxPosSym = 1;
double   gBaseline = 0.0;
string   gBaseKey = "";

datetime gBarTime = 0;
datetime gLastEntryBar = 0;
int      gSig = 0;
bool     gSigDone = true;
double   gSigATR = 0.0;

uint     gStatsTick = 0;
double   gDayRealized = 0.0;
int      gDayEntries = 0;
int      gDayConsec = 0;
string   gLastMsg = "";

string gMajors[]  = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD"};
string gCrypto[]  = {"BTC","ETH","LTC","XRP","SOL","BNB","DOGE","ADA","DOT","LINK","AVAX","MATIC","TRX","BCH","XLM","UNI","ATOM","ETC","BITCOIN"};

struct PosStats
  {
   int  sym;
   int  total;
   int  dir;
   bool allProtected;
  };

//+------------------------------------------------------------------+
void Verbose(const string msg)
  {
   if(InpVerbose && msg != gLastMsg)
     {
      Print("ConfirmedTrendEA: ", msg);
      gLastMsg = msg;
     }
  }

//+------------------------------------------------------------------+
ENUM_ASSET_CLASS DetectClass(const string sym)
  {
   if(InpAssetOverride != ASSET_AUTO)
      return InpAssetOverride;
   string s = sym;
   StringToUpper(s);
   for(int i = 0; i < ArraySize(gMajors); i++)
      if(StringFind(s, gMajors[i]) == 0)
         return ASSET_FOREX;
   for(int j = 0; j < ArraySize(gCrypto); j++)
      if(StringFind(s, gCrypto[j]) == 0)
         return ASSET_CRYPTO;
   return ASSET_NONE;
  }

//+------------------------------------------------------------------+
double GmtOffset()
  {
   if(InpAutoGMTOffset && !MQLInfoInteger(MQL_TESTER))
     {
      double diff = (double)((long)TimeTradeServer() - (long)TimeGMT());
      return MathRound(diff / 1800.0) * 0.5;
     }
   return InpBrokerGMTOffset;
  }

long ShiftToMYT()
  {
   return (long)((8.0 - GmtOffset()) * 3600.0);
  }

datetime ToMYT(const datetime serverTime)
  {
   return (datetime)((long)serverTime + ShiftToMYT());
  }

datetime MalaysiaDayStartServer()
  {
   long shift = ShiftToMYT();
   long my    = (long)TimeCurrent() + shift;
   long mid   = my - (my % 86400);
   return (datetime)(mid - shift);
  }

//+------------------------------------------------------------------+
bool InSessionAt(const datetime serverTime)
  {
   MqlDateTime t;
   TimeToStruct(ToMYT(serverTime), t);

   bool dayOk = false;
   if(gClass == ASSET_CRYPTO && InpCryptoAllDays)
      dayOk = true;
   else
     {
      switch(t.day_of_week)
        {
         case 1:  dayOk = InpTradeMonday;    break;
         case 2:  dayOk = InpTradeTuesday;   break;
         case 3:  dayOk = InpTradeWednesday; break;
         case 4:  dayOk = InpTradeThursday;  break;
         case 5:  dayOk = InpTradeFriday;    break;
         default: dayOk = false;
        }
     }
   if(!dayOk)
      return false;

   int nowM = t.hour * 60 + t.min;
   int st   = InpSessionStartHour * 60 + InpSessionStartMinute;
   int en   = InpSessionEndHour * 60 + InpSessionEndMinute;
   if(st <= en)
      return (nowM >= st && nowM < en);
   return (nowM >= st || nowM < en);
  }

//+------------------------------------------------------------------+
bool IsProtected(const long type, const double open, const double sl)
  {
   if(sl <= 0.0)
      return false;
   if(type == POSITION_TYPE_BUY)
      return (sl >= open);
   return (sl <= open);
  }

void GetPosStats(PosStats &s)
  {
   s.sym = 0;
   s.total = 0;
   s.dir = 0;
   s.allProtected = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      s.total++;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      s.sym++;
      long type = PositionGetInteger(POSITION_TYPE);
      int d = (type == POSITION_TYPE_BUY) ? 1 : -1;
      if(s.dir == 0)
         s.dir = d;
      else if(s.dir != d)
         s.dir = 2;
      if(!IsProtected(type, PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_SL)))
         s.allProtected = false;
     }
  }

double FloatingPL()
  {
   double pl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return pl;
  }

double OpenRiskMoney()
  {
   double risk = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
         return AccountInfoDouble(ACCOUNT_EQUITY);
      if(IsProtected(type, open, sl))
         continue;
      double p = 0.0;
      ENUM_ORDER_TYPE ot = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OrderCalcProfit(ot, PositionGetString(POSITION_SYMBOL), PositionGetDouble(POSITION_VOLUME), open, sl, p) && p < 0.0)
         risk += -p;
     }
   return risk;
  }

void CloseMyPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      trade.PositionClose(tk);
     }
  }

//+------------------------------------------------------------------+
void RefreshDayStats(const bool force)
  {
   uint nowTick = GetTickCount();
   if(!force && gStatsTick != 0 && (nowTick - gStatsTick) < 5000)
      return;
   gStatsTick = nowTick;

   gDayRealized = 0.0;
   gDayEntries  = 0;
   gDayConsec   = 0;
   if(!HistorySelect(MalaysiaDayStartServer(), TimeCurrent() + 86400))
      return;

   int streak = 0;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagicNumber)
         continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
        {
         gDayEntries++;
         gDayRealized += HistoryDealGetDouble(tk, DEAL_COMMISSION);
         continue;
        }
      double pl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP)
                  + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      gDayRealized += pl;
      if(pl < 0.0)
         streak++;
      else if(pl > 0.0)
         streak = 0;
     }
   gDayConsec = streak;
  }

//+------------------------------------------------------------------+
bool ProfitTargetHalt()
  {
   if(!InpStopAtProfitTarget || InpProfitTargetUSD <= 0.0)
      return false;

   double profit;
   if(InpTargetScope == TARGET_SINCE_START)
      profit = AccountInfoDouble(ACCOUNT_EQUITY) - gBaseline;
   else
     {
      RefreshDayStats(false);
      profit = gDayRealized + FloatingPL();
     }
   if(profit < InpProfitTargetUSD)
      return false;

   if(InpCloseAllAtTarget)
      CloseMyPositions();
   Verbose(StringFormat("profit target %.2f reached (%.2f); no new entries", InpProfitTargetUSD, profit));
   return true;
  }

//+------------------------------------------------------------------+
int TrendDirection()
  {
   double f[], s[], a[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(s, true);
   ArraySetAsSeries(a, true);
   if(CopyBuffer(hTrF, 0, 0, 3, f) < 3)
      return 0;
   if(CopyBuffer(hTrS, 0, 0, 3, s) < 3)
      return 0;
   if(CopyBuffer(hTrADX, 0, 0, 3, a) < 3)
      return 0;
   double c = iClose(_Symbol, gTrendTF, 1);
   if(c <= 0.0 || a[1] < InpADXMin)
      return 0;
   if(f[1] > s[1] && c > s[1])
      return 1;
   if(f[1] < s[1] && c < s[1])
      return -1;
   return 0;
  }

double VolRatio()
  {
   if(InpMinVolRatio <= 0.0)
      return 1.0e9;
   double a[];
   ArraySetAsSeries(a, true);
   int n = InpVolLookback;
   if(n < 2 || CopyBuffer(hATR, 0, 1, n, a) < n)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += a[i];
   double avg = sum / n;
   if(avg <= 0.0)
      return 0.0;
   return a[0] / avg;
  }

void ComputeSignal()
  {
   gSig = 0;
   gSigDone = true;

   if(!(gClass == ASSET_FOREX ? InpAllowForex : InpAllowCrypto))
      return;
   if(!InSessionAt(gBarTime))
      return;

   int dir = TrendDirection();
   if(dir == 0)
      return;
   if(VolRatio() < InpMinVolRatio)
      return;

   double e20[], e50[], rs[], at[];
   ArraySetAsSeries(e20, true);
   ArraySetAsSeries(e50, true);
   ArraySetAsSeries(rs, true);
   ArraySetAsSeries(at, true);
   if(CopyBuffer(hEF, 0, 0, 3, e20) < 3)
      return;
   if(CopyBuffer(hEM, 0, 0, 3, e50) < 3)
      return;
   if(CopyBuffer(hRSI, 0, 0, 3, rs) < 3)
      return;
   if(CopyBuffer(hATR, 0, 0, 3, at) < 3)
      return;
   if(at[1] <= 0.0)
      return;

   double o1 = iOpen(_Symbol, InpEntryTF, 1);
   double c1 = iClose(_Symbol, InpEntryTF, 1);
   double zone = InpPullbackZoneATR * at[1];

   if(dir == 1)
     {
      if(!(e20[1] > e50[1]))
         return;
      double lo = DBL_MAX;
      for(int k = 1; k <= InpPullbackLookback; k++)
         lo = MathMin(lo, iLow(_Symbol, InpEntryTF, k));
      bool touched = (lo <= e20[1] + zone);
      bool resume  = (c1 > e20[1] && c1 > o1 && rs[1] > InpRSIGate && rs[1] > rs[2]);
      if(touched && resume)
         gSig = 1;
     }
   else
     {
      if(!(e20[1] < e50[1]))
         return;
      double hi = 0.0;
      for(int k = 1; k <= InpPullbackLookback; k++)
         hi = MathMax(hi, iHigh(_Symbol, InpEntryTF, k));
      bool touched = (hi >= e20[1] - zone);
      bool resume  = (c1 < e20[1] && c1 < o1 && rs[1] < 100.0 - InpRSIGate && rs[1] < rs[2]);
      if(touched && resume)
         gSig = -1;
     }

   if(gSig != 0)
     {
      gSigDone = false;
      gSigATR  = at[1];
     }
  }

//+------------------------------------------------------------------+
bool EntryAllowed(string &why)
  {
   PosStats ps;
   GetPosStats(ps);
   if(ps.sym >= gMaxPosSym)
     {
      why = "max positions on symbol";
      return false;
     }
   if(ps.total >= InpMaxPositionsTotal)
     {
      why = "max positions in total";
      return false;
     }
   if(ps.sym > 0 && (ps.dir != gSig || !ps.allProtected))
     {
      why = "add-on needs same direction and protected positions";
      return false;
     }

   RefreshDayStats(false);
   if(gDayEntries >= InpMaxEntriesPerDay)
     {
      why = "max entries today";
      return false;
     }
   double dayStartBal = AccountInfoDouble(ACCOUNT_BALANCE) - gDayRealized;
   double dayPL = gDayRealized + FloatingPL();
   if(dayStartBal > 0.0 && dayPL <= -dayStartBal * InpDailyLossPct / 100.0)
     {
      why = "daily loss limit";
      return false;
     }
   if(InpPauseAfterLosses > 0 && gDayConsec >= InpPauseAfterLosses)
     {
      why = "paused after consecutive losses";
      return false;
     }
   if(gLastEntryBar != 0)
     {
      int sh = iBarShift(_Symbol, InpEntryTF, gLastEntryBar, false);
      if(sh >= 0 && sh < InpCooldownBars)
        {
         why = "cooldown";
         return false;
        }
     }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     {
      why = "trading disabled for symbol";
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
double ComputeLots(const ENUM_ORDER_TYPE type, const double entry, const double sl, string &why)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double p1 = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, p1) || p1 >= 0.0)
     {
      why = "cannot estimate loss per lot";
      return 0.0;
     }
   double lossPerLot = -p1;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0 || minLot <= 0.0)
     {
      why = "bad volume specification";
      return 0.0;
     }

   double lots = (InpLotMode == LOT_FIXED) ? InpFixedLot : (balance * InpRiskPercent / 100.0) / lossPerLot;
   double capMoney = balance * InpMaxRiskPerTradePct / 100.0;
   double capLots  = capMoney / lossPerLot;
   if(lots > capLots)
      lots = capLots;
   lots = MathMin(lots, maxLot);
   lots = MathFloor(lots / step + 1.0e-9) * step;

   if(lots < minLot - 1.0e-12)
     {
      if(InpLotMode == LOT_RISK_PERCENT && minLot * lossPerLot <= capMoney)
         lots = minLot;
      else
        {
         why = "risk cap is below the minimum lot";
         return 0.0;
        }
     }

   double margin = 0.0;
   if(OrderCalcMargin(type, _Symbol, lots, entry, margin) && margin > 0.0)
     {
      double allowed = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * InpMaxMarginUsePct / 100.0;
      if(margin > allowed)
        {
         lots = MathFloor(lots * allowed / margin / step + 1.0e-9) * step;
         if(lots < minLot - 1.0e-12)
           {
            why = "not enough free margin";
            return 0.0;
           }
        }
     }
   return NormalizeDouble(lots, 8);
  }

//+------------------------------------------------------------------+
void TryExecuteSignal()
  {
   string why = "";
   if(!EntryAllowed(why))
     {
      Verbose(why);
      gSigDone = true;
      return;
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;
   if((ask - bid) > InpMaxSpreadPctATR / 100.0 * gSigATR)
     {
      Verbose("spread too wide, waiting");
      return;
     }

   double slDist   = InpSLATR * gSigATR;
   double stopsLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopsLvl > 0.0 && slDist < stopsLvl * 1.2)
      slDist = stopsLvl * 1.2;

   ENUM_ORDER_TYPE ot = (gSig == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entry = (gSig == 1) ? ask : bid;
   double sl = NormalizeDouble((gSig == 1) ? entry - slDist : entry + slDist, _Digits);
   double tp = 0.0;
   if(InpTPR > 0.0)
      tp = NormalizeDouble((gSig == 1) ? entry + InpTPR * slDist : entry - InpTPR * slDist, _Digits);

   double lots = ComputeLots(ot, entry, sl, why);
   if(lots <= 0.0)
     {
      Verbose(why);
      gSigDone = true;
      return;
     }

   double p = 0.0;
   double newRisk = 0.0;
   if(OrderCalcProfit(ot, _Symbol, lots, entry, sl, p) && p < 0.0)
      newRisk = -p;
   if(OpenRiskMoney() + newRisk > AccountInfoDouble(ACCOUNT_EQUITY) * InpMaxOpenRiskPct / 100.0)
     {
      Verbose("open-risk cap");
      gSigDone = true;
      return;
     }

   trade.SetDeviationInPoints((ulong)MathMax(10.0, 0.05 * slDist / _Point));
   bool ok = (gSig == 1) ? trade.Buy(lots, _Symbol, 0.0, sl, tp, "CTE2")
                         : trade.Sell(lots, _Symbol, 0.0, sl, tp, "CTE2");
   gSigDone = true;
   if(ok)
     {
      gLastEntryBar = gBarTime;
      RefreshDayStats(true);
     }
   else
      Print("ConfirmedTrendEA: order failed, retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   if(InpTrailATR <= 0.0)
      return;
   double at[];
   ArraySetAsSeries(at, true);
   if(CopyBuffer(hATR, 0, 0, 3, at) < 3 || at[1] <= 0.0)
      return;

   double stopsLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      int shift = iBarShift(_Symbol, InpEntryTF, (datetime)PositionGetInteger(POSITION_TIME), false);
      if(shift < 1)
         continue;

      if(type == POSITION_TYPE_BUY)
        {
         int idx = iHighest(_Symbol, InpEntryTF, MODE_HIGH, shift, 1);
         if(idx < 0)
            continue;
         double ext   = MathMax(iHigh(_Symbol, InpEntryTF, idx), open);
         double newSL = NormalizeDouble(ext - InpTrailATR * at[1], _Digits);
         if((sl <= 0.0 || newSL > sl + _Point * 0.5) && newSL < bid - stopsLvl)
            trade.PositionModify(tk, newSL, tp);
        }
      else
        {
         int idx = iLowest(_Symbol, InpEntryTF, MODE_LOW, shift, 1);
         if(idx < 0)
            continue;
         double ext   = MathMin(iLow(_Symbol, InpEntryTF, idx), open);
         double newSL = NormalizeDouble(ext + spread + InpTrailATR * at[1], _Digits);
         if((sl <= 0.0 || newSL < sl - _Point * 0.5) && newSL > ask + stopsLvl)
            trade.PositionModify(tk, newSL, tp);
        }
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   gClass = DetectClass(_Symbol);
   if(gClass == ASSET_NONE)
     {
      Print("ConfirmedTrendEA: ", _Symbol, " is not a recognised major forex pair or crypto symbol. Set InpAssetOverride to use it anyway.");
      return INIT_FAILED;
     }
   gTrendTF = (gClass == ASSET_CRYPTO) ? InpCryptoTrendTF : InpForexTrendTF;

   bool hedging = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   gMaxPosSym = hedging ? MathMax(1, InpMaxPositionsPerSymbol) : 1;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);

   hTrF   = iMA(_Symbol, gTrendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrS   = iMA(_Symbol, gTrendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrADX = iADX(_Symbol, gTrendTF, InpADXPeriod);
   hEF    = iMA(_Symbol, InpEntryTF, InpEntryFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hEM    = iMA(_Symbol, InpEntryTF, InpEntryMidEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI   = iRSI(_Symbol, InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
   hATR   = iATR(_Symbol, InpEntryTF, InpATRPeriod);
   if(hTrF == INVALID_HANDLE || hTrS == INVALID_HANDLE || hTrADX == INVALID_HANDLE ||
      hEF == INVALID_HANDLE || hEM == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Print("ConfirmedTrendEA: failed to create indicator handles");
      return INIT_FAILED;
     }

   gBaseKey = "CTE_BASE_" + (string)InpMagicNumber;
   if(MQLInfoInteger(MQL_TESTER) || InpResetBaseline || !GlobalVariableCheck(gBaseKey))
      GlobalVariableSet(gBaseKey, AccountInfoDouble(ACCOUNT_BALANCE));
   gBaseline = GlobalVariableGet(gBaseKey);

   gBarTime = 0;
   gLastEntryBar = 0;
   gSig = 0;
   gSigDone = true;

   PrintFormat("ConfirmedTrendEA v2: %s as %s | trend TF %s | entry TF %s | max positions per symbol %d | GMT offset %.1f",
               _Symbol, (gClass == ASSET_CRYPTO ? "crypto" : "forex"), EnumToString(gTrendTF),
               EnumToString(InpEntryTF), gMaxPosSym, GmtOffset());
   if(InpLotMode == LOT_FIXED && AccountInfoDouble(ACCOUNT_BALANCE) < 200.0)
      Print("ConfirmedTrendEA: small balance with fixed lots - the per-trade risk cap (", InpMaxRiskPerTradePct,
            "%) will shrink or skip trades whose stop would risk more than that.");
   return INIT_SUCCEEDED;
  }

void ReleaseHandle(int &h)
  {
   if(h != INVALID_HANDLE)
      IndicatorRelease(h);
   h = INVALID_HANDLE;
  }

void OnDeinit(const int reason)
  {
   ReleaseHandle(hTrF);
   ReleaseHandle(hTrS);
   ReleaseHandle(hTrADX);
   ReleaseHandle(hEF);
   ReleaseHandle(hEM);
   ReleaseHandle(hRSI);
   ReleaseHandle(hATR);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   bool halted = ProfitTargetHalt();

   datetime bt = iTime(_Symbol, InpEntryTF, 0);
   if(bt == 0)
      return;
   if(bt != gBarTime)
     {
      gBarTime = bt;
      ManageOpenPositions();
      if(halted)
        {
         gSig = 0;
         gSigDone = true;
        }
      else
         ComputeSignal();
     }
   if(!halted && gSig != 0 && !gSigDone)
      TryExecuteSignal();
  }
//+------------------------------------------------------------------+
