//+------------------------------------------------------------------+
//|                                              ConfirmedTrendEA.mq5 |
//|  v2.20  Multi-symbol trend-pullback EA for major forex and crypto |
//|         with on-chart dashboard and optional counter-trade        |
//|                                                                    |
//|  Attach ONE instance to any chart. It trades every symbol listed  |
//|  in InpSymbols (default: 7 forex majors + BTC, ETH, XRP).         |
//|                                                                    |
//|  Logic per symbol (closed bars only):                             |
//|   1. Trend: EMA50 vs EMA200 + price on the correct side + ADX.    |
//|   2. Volatility expansion: ATR(14) >= 1.2 x its 100-bar average.  |
//|   3. Entry (H1): pullback touches the EMA20 zone, then a bar     |
//|      closes back through EMA20 with RSI > 50 and rising.          |
//|   4. Exit: ATR stop, ATR chandelier trail (no fixed target).      |
//|   5. Schedule in Malaysia time; account-wide risk governors.      |
//|                                                                    |
//|  Optional counter-trade (hedging accounts, OFF by default): when  |
//|  a position is down InpCounterTriggerR, open an opposite trade    |
//|  with TP1 (50% closed, stop to break-even) and TP2. Testing found |
//|  it neutral-to-negative, so it is off unless you enable it.       |
//|                                                                    |
//|  Evidence and limits: see MANUAL.md and research/RESULTS.md.      |
//|  Crypto showed a modest edge on unseen data; the forex result is  |
//|  inconclusive out of sample. No result is a promise of profit.    |
//+------------------------------------------------------------------+
#property copyright "Andrew"
#property version   "2.20"
#property description "Multi-symbol trend-pullback EA with dashboard for major forex and crypto"

#include <Trade\Trade.mqh>

enum ENUM_LOT_MODE      { LOT_FIXED = 0, LOT_RISK_PERCENT = 1 };
enum ENUM_TARGET_SCOPE  { TARGET_SINCE_START = 0, TARGET_DAILY = 1 };
enum ENUM_ASSET_CLASS   { ASSET_NONE = 0, ASSET_FOREX = 1, ASSET_CRYPTO = 2 };
enum ENUM_UNKNOWN_CLASS { UNKNOWN_SKIP = 0, UNKNOWN_AS_FOREX = 1, UNKNOWN_AS_CRYPTO = 2 };

input group "=== Symbols ==="
input string InpSymbols                   = "EURUSD,GBPUSD,USDJPY,USDCHF,AUDUSD,USDCAD,NZDUSD,BTCUSD,ETHUSD,XRPUSD"; // comma separated; empty = chart symbol only
input string InpSymbolSuffix              = "";       // appended to every name, e.g. ".a" or "m"
input ENUM_UNKNOWN_CLASS InpUnknownSymbols = UNKNOWN_SKIP; // how to treat names that are not recognised forex majors or crypto

input group "=== Position sizing & risk ==="
input ENUM_LOT_MODE InpLotMode            = LOT_FIXED;
input double InpFixedLot                  = 0.02;     // used when LOT_FIXED
input double InpRiskPercent               = 2.0;      // used when LOT_RISK_PERCENT (% of balance)
input double InpMaxRiskPerTradePct        = 5.0;      // hard cap: loss at stop-loss as % of balance
input double InpMaxOpenRiskPct            = 10.0;     // cap on summed loss-at-SL of unprotected positions (% of equity)
input double InpMaxMarginUsePct           = 50.0;     // new trade margin <= this % of free margin
input int    InpMaxPositionsPerSymbol     = 2;        // hedging accounts only; netting forces 1
input int    InpMaxPositionsTotal         = 4;        // main positions, all symbols using this magic number
input int    InpMaxEntriesPerDay          = 6;        // account-wide, Malaysia day (counter-trades not counted)
input double InpDailyLossPct              = 8.0;      // no new entries once the day is down this % of start-of-day balance
input int    InpPauseAfterLosses          = 3;        // consecutive losing closes today -> pause until tomorrow (0 = off)
input ulong  InpMagicNumber               = 20260928;

input group "=== Counter-trade (hedging accounts only) ==="
input bool   InpCounterEnabled            = false;    // OFF by default: neutral-to-negative in testing
input double InpCounterTriggerR           = 0.6;      // open when a position is down this many R (R = its initial stop distance)
input double InpCounterVolPct             = 50.0;     // counter size as % of the losing position (max 100)
input double InpCounterTP1R               = 1.0;      // TP1 in multiples of the counter's own stop distance
input double InpCounterTP2R               = 2.5;      // TP2 (final target) in the same units
input double InpCounterTP1Pct             = 50.0;     // % of the counter closed at TP1, then its stop moves to break-even

input group "=== Profit target ==="
input double InpProfitTargetUSD           = 75.0;
input ENUM_TARGET_SCOPE InpTargetScope    = TARGET_SINCE_START;
input bool   InpStopAtProfitTarget        = true;
input bool   InpCloseAllAtTarget          = true;
input bool   InpResetBaseline             = false;    // true: re-take the since-start baseline from the current balance (set back to false afterwards)

input group "=== Schedule (Malaysia time, GMT+8) ==="
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

input group "=== Dashboard ==="
input bool   InpShowDashboard             = true;
input int    InpDashX                     = 10;
input int    InpDashY                     = 20;
input int    InpDashFont                  = 9;
input bool   InpDashDark                  = true;
input int    InpDashPositionRows          = 6;
input bool   InpShowCalendar              = true;     // MT5 economic calendar (live terminal only)
input int    InpCalendarRows              = 5;
input int    InpCalendarHours             = 72;

input group "=== Diagnostics ==="
input bool   InpVerbose                   = false;

CTrade   trade;

struct SymState
  {
   string           sym;
   ENUM_ASSET_CLASS cls;
   ENUM_TIMEFRAMES  trendTF;
   int              hTrF;
   int              hTrS;
   int              hTrADX;
   int              hEF;
   int              hEM;
   int              hRSI;
   int              hATR;
   int              dh[8];
   datetime         barTime;
   datetime         lastEntryBar;
   int              sig;
   bool             sigDone;
   double           sigATR;
   int              dirT;
   double           vol;
   double           atr;
   string           state;
   string           lastMsg;
   bool             ready;
  };

struct PosStats
  {
   int  sym;
   int  total;
   int  counters;
   int  dir;
   bool allProtected;
  };

SymState gS[];
bool     gHedging = false;
int      gMaxPosSym = 1;
double   gBaseline = 0.0;
string   gBaseKey = "";
string   gLockKey = "";
uint     gBeatTick = 0;
uint     gHaltMsgTick = 0;

uint     gStatsTick = 0;
double   gDayRealized = 0.0;
int      gDayEntries = 0;
int      gDayConsec = 0;

