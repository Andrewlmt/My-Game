//+------------------------------------------------------------------+
//|                                          ConfirmedTrendEA.mq5     |
//|  Trend-confirmation EA for small accounts (MetaTrader 5)         |
//|                                                                    |
//|  Designed around:                                                 |
//|    - $100 starting balance, 1:500 leverage, fixed 0.02 lot        |
//|    - Trades only Tue/Wed/Thu (avoids Mon gaps & Fri weekend risk) |
//|    - Major FX pairs only                                          |
//|    - Enters only when a higher-timeframe trend is confirmed by    |
//|      EMA alignment + ADX strength, then triggers on a pullback    |
//|      with RSI momentum confirmation on the trading timeframe      |
//|    - Halts new trades once a $75 profit target is reached         |
//|                                                                    |
//|  IMPORTANT: No EA guarantees profit. Backtest and forward-test    |
//|  on a demo account before running this live. Past performance     |
//|  does not predict future results.                                 |
//+------------------------------------------------------------------+
#property copyright "Andrew"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Inputs
input group "=== Account / Risk ==="
input double InpLotSize            = 0.02;      // Fixed lot size
input double InpProfitTargetUSD    = 75.0;      // Stop trading once session profit reaches this (USD)
input bool   InpStopAtProfitTarget = true;       // Halt new trades once target is hit
input bool   InpCloseAllAtTarget   = true;       // Close open trades once target is hit
input ulong  InpMagicNumber        = 20260928;   // Magic number
input int    InpMaxSpreadPoints    = 30;         // Max allowed spread (points)

input group "=== Trading Window (Malaysia time, GMT+8) ==="
input bool   InpTradeTuesday   = true;
input bool   InpTradeWednesday = true;
input bool   InpTradeThursday  = true;
input bool   InpMajorPairsOnly = true;    // Only trade recognised major FX pairs
input double InpBrokerGMTOffset = 2.0;    // Broker server time offset from GMT (set per broker, e.g. 2 or 3)
input int    InpSessionStartHour   = 15;  // Malaysia session start hour   (15:30 = 3:30pm)
input int    InpSessionStartMinute = 30;
input int    InpSessionEndHour     = 23;  // Malaysia session end hour     (23:00 = 11:00pm)
input int    InpSessionEndMinute   = 0;

input group "=== Trend Filter (higher timeframe) ==="
input ENUM_TIMEFRAMES InpTrendTF   = PERIOD_H1;
input int    InpTrendFastEMA  = 50;
input int    InpTrendSlowEMA  = 200;
input int    InpADXPeriod     = 14;
input double InpADXThreshold  = 25.0;

input group "=== Entry Trigger (trading timeframe) ==="
input int    InpEntryEMA      = 20;
input int    InpRSIPeriod     = 14;
input double InpRSIOverbought = 70.0;
input double InpRSIOversold   = 30.0;

input group "=== Exit ==="
input int    InpATRPeriod     = 14;
input double InpSL_ATRMult    = 1.5;
input double InpTP_ATRMult    = 3.0;
input bool   InpUseTrailing   = true;
input double InpTrail_ATRMult = 1.0;

CTrade trade;

int      hTrendFastEMA, hTrendSlowEMA, hADX, hEntryEMA, hRSI, hATR;
double   gStartBalance;
bool     gTargetHit = false;
datetime gLastBarTime = 0;

string kMajors[] = {"EURUSD","GBPUSD","USDJPY","USDCHF","AUDUSD","USDCAD","NZDUSD"};

//+------------------------------------------------------------------+
bool IsMajorPair(const string sym)
  {
   for(int i = 0; i < ArraySize(kMajors); i++)
      if(StringFind(sym, kMajors[i]) == 0)
         return true;
   return false;
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(InpMagicNumber);

   hTrendFastEMA = iMA(_Symbol, InpTrendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrendSlowEMA = iMA(_Symbol, InpTrendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   hADX          = iADX(_Symbol, InpTrendTF, InpADXPeriod);
   hEntryEMA     = iMA(_Symbol, PERIOD_CURRENT, InpEntryEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI          = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   hATR          = iATR(_Symbol, PERIOD_CURRENT, InpATRPeriod);

   if(hTrendFastEMA == INVALID_HANDLE || hTrendSlowEMA == INVALID_HANDLE ||
      hADX == INVALID_HANDLE || hEntryEMA == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Print("ConfirmedTrendEA: failed to create indicator handle(s)");
      return(INIT_FAILED);
     }

   gStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   gTargetHit    = false;
   gLastBarTime  = 0;

   if(InpMajorPairsOnly && !IsMajorPair(_Symbol))
      Print("ConfirmedTrendEA: ", _Symbol, " is not in the major-pair list; no trades will be opened here.");

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hTrendFastEMA);
   IndicatorRelease(hTrendSlowEMA);
   IndicatorRelease(hADX);
   IndicatorRelease(hEntryEMA);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);
  }

//+------------------------------------------------------------------+
bool WithinTradingWindow()
  {
   // Convert broker server time to Malaysia local time (GMT+8) so the
   // Tue-Thu day filter and session window both apply in Malaysia time,
   // regardless of what timezone the broker's server clock runs on.
   datetime myTime = TimeCurrent() + (datetime)((8.0 - InpBrokerGMTOffset) * 3600.0);

   MqlDateTime t;
   TimeToStruct(myTime, t);

   bool dayOk;
   switch(t.day_of_week)
     {
      case 2:  dayOk = InpTradeTuesday;   break; // Tuesday
      case 3:  dayOk = InpTradeWednesday; break; // Wednesday
      case 4:  dayOk = InpTradeThursday;  break; // Thursday
      default: dayOk = false;                    // Mon/Fri/weekend excluded
     }
   if(!dayOk)
      return false;

   int nowMinutes   = t.hour * 60 + t.min;
   int startMinutes = InpSessionStartHour * 60 + InpSessionStartMinute;
   int endMinutes   = InpSessionEndHour   * 60 + InpSessionEndMinute;

   if(nowMinutes < startMinutes || nowMinutes >= endMinutes)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
bool ProfitTargetReached()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profit = equity - gStartBalance;
   return(profit >= InpProfitTargetUSD);
  }

//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      trade.PositionClose(ticket);
     }
  }