ENUM_TIMEFRAMES gDashTF[4] = {PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
string   gDashTFName[4]    = {"M15", "H1", "H4", "D1"};

uint     gCalTick = 0;
int      gCalCount = 0;
bool     gCalOk = false;
datetime gEvT[64];
string   gEvC[64];
string   gEvN[64];

string gMajors[]  = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD"};
string gCrypto[]  = {"BTC","ETH","LTC","XRP","SOL","BNB","DOGE","ADA","DOT","LINK","AVAX","MATIC","TRX","BCH","XLM","UNI","ATOM","ETC","BITCOIN"};

#define DASH_PREFIX "CTE_D_"
#define TAG_MAIN    "CTE2R"
#define TAG_COUNTER "CTE2C"

//+------------------------------------------------------------------+
void VerboseS(SymState &s, const string msg)
  {
   if(InpVerbose && msg != s.lastMsg)
     {
      Print("ConfirmedTrendEA ", s.sym, ": ", msg);
      s.lastMsg = msg;
     }
  }

//+------------------------------------------------------------------+
ENUM_ASSET_CLASS DetectClass(const string sym)
  {
   string s = sym;
   StringToUpper(s);
   for(int i = 0; i < ArraySize(gMajors); i++)
      if(StringFind(s, gMajors[i]) == 0)
         return ASSET_FOREX;
   for(int j = 0; j < ArraySize(gCrypto); j++)
      if(StringFind(s, gCrypto[j]) == 0)
         return ASSET_CRYPTO;
   if(InpUnknownSymbols == UNKNOWN_AS_FOREX)
      return ASSET_FOREX;
   if(InpUnknownSymbols == UNKNOWN_AS_CRYPTO)
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
bool InSessionAt(const datetime serverTime, const ENUM_ASSET_CLASS cls)
  {
   MqlDateTime t;
   TimeToStruct(ToMYT(serverTime), t);

   bool dayOk = false;
   if(cls == ASSET_CRYPTO && InpCryptoAllDays)
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

// the selected position (PositionGetTicket) is a counter-trade
bool SelectedIsCounter()
  {
   return (StringFind(PositionGetString(POSITION_COMMENT), TAG_COUNTER) == 0);
  }

// initial stop distance stored in a main position's comment, 0 if none
double SelectedMainRisk()
  {
   string c = PositionGetString(POSITION_COMMENT);
   if(StringFind(c, TAG_MAIN) != 0)
      return 0.0;
   return StringToDouble(StringSubstr(c, StringLen(TAG_MAIN)));
  }

void GetPosStats(PosStats &s, const string sym)
  {
   s.sym = 0;
   s.total = 0;
   s.counters = 0;
   s.dir = 0;
   s.allProtected = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(SelectedIsCounter())
        {
         s.counters++;
         continue;
        }
      s.total++;
      if(PositionGetString(POSITION_SYMBOL) != sym)
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
         if(StringFind(HistoryDealGetString(tk, DEAL_COMMENT), TAG_COUNTER) != 0)
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
double TargetProfit()
  {
   if(InpTargetScope == TARGET_SINCE_START)
      return AccountInfoDouble(ACCOUNT_EQUITY) - gBaseline;
   RefreshDayStats(false);
   return gDayRealized + FloatingPL();
  }

bool ProfitTargetHalt()
  {
   if(!InpStopAtProfitTarget || InpProfitTargetUSD <= 0.0)
      return false;
   double profit = TargetProfit();
   if(profit < InpProfitTargetUSD)
      return false;

   if(InpCloseAllAtTarget)
      CloseMyPositions();
   uint nowTick = GetTickCount();
   if(gHaltMsgTick == 0 || (nowTick - gHaltMsgTick) > 3600000)
     {
      gHaltMsgTick = nowTick;
      PrintFormat("ConfirmedTrendEA: profit target %.2f reached (%.2f); no new entries", InpProfitTargetUSD, profit);
     }
   return true;
  }

//+------------------------------------------------------------------+
int TrendDirection(SymState &s)
  {
   double f[], sl[], a[];
   ArraySetAsSeries(f, true);
   ArraySetAsSeries(sl, true);
   ArraySetAsSeries(a, true);
   if(CopyBuffer(s.hTrF, 0, 0, 3, f) < 3)
      return 0;
   if(CopyBuffer(s.hTrS, 0, 0, 3, sl) < 3)
      return 0;
   if(CopyBuffer(s.hTrADX, 0, 0, 3, a) < 3)
      return 0;
   double c = iClose(s.sym, s.trendTF, 1);
   if(c <= 0.0 || a[1] < InpADXMin)
      return 0;
   if(f[1] > sl[1] && c > sl[1])
      return 1;
   if(f[1] < sl[1] && c < sl[1])
      return -1;
   return 0;
  }

double VolRatio(SymState &s)
  {
   if(InpMinVolRatio <= 0.0)
      return 1.0e9;
   double a[];
   ArraySetAsSeries(a, true);
   int n = InpVolLookback;
   if(n < 2 || CopyBuffer(s.hATR, 0, 1, n, a) < n)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += a[i];
   double avg = sum / n;
   if(avg <= 0.0)
      return 0.0;
   return a[0] / avg;
  }

void ComputeSignal(SymState &s)
  {
   s.sig = 0;
   s.sigDone = true;

   s.dirT = TrendDirection(s);
   s.vol  = VolRatio(s);
   double atrNow[];
   ArraySetAsSeries(atrNow, true);
   if(CopyBuffer(s.hATR, 0, 0, 3, atrNow) >= 3 && atrNow[1] > 0.0)
      s.atr = atrNow[1];

   if(!(s.cls == ASSET_FOREX ? InpAllowForex : InpAllowCrypto))
     {
      s.state = "DISABLED";
      return;
     }
   if(!InSessionAt(s.barTime, s.cls))
     {
      s.state = "OUT OF SESSION";
      return;
     }
   if(s.dirT == 0)
     {
      s.state = "NO TREND";
      return;
     }
   if(s.vol < InpMinVolRatio)
     {
      s.state = "LOW VOLATILITY";
      return;
     }

   double e20[], e50[], rs[], at[];
   ArraySetAsSeries(e20, true);
   ArraySetAsSeries(e50, true);
   ArraySetAsSeries(rs, true);
   ArraySetAsSeries(at, true);
   if(CopyBuffer(s.hEF, 0, 0, 3, e20) < 3)
      return;
   if(CopyBuffer(s.hEM, 0, 0, 3, e50) < 3)
      return;
   if(CopyBuffer(s.hRSI, 0, 0, 3, rs) < 3)
      return;
   if(CopyBuffer(s.hATR, 0, 0, 3, at) < 3)
      return;
   if(at[1] <= 0.0)
      return;
   s.atr = at[1];

   double o1 = iOpen(s.sym, InpEntryTF, 1);
   double c1 = iClose(s.sym, InpEntryTF, 1);
   double zone = InpPullbackZoneATR * at[1];
   s.state = (s.dirT == 1) ? "UP: WAIT PULLBACK" : "DOWN: WAIT PULLBACK";

   if(s.dirT == 1)
     {
      if(!(e20[1] > e50[1]))
         return;
      double lo = DBL_MAX;
      for(int k = 1; k <= InpPullbackLookback; k++)
         lo = MathMin(lo, iLow(s.sym, InpEntryTF, k));
      bool touched = (lo <= e20[1] + zone);
      bool resume  = (c1 > e20[1] && c1 > o1 && rs[1] > InpRSIGate && rs[1] > rs[2]);
      if(touched && resume)
         s.sig = 1;
     }
   else
     {
      if(!(e20[1] < e50[1]))
         return;
      double hi = 0.0;
      for(int k = 1; k <= InpPullbackLookback; k++)
         hi = MathMax(hi, iHigh(s.sym, InpEntryTF, k));
      bool touched = (hi >= e20[1] - zone);
      bool resume  = (c1 < e20[1] && c1 < o1 && rs[1] < 100.0 - InpRSIGate && rs[1] < rs[2]);
      if(touched && resume)
         s.sig = -1;
     }

   if(s.sig != 0)
     {
      s.sigDone = false;
      s.sigATR  = at[1];
      s.state = (s.sig == 1) ? "SIGNAL: BUY" : "SIGNAL: SELL";
     }
  }

//+------------------------------------------------------------------+
bool EntryAllowed(SymState &s, string &why)
  {
   PosStats ps;
   GetPosStats(ps, s.sym);
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
   if(ps.sym > 0 && (ps.dir != s.sig || !ps.allProtected))
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
   if(s.lastEntryBar != 0)
     {
      int sh = iBarShift(s.sym, InpEntryTF, s.lastEntryBar, false);
      if(sh >= 0 && sh < InpCooldownBars)
        {
         why = "cooldown";
         return false;
        }
     }
   if(SymbolInfoInteger(s.sym, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     {
      why = "trading disabled for symbol";
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
double ComputeLots(const string sym, const ENUM_ORDER_TYPE type, const double entry, const double sl, string &why)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double p1 = 0.0;
   if(!OrderCalcProfit(type, sym, 1.0, entry, sl, p1) || p1 >= 0.0)
     {
      why = "cannot estimate loss per lot";
      return 0.0;
     }
   double lossPerLot = -p1;
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
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
   if(OrderCalcMargin(type, sym, lots, entry, margin) && margin > 0.0)
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
void TryExecuteSignal(SymState &s)
  {
   string why = "";
   if(!EntryAllowed(s, why))
     {
      VerboseS(s, why);
      s.sigDone = true;
      return;
     }

   double ask = SymbolInfoDouble(s.sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s.sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;
   if((ask - bid) > InpMaxSpreadPctATR / 100.0 * s.sigATR)
     {
      VerboseS(s, "spread too wide, waiting");
      return;
     }

   double point    = SymbolInfoDouble(s.sym, SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS);
   double slDist   = InpSLATR * s.sigATR;
   double stopsLvl = (double)SymbolInfoInteger(s.sym, SYMBOL_TRADE_STOPS_LEVEL) * point;
   if(stopsLvl > 0.0 && slDist < stopsLvl * 1.2)
      slDist = stopsLvl * 1.2;

   ENUM_ORDER_TYPE ot = (s.sig == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entry = (s.sig == 1) ? ask : bid;
   double sl = NormalizeDouble((s.sig == 1) ? entry - slDist : entry + slDist, digits);
   double tp = 0.0;
   if(InpTPR > 0.0)
      tp = NormalizeDouble((s.sig == 1) ? entry + InpTPR * slDist : entry - InpTPR * slDist, digits);

   double lots = ComputeLots(s.sym, ot, entry, sl, why);
   if(lots <= 0.0)
     {
      VerboseS(s, why);
      s.sigDone = true;
      return;
     }

   double p = 0.0;
   double newRisk = 0.0;
   if(OrderCalcProfit(ot, s.sym, lots, entry, sl, p) && p < 0.0)
      newRisk = -p;
   if(OpenRiskMoney() + newRisk > AccountInfoDouble(ACCOUNT_EQUITY) * InpMaxOpenRiskPct / 100.0)
     {
      VerboseS(s, "open-risk cap");
      s.sigDone = true;
      return;
     }

   trade.SetTypeFillingBySymbol(s.sym);
   trade.SetDeviationInPoints((ulong)MathMax(10.0, 0.05 * slDist / point));
   string tag = TAG_MAIN + DoubleToString(MathAbs(entry - sl), digits);
   bool ok = (s.sig == 1) ? trade.Buy(lots, s.sym, 0.0, sl, tp, tag)
                          : trade.Sell(lots, s.sym, 0.0, sl, tp, tag);
   s.sigDone = true;
   if(ok)
     {
      s.lastEntryBar = s.barTime;
      RefreshDayStats(true);
     }
   else
      Print("ConfirmedTrendEA ", s.sym, ": order failed, retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
  }

//+------------------------------------------------------------------+
void ManageOpenPositions(SymState &s)
  {
   if(InpTrailATR <= 0.0)
      return;
   double at[];
   ArraySetAsSeries(at, true);
   if(CopyBuffer(s.hATR, 0, 0, 3, at) < 3 || at[1] <= 0.0)
      return;

   double point    = SymbolInfoDouble(s.sym, SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS);
   double stopsLvl = (double)SymbolInfoInteger(s.sym, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double ask = SymbolInfoDouble(s.sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s.sym, SYMBOL_BID);
   double spread = ask - bid;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != s.sym)
         continue;
      if(SelectedIsCounter())
         continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      int shift = iBarShift(s.sym, InpEntryTF, (datetime)PositionGetInteger(POSITION_TIME), false);
      if(shift < 1)
         continue;

      if(type == POSITION_TYPE_BUY)
        {
         int idx = iHighest(s.sym, InpEntryTF, MODE_HIGH, shift, 1);
         if(idx < 0)
            continue;
         double ext   = MathMax(iHigh(s.sym, InpEntryTF, idx), open);
         double newSL = NormalizeDouble(ext - InpTrailATR * at[1], digits);
         if((sl <= 0.0 || newSL > sl + point * 0.5) && newSL < bid - stopsLvl)
            trade.PositionModify(tk, newSL, tp);
        }
      else
        {
         int idx = iLowest(s.sym, InpEntryTF, MODE_LOW, shift, 1);
         if(idx < 0)
            continue;
         double ext   = MathMin(iLow(s.sym, InpEntryTF, idx), open);
         double newSL = NormalizeDouble(ext + spread + InpTrailATR * at[1], digits);
         if((sl <= 0.0 || newSL < sl - point * 0.5) && newSL > ask + stopsLvl)
            trade.PositionModify(tk, newSL, tp);
        }
     }
  }

//+------------------------------------------------------------------+
// Counter-trade: opposite position when a main position is down
// InpCounterTriggerR. Stop at the main position's entry price; 50% closed
// at TP1 (stop to break-even), the remainder runs to TP2.
//+------------------------------------------------------------------+
string CounterTag(const ulong parent)
  {
   return TAG_COUNTER + (string)parent;
  }

ulong FindCounterTicket(const ulong parent)
  {
   string want = CounterTag(parent);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_COMMENT) == want)
         return tk;
     }
   return 0;
  }

void OpenCounter(SymState &s, const ulong parent, const long ptype, const double pvol, const double popen)
  {
   double point    = SymbolInfoDouble(s.sym, SYMBOL_POINT);
   int    digits   = (int)SymbolInfoInteger(s.sym, SYMBOL_DIGITS);
   double stopsLvl = (double)SymbolInfoInteger(s.sym, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double ask = SymbolInfoDouble(s.sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s.sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   ENUM_ORDER_TYPE ot = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   int    dc    = (ot == ORDER_TYPE_BUY) ? 1 : -1;
   double entry = (ot == ORDER_TYPE_BUY) ? ask : bid;
   double sl    = NormalizeDouble(popen, digits);
   double rc    = MathAbs(sl - entry);
   if(rc < stopsLvl + 3.0 * (ask - bid))
     {
      VerboseS(s, "counter skipped: stop would be too close");
      return;
     }

   double step   = SymbolInfoDouble(s.sym, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(s.sym, SYMBOL_VOLUME_MIN);
   if(step <= 0.0 || minLot <= 0.0)
      return;
   double pct = MathMin(100.0, MathMax(1.0, InpCounterVolPct));
   double vol = MathFloor(pvol * pct / 100.0 / step + 1.0e-9) * step;
   vol = MathMin(vol, pvol);
   if(vol < minLot - 1.0e-12)
     {
      VerboseS(s, "counter skipped: size below minimum lot");
      return;
     }

   double p = 0.0;
   double risk = 0.0;
   if(OrderCalcProfit(ot, s.sym, vol, entry, sl, p) && p < 0.0)
      risk = -p;
   if(OpenRiskMoney() + risk > AccountInfoDouble(ACCOUNT_EQUITY) * InpMaxOpenRiskPct / 100.0)
     {
      VerboseS(s, "counter skipped: open-risk cap");
      return;
     }
   double margin = 0.0;
   if(OrderCalcMargin(ot, s.sym, vol, entry, margin) && margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * InpMaxMarginUsePct / 100.0)
     {
      VerboseS(s, "counter skipped: margin");
      return;
     }

   double tp1 = entry + dc * InpCounterTP1R * rc;
   double tp2 = NormalizeDouble(entry + dc * InpCounterTP2R * rc, digits);
   trade.SetTypeFillingBySymbol(s.sym);
   trade.SetDeviationInPoints((ulong)MathMax(10.0, 0.05 * rc / point));
   bool ok = (ot == ORDER_TYPE_BUY) ? trade.Buy(vol, s.sym, 0.0, sl, tp2, CounterTag(parent))
                                    : trade.Sell(vol, s.sym, 0.0, sl, tp2, CounterTag(parent));
   if(!ok)
     {
      Print("ConfirmedTrendEA ", s.sym, ": counter order failed, retcode=", trade.ResultRetcode(), " ", trade.ResultRetcodeDescription());
      return;
     }
   GlobalVariableSet("CTE_H_" + (string)parent, 1.0);
   ulong ctk = FindCounterTicket(parent);
   if(ctk != 0)
      GlobalVariableSet("CTE_T1_" + (string)ctk, tp1);
   PrintFormat("ConfirmedTrendEA %s: counter-trade opened against ticket %I64u (vol %.4f, TP1 %s, TP2 %s)",
               s.sym, parent, vol, DoubleToString(tp1, digits), DoubleToString(tp2, digits));
  }

void SpawnCounters(SymState &s)
  {
   if(!InpCounterEnabled || !gHedging)
      return;
   double ask = SymbolInfoDouble(s.sym, SYMBOL_ASK);
   double bid = SymbolInfoDouble(s.sym, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return;

   ulong  cTk[];
   long   cType[];
   double cVol[];
   double cOpen[];
   int    n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != s.sym || SelectedIsCounter())
         continue;
      double r = SelectedMainRisk();
      if(r <= 0.0 || GlobalVariableCheck("CTE_H_" + (string)tk))
         continue;
      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double lossR = (type == POSITION_TYPE_BUY) ? (open - bid) / r : (ask - open) / r;
      if(lossR < InpCounterTriggerR)
         continue;
      ArrayResize(cTk, n + 1);
      ArrayResize(cType, n + 1);
      ArrayResize(cVol, n + 1);
      ArrayResize(cOpen, n + 1);
      cTk[n] = tk;
      cType[n] = type;
      cVol[n] = PositionGetDouble(POSITION_VOLUME);
      cOpen[n] = open;
      n++;
     }
   for(int k = 0; k < n; k++)
      OpenCounter(s, cTk[k], cType[k], cVol[k], cOpen[k]);
  }

void ManageCounterTP1()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || !SelectedIsCounter())
         continue;
      string key = "CTE_T1_" + (string)tk;
      if(!GlobalVariableCheck(key))
         continue;
      double tp1 = GlobalVariableGet(key);
      if(tp1 <= 0.0)
         continue;

      string sym  = PositionGetString(POSITION_SYMBOL);
      long   type = PositionGetInteger(POSITION_TYPE);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp   = PositionGetDouble(POSITION_TP);
      double bid  = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask  = SymbolInfoDouble(sym, SYMBOL_ASK);
      bool hit = (type == POSITION_TYPE_BUY) ? (bid >= tp1) : (ask <= tp1);
      if(!hit)
         continue;

      GlobalVariableSet(key, 0.0);
      double step   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      double point  = SymbolInfoDouble(sym, SYMBOL_POINT);
      int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double part = MathFloor(vol * InpCounterTP1Pct / 100.0 / step + 1.0e-9) * step;
      if(step > 0.0 && part >= minLot - 1.0e-12 && (vol - part) >= minLot - 1.0e-12)
         trade.PositionClosePartial(tk, part);

      double stopsLvl = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) * point;
      double be = NormalizeDouble(open, digits);
      bool valid = (type == POSITION_TYPE_BUY) ? (be < bid - stopsLvl) : (be > ask + stopsLvl);
      if(valid)
         trade.PositionModify(tk, be, tp);
     }
  }

void CleanupGlobals()
  {
   bool tester = (MQLInfoInteger(MQL_TESTER) != 0);
   for(int i = GlobalVariablesTotal() - 1; i >= 0; i--)
     {
      string nm = GlobalVariableName(i);
      bool t1 = (StringFind(nm, "CTE_T1_") == 0);
      bool hd = (StringFind(nm, "CTE_H_") == 0);
      if(!t1 && !hd)
         continue;
      if(tester)
        {
         GlobalVariableDel(nm);
         continue;
        }
      ulong tk = (ulong)StringToInteger(StringSubstr(nm, t1 ? 7 : 6));
      if(!PositionSelectByTicket(tk))
         GlobalVariableDel(nm);
     }
  }

//+------------------------------------------------------------------+
//  Dashboard
//+------------------------------------------------------------------+
color cBack()   { return InpDashDark ? C'20,24,33'   : C'246,247,250'; }
color cEdge()   { return InpDashDark ? C'60,68,86'   : C'190,196,210'; }
color cText()   { return InpDashDark ? C'214,219,230' : C'30,34,44'; }
color cDim()    { return InpDashDark ? C'128,138,156' : C'110,118,134'; }
color cGood()   { return InpDashDark ? C'84,206,128'  : C'20,140,70'; }
color cBad()    { return InpDashDark ? C'240,100,100' : C'200,40,40'; }
color cWarn()   { return InpDashDark ? C'242,184,64'  : C'190,120,0'; }
color cInfo()   { return InpDashDark ? C'110,176,255' : C'20,90,190'; }

color PnlColor(const double v)
  {
   if(v > 0.0)
      return cGood();
   if(v < 0.0)
      return cBad();
   return cDim();
  }

int DashY(const int row)
  {
   return 6 + row * 15;
  }

string DashName(const string key)
  {
   return DASH_PREFIX + key;
  }

void DashPut(const string key, const int x, const int row, const string text, const color clr)
  {
   string name = DashName(key);
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashFont);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashX + x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashY + DashY(row));
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != clr)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void DashBackground(const int rows)
  {
   string name = DashName("bg");
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashX - 4);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashY - 2);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 856);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, DashY(rows) + 8);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, cBack());
   ObjectSetInteger(0, name, OBJPROP_COLOR, cEdge());
  }