//+------------------------------------------------------------------+
bool HasOpenPosition()
  {
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) == (long)InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
// Returns +1 (uptrend), -1 (downtrend) or 0 (no confirmed trend),   |
// based on the last fully closed bar of the higher timeframe.       |
//+------------------------------------------------------------------+
int TrendDirection()
  {
   double fast[], slow[], adx[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(adx,  true);

   if(CopyBuffer(hTrendFastEMA, 0, 0, 3, fast) < 3) return 0;
   if(CopyBuffer(hTrendSlowEMA, 0, 0, 3, slow) < 3) return 0;
   if(CopyBuffer(hADX, 0, 0, 3, adx) < 3) return 0;

   if(adx[1] < InpADXThreshold)
      return 0; // higher timeframe isn't trending strongly enough

   if(fast[1] > slow[1])
      return 1;
   if(fast[1] < slow[1])
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(!InpUseTrailing)
      return;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(hATR, 0, 0, 2, atr) < 2)
      return;

   double trailDist = atr[1] * InpTrail_ATRMult;

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double sl    = PositionGetDouble(POSITION_SL);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp    = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = price - trailDist;
         if(newSL > open && (sl == 0 || newSL > sl))
            trade.PositionModify(ticket, newSL, tp);
        }
      else
        {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = price + trailDist;
         if(newSL < open && (sl == 0 || newSL < sl))
            trade.PositionModify(ticket, newSL, tp);
        }
     }
  }

//+------------------------------------------------------------------+
void TryEnter()
  {
   int trend = TrendDirection();
   if(trend == 0)
      return;

   double emaEntry[], rsi[], atr[];
   ArraySetAsSeries(emaEntry, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);

   if(CopyBuffer(hEntryEMA, 0, 0, 3, emaEntry) < 3) return;
   if(CopyBuffer(hRSI, 0, 0, 3, rsi) < 3) return;
   if(CopyBuffer(hATR, 0, 0, 3, atr) < 3) return;

   double closePrev = iClose(_Symbol, PERIOD_CURRENT, 1);

   // RSI momentum resuming in the trend direction, confirmed on the last closed bar
   bool buySignal  = (trend == 1)  && (closePrev >= emaEntry[1]) &&
                      (rsi[1] > 50.0 && rsi[1] < InpRSIOverbought) && (rsi[2] <= 50.0);
   bool sellSignal = (trend == -1) && (closePrev <= emaEntry[1]) &&
                      (rsi[1] < 50.0 && rsi[1] > InpRSIOversold) && (rsi[2] >= 50.0);

   if(!buySignal && !sellSignal)
      return;

   double slDist = atr[1] * InpSL_ATRMult;
   double tpDist = atr[1] * InpTP_ATRMult;

   if(buySignal)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(InpLotSize, _Symbol, ask, ask - slDist, ask + tpDist, "ConfirmedTrendEA buy");
     }
   else
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(InpLotSize, _Symbol, bid, bid + slDist, bid - tpDist, "ConfirmedTrendEA sell");
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(InpStopAtProfitTarget && gTargetHit)
      return;

   if(InpStopAtProfitTarget && ProfitTargetReached())
     {
      gTargetHit = true;
      PrintFormat("ConfirmedTrendEA: profit target of $%.2f reached. Halting new trades.", InpProfitTargetUSD);
      if(InpCloseAllAtTarget)
         CloseAllPositions();
      return;
     }

   ManageTrailingStop();

   // Only evaluate new entries once per closed bar to avoid re-triggering intrabar
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == gLastBarTime)
      return;
   gLastBarTime = barTime;

   if(HasOpenPosition())
      return;
   if(!WithinTradingWindow())
      return;
   if(InpMajorPairsOnly && !IsMajorPair(_Symbol))
      return;

   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > InpMaxSpreadPoints)
      return;

   TryEnter();
  }
//+------------------------------------------------------------------+