void DashMetric(const string key, const int x, const int row, const string caption, const string value, const color clr)
  {
   DashPut(key + "c", x, row, caption, cDim());
   DashPut(key + "v", x + 7 * (StringLen(caption) + 1), row, value, clr);
  }

string TFTrend(SymState &s, const int k, color &clr)
  {
   double a[], b[];
   ArraySetAsSeries(a, true);
   ArraySetAsSeries(b, true);
   int h1 = s.dh[2 * k];
   int h2 = s.dh[2 * k + 1];
   clr = cDim();
   if(h1 == INVALID_HANDLE || h2 == INVALID_HANDLE)
      return "..";
   if(CopyBuffer(h1, 0, 0, 2, a) < 2 || CopyBuffer(h2, 0, 0, 2, b) < 2)
      return "..";
   double c = iClose(s.sym, gDashTF[k], 1);
   if(a[1] > b[1] && c > b[1])
     {
      clr = cGood();
      return "UP";
     }
   if(a[1] < b[1] && c < b[1])
     {
      clr = cBad();
      return "DN";
     }
   clr = cWarn();
   return "--";
  }

string DayName(const int dow)
  {
   string d[7] = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"};
   if(dow < 0 || dow > 6)
      return "";
   return d[dow];
  }

void RefreshCalendar()
  {
   gCalTick = GetTickCount();
   gCalCount = 0;
   gCalOk = false;
   if(MQLInfoInteger(MQL_TESTER))
      return;

   string cur[];
   int nc = 0;
   for(int i = 0; i < ArraySize(gS); i++)
     {
      string a[2];
      int na = 0;
      if(gS[i].cls == ASSET_CRYPTO)
        {
         a[0] = "USD";
         na = 1;
        }
      else
        {
         string u = gS[i].sym;
         StringToUpper(u);
         a[0] = StringSubstr(u, 0, 3);
         a[1] = StringSubstr(u, 3, 3);
         na = 2;
        }
      for(int k = 0; k < na; k++)
        {
         bool dup = false;
         for(int j = 0; j < nc; j++)
            if(cur[j] == a[k])
               dup = true;
         if(!dup && StringLen(a[k]) == 3)
           {
            ArrayResize(cur, nc + 1);
            cur[nc] = a[k];
            nc++;
           }
        }
     }

   datetime from = TimeCurrent() - 600;
   datetime to   = TimeCurrent() + (datetime)(InpCalendarHours * 3600);
   for(int c = 0; c < nc; c++)
     {
      MqlCalendarValue vals[];
      int n = CalendarValueHistory(vals, from, to, NULL, cur[c]);
      if(n < 0)
         continue;
      gCalOk = true;
      for(int k = 0; k < n; k++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(vals[k].event_id, ev))
            continue;
         if(ev.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;
         int pos = gCalCount;
         if(pos >= 64)
            continue;
         while(pos > 0 && gEvT[pos - 1] > vals[k].time)
           {
            gEvT[pos] = gEvT[pos - 1];
            gEvC[pos] = gEvC[pos - 1];
            gEvN[pos] = gEvN[pos - 1];
            pos--;
           }
         gEvT[pos] = vals[k].time;
         gEvC[pos] = cur[c];
         gEvN[pos] = ev.name;
         gCalCount++;
        }
     }
  }

string Countdown(const datetime t)
  {
   long d = (long)t - (long)TimeCurrent();
   if(d <= 0)
      return "now";
   long h = d / 3600;
   long m = (d % 3600) / 60;
   if(h >= 24)
      return StringFormat("%dd %dh", (int)(h / 24), (int)(h % 24));
   return StringFormat("%dh %02dm", (int)h, (int)m);
  }

void UpdateDashboard()
  {
   if(!InpShowDashboard)
      return;
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
      return;

   RefreshDayStats(false);
   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   double fl    = FloatingPL();
   double dayPL = gDayRealized + fl;
   double tProf = TargetProfit();
   double dayStart = bal - gDayRealized;
   double openRisk = OpenRiskMoney();
   double riskPct  = (eq > 0.0) ? openRisk / eq * 100.0 : 0.0;
   double lossUsed = (dayStart > 0.0 && dayPL < 0.0) ? (-dayPL / dayStart * 100.0) : 0.0;
   double mLevel   = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double mFree    = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   PosStats allPs;
   GetPosStats(allPs, "");

   string status;
   color  stColor;
   if(InpStopAtProfitTarget && InpProfitTargetUSD > 0.0 && tProf >= InpProfitTargetUSD)
     {
      status = "HALTED - PROFIT TARGET";
      stColor = cGood();
     }
   else if(dayStart > 0.0 && lossUsed >= InpDailyLossPct)
     {
      status = "PAUSED - DAILY LOSS LIMIT";
      stColor = cBad();
     }
   else if(InpPauseAfterLosses > 0 && gDayConsec >= InpPauseAfterLosses)
     {
      status = "PAUSED - LOSS STREAK";
      stColor = cBad();
     }
   else if(gDayEntries >= InpMaxEntriesPerDay)
     {
      status = "LIMIT - ENTRIES TODAY";
      stColor = cWarn();
     }
   else
     {
      status = "ACTIVE";
      stColor = cGood();
     }

   int symRows = ArraySize(gS);
   int posRows = MathMax(1, InpDashPositionRows);
   int calRows = InpShowCalendar ? MathMax(1, InpCalendarRows) : 0;
   DashBackground(symRows + posRows + 13 + (InpShowCalendar ? 1 + calRows : 0));

   int row = 0;
   DashPut("t1", 8, row, "CONFIRMED TREND EA  v2.20", cInfo());
   DashPut("t2", 230, row, StringFormat("%s MYT", TimeToString(ToMYT(TimeCurrent()), TIME_DATE | TIME_MINUTES)), cText());
   DashPut("t3", 420, row, status, stColor);
   DashPut("t4", 640, row, StringFormat("FX %s   CRYPTO %s", InSessionAt(TimeCurrent(), ASSET_FOREX) ? "OPEN" : "closed",
                                         InSessionAt(TimeCurrent(), ASSET_CRYPTO) ? "OPEN" : "closed"), cDim());
   row++;

   DashMetric("a1", 8,   row, "Balance", DoubleToString(bal, 2), cText());
   DashMetric("a2", 160, row, "Equity", DoubleToString(eq, 2), cText());
   DashMetric("a3", 312, row, "Floating", StringFormat("%+.2f", fl), PnlColor(fl));
   DashMetric("a4", 470, row, "Today", StringFormat("%+.2f", dayPL), PnlColor(dayPL));
   DashMetric("a5", 610, row, InpTargetScope == TARGET_DAILY ? "Day target" : "Target",
              StringFormat("%+.2f / %.0f", tProf, InpProfitTargetUSD), PnlColor(tProf));
   row++;

   DashMetric("b1", 8,   row, "Margin lvl", mLevel > 0.0 ? StringFormat("%.0f%%", mLevel) : "-", mLevel > 0.0 && mLevel < 300.0 ? cBad() : cText());
   DashMetric("b2", 160, row, "Free", DoubleToString(mFree, 2), cText());
   DashMetric("b3", 312, row, "Open risk", StringFormat("%.2f (%.1f%%/%.0f%%)", openRisk, riskPct, InpMaxOpenRiskPct),
              riskPct >= InpMaxOpenRiskPct ? cBad() : (riskPct >= InpMaxOpenRiskPct * 0.7 ? cWarn() : cText()));
   DashMetric("b4", 560, row, "Day loss", StringFormat("%.1f%%/%.0f%%", lossUsed, InpDailyLossPct),
              lossUsed >= InpDailyLossPct * 0.7 ? cWarn() : cText());
   row++;

   DashMetric("c1", 8,   row, "Entries", StringFormat("%d/%d", gDayEntries, InpMaxEntriesPerDay), gDayEntries >= InpMaxEntriesPerDay ? cWarn() : cText());
   DashMetric("c2", 160, row, "Loss streak", StringFormat("%d/%d", gDayConsec, InpPauseAfterLosses), gDayConsec > 0 ? cWarn() : cText());
   DashMetric("c3", 312, row, "Positions", StringFormat("%d/%d main, %d counter", allPs.total, InpMaxPositionsTotal, allPs.counters), cText());
   DashMetric("c4", 560, row, "Counter", InpCounterEnabled ? (gHedging ? "ON" : "needs hedging acct") : "OFF", InpCounterEnabled ? cInfo() : cDim());
   row++;

   DashMetric("d1", 8,   row, "Sizing", InpLotMode == LOT_FIXED ? StringFormat("fixed %.2f lot", InpFixedLot) : StringFormat("%.1f%% risk", InpRiskPercent), cText());
   DashMetric("d2", 232, row, "Risk cap/trade", StringFormat("%.1f%%", InpMaxRiskPerTradePct), cText());
   DashMetric("d3", 440, row, "Trail", InpTrailATR > 0.0 ? StringFormat("%.1f ATR", InpTrailATR) : "off", cText());
   DashMetric("d4", 600, row, "Stop", StringFormat("%.1f ATR", InpSLATR), cText());
   row++;
   row++;

   int xs[13] = {8, 98, 192, 252, 296, 340, 384, 432, 492, 664, 704, 764, 0};
   DashPut("h0", xs[0], row, "PAIR", cDim());
   DashPut("h1", xs[1], row, "PRICE", cDim());
   DashPut("h2", xs[2], row, "SPR%ATR", cDim());
   for(int k = 0; k < 4; k++)
      DashPut("hT" + (string)k, xs[3 + k] , row, gDashTFName[k], cDim());
   DashPut("h7", xs[7], row, "VOL x", cDim());
   DashPut("h8", xs[8], row, "STATE", cDim());
   DashPut("h9", xs[9], row, "POS", cDim());
   DashPut("h10", xs[10], row, "LOTS", cDim());
   DashPut("h11", xs[11], row, "P/L", cDim());
   row++;

   for(int i = 0; i < symRows; i++)
     {
      string pre = "s" + (string)i + "_";
      int digits = (int)SymbolInfoInteger(gS[i].sym, SYMBOL_DIGITS);
      double bid = SymbolInfoDouble(gS[i].sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(gS[i].sym, SYMBOL_ASK);
      double sprPct = (gS[i].atr > 0.0) ? (ask - bid) / gS[i].atr * 100.0 : 0.0;

      double lots = 0.0, pl = 0.0;
      int np = 0;
      for(int p = PositionsTotal() - 1; p >= 0; p--)
        {
         ulong tk = PositionGetTicket(p);
         if(tk == 0)
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != gS[i].sym)
            continue;
         np++;
         lots += (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1.0 : -1.0) * PositionGetDouble(POSITION_VOLUME);
         pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }

      string st = gS[i].state;
      if(st == "")
         st = "WARMING UP";
      if(st != "OUT OF SESSION" && st != "DISABLED" && !InSessionAt(TimeCurrent(), gS[i].cls))
         st = "OUT OF SESSION";
      color stc = cDim();
      if(StringFind(st, "SIGNAL") == 0)
         stc = cInfo();
      else if(StringFind(st, "WAIT") >= 0)
         stc = cText();

      DashPut(pre + "0", xs[0], row, gS[i].sym + (gS[i].cls == ASSET_CRYPTO ? " *" : ""), cText());
      DashPut(pre + "1", xs[1], row, bid > 0.0 ? DoubleToString(bid, digits) : "-", cText());
      DashPut(pre + "2", xs[2], row, gS[i].atr > 0.0 ? StringFormat("%.0f%%", sprPct) : "-", sprPct > InpMaxSpreadPctATR ? cWarn() : cDim());
      for(int k = 0; k < 4; k++)
        {
         color tc;
         string tt = TFTrend(gS[i], k, tc);
         DashPut(pre + "T" + (string)k, xs[3 + k], row, tt, tc);
        }
      DashPut(pre + "7", xs[7], row, gS[i].vol > 0.0 && gS[i].vol < 1.0e8 ? StringFormat("%.2f", gS[i].vol) : "-",
              gS[i].vol >= InpMinVolRatio ? cGood() : cDim());
      DashPut(pre + "8", xs[8], row, st, stc);
      DashPut(pre + "9", xs[9], row, np > 0 ? (string)np : "-", np > 0 ? cText() : cDim());
      DashPut(pre + "10", xs[10], row, np > 0 ? StringFormat("%+.2f", lots) : "-", cText());
      DashPut(pre + "11", xs[11], row, np > 0 ? StringFormat("%+.2f", pl) : "-", np > 0 ? PnlColor(pl) : cDim());
      row++;
     }
   row++;

   DashPut("ph", 8, row, "OPEN POSITIONS", cInfo());
   row++;
   DashPut("ph2", 8, row, "PAIR     SIDE     LOTS  OPEN        STOP", cDim());
   DashPut("ph3", 500, row, "P/L", cDim());
   DashPut("ph4", 590, row, "R", cDim());
   DashPut("ph5", 690, row, "TYPE", cDim());
   row++;
   int shown = 0;
   for(int p = PositionsTotal() - 1; p >= 0 && shown < posRows; p--)
     {
      ulong tk = PositionGetTicket(p);
      if(tk == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      string sym = PositionGetString(POSITION_SYMBOL);
      long   type = PositionGetInteger(POSITION_TYPE);
      double vol  = PositionGetDouble(POSITION_VOLUME);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double pl   = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      bool counter = SelectedIsCounter();
      int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      double rMoney = 0.0, pp = 0.0;
      if(sl > 0.0 && OrderCalcProfit(type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, sym, vol, open, sl, pp))
         rMoney = MathAbs(pp);
      string rs = (rMoney > 0.0 && !IsProtected(type, open, sl)) ? StringFormat("%+.2fR", pl / rMoney) : "prot.";
      string line = StringFormat("%-8s %-4s %6.2f  %-10s  %-10s", sym, type == POSITION_TYPE_BUY ? "BUY" : "SELL", vol,
                                 DoubleToString(open, dg), sl > 0.0 ? DoubleToString(sl, dg) : "-");
      string key = "p" + (string)shown;
      DashPut(key + "a", 8, row, line, cText());
      DashPut(key + "b", 500, row, StringFormat("%+.2f", pl), PnlColor(pl));
      DashPut(key + "c", 590, row, rs, PnlColor(pl));
      DashPut(key + "d", 690, row, counter ? "COUNTER" : "MAIN", counter ? cInfo() : cDim());
      shown++;
      row++;
     }
   if(shown == 0)
     {
      DashPut("pnone", 8, row, "no open positions", cDim());
      row++;
      shown = 1;
     }
   while(shown < posRows)
     {
      string key = "p" + (string)shown;
      DashPut(key + "a", 8, row, "", cText());
      DashPut(key + "b", 500, row, "", cText());
      DashPut(key + "c", 590, row, "", cText());
      DashPut(key + "d", 690, row, "", cText());
      shown++;
      row++;
     }
   row++;

   if(InpShowCalendar)
     {
      if(gCalTick == 0 || (GetTickCount() - gCalTick) > 600000)
         RefreshCalendar();
      DashPut("eh", 8, row, "NEXT HIGH-IMPACT EVENTS (Malaysia time)", cInfo());
      row++;
      int shownE = 0;
      for(int e = 0; e < gCalCount && shownE < calRows; e++)
        {
         MqlDateTime tm;
         TimeToStruct(ToMYT(gEvT[e]), tm);
         string nm = gEvN[e];
         if(StringLen(nm) > 46)
            nm = StringSubstr(nm, 0, 46);
         string key = "e" + (string)shownE;
         DashPut(key + "a", 8, row, StringFormat("%s %02d:%02d", DayName(tm.day_of_week), tm.hour, tm.min), cText());
         DashPut(key + "b", 110, row, gEvC[e], cWarn());
         DashPut(key + "c", 160, row, nm, cText());
         DashPut(key + "d", 620, row, "in " + Countdown(gEvT[e]), cDim());
         shownE++;
         row++;
        }
      if(shownE == 0)
        {
         string msg = MQLInfoInteger(MQL_TESTER) ? "calendar not available in the tester"
                      : (gCalOk ? "no high-impact events in the window" : "calendar data not available from this broker/terminal yet");
         DashPut("enone", 8, row, msg, cDim());
         row++;
         shownE = 1;
        }
      while(shownE < calRows)
        {
         string key = "e" + (string)shownE;
         DashPut(key + "a", 8, row, "", cText());
         DashPut(key + "b", 110, row, "", cText());
         DashPut(key + "c", 160, row, "", cText());
         DashPut(key + "d", 620, row, "", cText());
         shownE++;
         row++;
        }
     }
   DashPut("foot", 8, row, "* crypto symbol   UP/DN = EMA50 vs EMA200 and price vs EMA200 on that timeframe   -- = mixed", cDim());
   DashBackground(row + 1);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void ReleaseHandle(int &h)
  {
   if(h != INVALID_HANDLE)
      IndicatorRelease(h);
   h = INVALID_HANDLE;
  }

void ReleaseSymbol(SymState &s)
  {
   ReleaseHandle(s.hTrF);
   ReleaseHandle(s.hTrS);
   ReleaseHandle(s.hTrADX);
   ReleaseHandle(s.hEF);
   ReleaseHandle(s.hEM);
   ReleaseHandle(s.hRSI);
   ReleaseHandle(s.hATR);
   for(int k = 0; k < 8; k++)
      ReleaseHandle(s.dh[k]);
   s.ready = false;
  }

bool InitSymbol(SymState &s, const string sym)
  {
   s.sym = sym;
   s.ready = false;
   s.hTrF = INVALID_HANDLE;
   s.hTrS = INVALID_HANDLE;
   s.hTrADX = INVALID_HANDLE;
   s.hEF = INVALID_HANDLE;
   s.hEM = INVALID_HANDLE;
   s.hRSI = INVALID_HANDLE;
   s.hATR = INVALID_HANDLE;
   for(int k = 0; k < 8; k++)
      s.dh[k] = INVALID_HANDLE;
   s.barTime = 0;
   s.lastEntryBar = 0;
   s.sig = 0;
   s.sigDone = true;
   s.sigATR = 0.0;
   s.dirT = 0;
   s.vol = 0.0;
   s.atr = 0.0;
   s.state = "";
   s.lastMsg = "";

   s.cls = DetectClass(sym);
   if(s.cls == ASSET_NONE)
     {
      Print("ConfirmedTrendEA: skipping ", sym, " - not a recognised forex major or crypto name (see InpUnknownSymbols).");
      return false;
     }
   if(!SymbolSelect(sym, true))
     {
      Print("ConfirmedTrendEA: skipping ", sym, " - symbol is not available at this broker (check name / InpSymbolSuffix).");
      return false;
     }
   s.trendTF = (s.cls == ASSET_CRYPTO) ? InpCryptoTrendTF : InpForexTrendTF;

   s.hTrF   = iMA(sym, s.trendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   s.hTrS   = iMA(sym, s.trendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   s.hTrADX = iADX(sym, s.trendTF, InpADXPeriod);
   s.hEF    = iMA(sym, InpEntryTF, InpEntryFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   s.hEM    = iMA(sym, InpEntryTF, InpEntryMidEMA, 0, MODE_EMA, PRICE_CLOSE);
   s.hRSI   = iRSI(sym, InpEntryTF, InpRSIPeriod, PRICE_CLOSE);
   s.hATR   = iATR(sym, InpEntryTF, InpATRPeriod);
   if(s.hTrF == INVALID_HANDLE || s.hTrS == INVALID_HANDLE || s.hTrADX == INVALID_HANDLE ||
      s.hEF == INVALID_HANDLE || s.hEM == INVALID_HANDLE || s.hRSI == INVALID_HANDLE || s.hATR == INVALID_HANDLE)
     {
      Print("ConfirmedTrendEA: skipping ", sym, " - could not create indicators.");
      ReleaseSymbol(s);
      return false;
     }
   if(InpShowDashboard && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
     {
      for(int k = 0; k < 4; k++)
        {
         s.dh[2 * k]     = iMA(sym, gDashTF[k], InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
         s.dh[2 * k + 1] = iMA(sym, gDashTF[k], InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
        }
     }
   s.ready = true;
   return true;
  }

//+------------------------------------------------------------------+
bool AcquireLock()
  {
   if(MQLInfoInteger(MQL_TESTER))
      return true;
   gLockKey = "CTE_LOCK_" + (string)InpMagicNumber;
   if(GlobalVariableCheck(gLockKey) && ((double)TimeLocal() - GlobalVariableGet(gLockKey)) < 10.0)
      return false;
   GlobalVariableSet(gLockKey, (double)TimeLocal());
   return true;
  }

void Heartbeat()
  {
   if(gLockKey == "")
      return;
   uint nowTick = GetTickCount();
   if(gBeatTick != 0 && (nowTick - gBeatTick) < 1000)
      return;
   gBeatTick = nowTick;
   GlobalVariableSet(gLockKey, (double)TimeLocal());
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   if(!AcquireLock())
     {
      Print("ConfirmedTrendEA: another instance with magic number ", InpMagicNumber,
            " is already running. Attach the EA once, or give this one a different magic number.");
      return INIT_FAILED;
     }

   gHedging = ((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   gMaxPosSym = gHedging ? MathMax(1, InpMaxPositionsPerSymbol) : 1;
   if(InpCounterEnabled && !gHedging)
      Print("ConfirmedTrendEA: counter-trades need a hedging account; they are disabled on this netting account.");

   trade.SetExpertMagicNumber(InpMagicNumber);
   CleanupGlobals();

   string names[];
   int n = 0;
   string list = InpSymbols;
   StringTrimLeft(list);
   StringTrimRight(list);
   if(StringLen(list) == 0)
     {
      ArrayResize(names, 1);
      names[0] = _Symbol;
      n = 1;
     }
   else
     {
      string parts[];
      int cnt = StringSplit(list, ',', parts);
      for(int i = 0; i < cnt; i++)
        {
         string nm = parts[i];
         StringTrimLeft(nm);
         StringTrimRight(nm);
         if(StringLen(nm) == 0)
            continue;
         nm = nm + InpSymbolSuffix;
         bool dup = false;
         for(int j = 0; j < n; j++)
            if(names[j] == nm)
               dup = true;
         if(dup)
            continue;
         ArrayResize(names, n + 1);
         names[n] = nm;
         n++;
        }
     }

   ArrayResize(gS, 0);
   string active = "";
   for(int i = 0; i < n; i++)
     {
      int idx = ArraySize(gS);
      ArrayResize(gS, idx + 1);
      if(InitSymbol(gS[idx], names[i]))
         active = active + names[i] + " ";
      else
         ArrayResize(gS, idx);
     }
   if(ArraySize(gS) == 0)
     {
      Print("ConfirmedTrendEA: no usable symbols. Check InpSymbols and InpSymbolSuffix.");
      if(gLockKey != "")
         GlobalVariableDel(gLockKey);
      return INIT_FAILED;
     }

   gBaseKey = "CTE_BASE_" + (string)InpMagicNumber;
   if(MQLInfoInteger(MQL_TESTER) || InpResetBaseline || !GlobalVariableCheck(gBaseKey))
      GlobalVariableSet(gBaseKey, AccountInfoDouble(ACCOUNT_BALANCE));
   gBaseline = GlobalVariableGet(gBaseKey);

   PrintFormat("ConfirmedTrendEA v2.20: %d symbol(s) active | entry TF %s | max positions per symbol %d | GMT offset %.1f | counter-trades %s",
               ArraySize(gS), EnumToString(InpEntryTF), gMaxPosSym, GmtOffset(), (InpCounterEnabled && gHedging) ? "ON" : "OFF");
   Print("ConfirmedTrendEA: active symbols: ", active);
   if(InpLotMode == LOT_FIXED && AccountInfoDouble(ACCOUNT_BALANCE) < 200.0)
      Print("ConfirmedTrendEA: small balance with fixed lots - the per-trade risk cap (", InpMaxRiskPerTradePct,
            "%) will shrink or skip trades whose stop would risk more than that.");

   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   for(int i = 0; i < ArraySize(gS); i++)
      ReleaseSymbol(gS[i]);
   ObjectsDeleteAll(0, DASH_PREFIX);
   if(gLockKey != "")
      GlobalVariableDel(gLockKey);
  }

//+------------------------------------------------------------------+
void ProcessSymbol(SymState &s, const bool halted)
  {
   datetime bt = iTime(s.sym, InpEntryTF, 0);
   if(bt == 0)
      return;
   if(bt != s.barTime)
     {
      s.barTime = bt;
      ManageOpenPositions(s);
      SpawnCounters(s);
      if(halted)
        {
         s.sig = 0;
         s.sigDone = true;
         s.state = "HALTED";
        }
      else
         ComputeSignal(s);
     }
   if(!halted && s.sig != 0 && !s.sigDone)
      TryExecuteSignal(s);
  }

void RunAll()
  {
   Heartbeat();
   bool halted = ProfitTargetHalt();
   ManageCounterTP1();
   for(int i = 0; i < ArraySize(gS); i++)
     {
      if(gS[i].ready)
         ProcessSymbol(gS[i], halted);
     }
  }

void OnTick()
  {
   RunAll();
  }

void OnTimer()
  {
   RunAll();
   UpdateDashboard();
  }
//+------------------------------------------------------------------+
