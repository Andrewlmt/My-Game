#pragma once
// Replace stub functions we implement for real; keep the rest of the stub.
#define iTime stub_iTime
#define iOpen stub_iOpen
#define iHigh stub_iHigh
#define iLow stub_iLow
#define iClose stub_iClose
#define iBarShift stub_iBarShift
#define iHighest stub_iHighest
#define iLowest stub_iLowest
#define iMA stub_iMA
#define iADX stub_iADX
#define iRSI stub_iRSI
#define iATR stub_iATR
#define CopyBuffer stub_CopyBuffer
#define TimeToStruct stub_TimeToStruct
#define TimeCurrent stub_TimeCurrent
#define TimeTradeServer stub_TimeTradeServer
#define MQLInfoInteger stub_MQLInfoInteger
#define AccountInfoInteger stub_AccountInfoInteger
#define AccountInfoDouble stub_AccountInfoDouble
#define PositionsTotal stub_PositionsTotal
#define PositionGetTicket stub_PositionGetTicket
#define PositionGetInteger stub_PositionGetInteger
#define PositionGetDouble stub_PositionGetDouble
#define PositionGetString stub_PositionGetString
#define OrderCalcProfit stub_OrderCalcProfit
#define OrderCalcMargin stub_OrderCalcMargin
#define HistorySelect stub_HistorySelect
#define HistoryDealsTotal stub_HistoryDealsTotal
#define HistoryDealGetTicket stub_HistoryDealGetTicket
#define HistoryDealGetInteger stub_HistoryDealGetInteger
#define HistoryDealGetDouble stub_HistoryDealGetDouble
#define SymbolInfoDouble stub_SymbolInfoDouble
#define SymbolInfoInteger stub_SymbolInfoInteger
#define GlobalVariableCheck stub_GlobalVariableCheck
#define GlobalVariableSet stub_GlobalVariableSet
#define GlobalVariableGet stub_GlobalVariableGet
#define GlobalVariableDel stub_GlobalVariableDel
#define StringSplit stub_StringSplit
#define StringTrimLeft stub_StringTrimLeft
#define StringTrimRight stub_StringTrimRight
#define CTrade StubCTrade
#define StringFormat stub_StringFormat
#define HistoryDealGetString stub_HistoryDealGetString
#define GlobalVariablesTotal stub_GlobalVariablesTotal
#define GlobalVariableName stub_GlobalVariableName
#define PositionSelectByTicket stub_PositionSelectByTicket
#define ObjectCreate stub_ObjectCreate
#define ObjectFind stub_ObjectFind
#define ObjectSetInteger stub_ObjectSetInteger
#define ObjectSetString stub_ObjectSetString
#define ObjectGetInteger stub_ObjectGetInteger
#define ObjectGetString stub_ObjectGetString
#define ObjectsDeleteAll stub_ObjectsDeleteAll
#define StringToInteger stub_StringToInteger
#define StringToDouble stub_StringToDouble
#define DoubleToString stub_DoubleToString
#define TimeToString stub_TimeToString
#include "mql5_stub.h"
#undef iTime
#undef iOpen
#undef iHigh
#undef iLow
#undef iClose
#undef iBarShift
#undef iHighest
#undef iLowest
#undef iMA
#undef iADX
#undef iRSI
#undef iATR
#undef CopyBuffer
#undef TimeToStruct
#undef TimeCurrent
#undef TimeTradeServer
#undef MQLInfoInteger
#undef AccountInfoInteger
#undef AccountInfoDouble
#undef PositionsTotal
#undef PositionGetTicket
#undef PositionGetInteger
#undef PositionGetDouble
#undef PositionGetString
#undef OrderCalcProfit
#undef OrderCalcMargin
#undef HistorySelect
#undef HistoryDealsTotal
#undef HistoryDealGetTicket
#undef HistoryDealGetInteger
#undef HistoryDealGetDouble
#undef SymbolInfoDouble
#undef SymbolInfoInteger
#undef GlobalVariableCheck
#undef GlobalVariableSet
#undef GlobalVariableGet
#undef GlobalVariableDel
#undef StringSplit
#undef StringTrimLeft
#undef StringTrimRight
#undef CTrade
#undef StringFormat
#undef HistoryDealGetString
#undef GlobalVariablesTotal
#undef GlobalVariableName
#undef PositionSelectByTicket
#undef ObjectCreate
#undef ObjectFind
#undef ObjectSetInteger
#undef ObjectSetString
#undef ObjectGetInteger
#undef ObjectGetString
#undef ObjectsDeleteAll
#undef StringToInteger
#undef StringToDouble
#undef DoubleToString
#undef TimeToString
#include <ctime>
#include <fstream>
#include <sstream>
#include <limits>
#include <map>
#include <algorithm>

static const double NANV = std::numeric_limits<double>::quiet_NaN();
struct BarStore { std::vector<long> t; std::vector<double> o, h, l, c; };
struct SymSpec { double contract, spread, point, minLot, maxLot, step; int digits; bool quoteUSD; };
struct IndStore { std::string sym; std::vector<double> v; };
struct Pos { ulong ticket; std::string sym; int type; double vol, open, sl, tp, initSL; long time; ulong magic; std::string comment; double riskUnit; double pnlAcc; };
struct Deal { ulong ticket; long time; int entry; double profit, commission, swap; ulong magic; std::string comment; };
struct Obj { std::string text; long x, y; long color; };
struct TradeRec { long t0, t1; std::string sym; int dir; double open, exitPx, R, pnl; };
extern std::map<std::string, BarStore> gStore;
extern std::map<std::string, SymSpec> gSpec;
extern std::vector<IndStore> gInd;
extern std::vector<Pos> gPos; extern std::vector<Deal> gDeals; extern std::vector<int> gDealSel;
extern std::vector<TradeRec> gRecs; extern std::map<std::string, double> gGV;
extern std::map<std::string, Obj> gObj; extern bool gOvr; extern std::string gOvrSym; extern double gOvrBid;
extern int gCur, gSel; extern long gNow; extern double gBalance; extern ulong gNextTicket;

inline BarStore& ST(const string& s){ return gStore[std::string(s)]; }
inline long barT(const string& s, int sh){ auto& b = ST(s); int i = gCur - sh; return (i >= 0 && i < (int)b.t.size()) ? b.t[i] : 0; }
inline datetime iTime(const string& s, ENUM_TIMEFRAMES, int sh){ return barT(s, sh); }
inline double iOpen (const string& s, ENUM_TIMEFRAMES, int sh){ auto& b = ST(s); int i = gCur - sh; return (i >= 0 && i < (int)b.t.size()) ? b.o[i] : 0; }
inline double iHigh (const string& s, ENUM_TIMEFRAMES, int sh){ auto& b = ST(s); int i = gCur - sh; return (i >= 0 && i < (int)b.t.size()) ? b.h[i] : 0; }
inline double iLow  (const string& s, ENUM_TIMEFRAMES, int sh){ auto& b = ST(s); int i = gCur - sh; return (i >= 0 && i < (int)b.t.size()) ? b.l[i] : 0; }
inline double iClose(const string& s, ENUM_TIMEFRAMES, int sh){ auto& b = ST(s); int i = gCur - sh; return (i >= 0 && i < (int)b.t.size()) ? b.c[i] : 0; }
inline int iBarShift(const string& s, ENUM_TIMEFRAMES, datetime t, bool){ auto& b = ST(s); for (int sh = 0; sh <= gCur; sh++) if (b.t[gCur - sh] <= t) return sh; return -1; }
inline int iHighest(const string& s, ENUM_TIMEFRAMES, int, int count, int start){ int best = -1; double bv = -1e300; for (int k = start; k < start + count; k++){ double v = iHigh(s, PERIOD_H1, k); if (v > bv){ bv = v; best = k; } } return best; }
inline int iLowest(const string& s, ENUM_TIMEFRAMES, int, int count, int start){ int best = -1; double bv = 1e300; for (int k = start; k < start + count; k++){ double v = iLow(s, PERIOD_H1, k); if (v < bv){ bv = v; best = k; } } return best; }
inline void TimeToStruct(datetime t, MqlDateTime& m){
  time_t tt = (time_t)t; struct tm g; gmtime_r(&tt, &g);
  m.year = g.tm_year + 1900; m.mon = g.tm_mon + 1; m.day = g.tm_mday; m.hour = g.tm_hour; m.min = g.tm_min; m.sec = g.tm_sec; m.day_of_week = g.tm_wday; m.day_of_year = g.tm_yday;
}
inline std::vector<double> ewm(const std::vector<double>& x, double alpha){ std::vector<double> y(x.size(), NANV); double cur = NANV;
  for (size_t i = 0; i < x.size(); i++){ if (!std::isnan(x[i])) cur = std::isnan(cur) ? x[i] : alpha * x[i] + (1 - alpha) * cur; y[i] = cur; } return y; }
inline std::vector<double> trueRange(BarStore& b){ size_t n = b.t.size(); std::vector<double> tr(n);
  for (size_t i = 0; i < n; i++){ double a = b.h[i] - b.l[i]; if (i > 0){ a = std::max(a, std::fabs(b.h[i] - b.c[i-1])); a = std::max(a, std::fabs(b.l[i] - b.c[i-1])); } tr[i] = a; } return tr; }
inline int addInd(const std::string& s, const std::vector<double>& v){ gInd.push_back({s, v}); return (int)gInd.size() - 1; }
inline int iMA(const string& s, ENUM_TIMEFRAMES, int period, int, int, int){ return addInd(s, ewm(ST(s).c, 2.0 / (period + 1))); }
inline int iRSI(const string& s, ENUM_TIMEFRAMES, int period, int){ auto& b = ST(s); size_t n = b.c.size(); std::vector<double> up(n, NANV), dn(n, NANV);
  for (size_t i = 1; i < n; i++){ double d = b.c[i] - b.c[i-1]; up[i] = std::max(d, 0.0); dn[i] = std::max(-d, 0.0); }
  auto u = ewm(up, 1.0 / period), w = ewm(dn, 1.0 / period); std::vector<double> r(n, NANV);
  for (size_t i = 0; i < n; i++) if (!std::isnan(u[i]) && !std::isnan(w[i]) && w[i] != 0) r[i] = 100 - 100 / (1 + u[i] / w[i]);
  return addInd(s, r); }
inline int iATR(const string& s, ENUM_TIMEFRAMES, int period){ auto& b = ST(s); auto tr = trueRange(b); std::vector<double> a(tr.size(), NANV);
  for (size_t i = period - 1; i < tr.size(); i++){ double sum = 0; for (int k = 0; k < period; k++) sum += tr[i - k]; a[i] = sum / period; } return addInd(s, a); }
inline int iADX(const string& s, ENUM_TIMEFRAMES, int period){ auto& b = ST(s); size_t n = b.c.size(); double al = 1.0 / period; auto tr = trueRange(b); auto atrw = ewm(tr, al);
  std::vector<double> pdm(n, 0.0), mdm(n, 0.0);
  for (size_t i = 1; i < n; i++){ double up = b.h[i] - b.h[i-1], dn = -(b.l[i] - b.l[i-1]); pdm[i] = (up > dn && up > 0) ? up : 0.0; mdm[i] = (dn > up && dn > 0) ? dn : 0.0; }
  auto pe = ewm(pdm, al), me = ewm(mdm, al); std::vector<double> dx(n, NANV);
  for (size_t i = 0; i < n; i++){ double pdi = 100 * pe[i] / atrw[i], mdi = 100 * me[i] / atrw[i], sm = pdi + mdi; if (sm != 0 && !std::isnan(sm)) dx[i] = 100 * std::fabs(pdi - mdi) / sm; }
  return addInd(s, ewm(dx, al)); }
inline int CopyBuffer(int h, int, int start, int count, DArr& out){ out.v.clear(); auto& b = ST(gInd[h].sym);
  for (int k = 0; k < count; k++){ int i = gCur - start - k; if (i < 0 || i >= (int)b.t.size()) return -1; out.v.push_back(gInd[h].v[i]); } return count; }

template<class T> inline T cvt(T v){ return v; }
inline const char* cvt(const string& s){ return s.c_str(); }
template<class... A> inline string StringFormat(const char* fmt, A... a){ char b[1024]; snprintf(b, sizeof b, fmt, cvt(a)...); return string(std::string(b)); }
// ---- broker -------------------------------------------------------
inline datetime TimeCurrent(){ return (datetime)gNow; }
inline datetime TimeTradeServer(){ return (datetime)gNow; }
inline long MQLInfoInteger(int){ return 1; }  // pretend tester
inline double bidOf(const std::string& s){ return (gOvr && s == gOvrSym) ? gOvrBid : ST(s).o[gCur]; }
inline double spreadOf(const std::string& s){ double sp = gSpec[s].spread; return sp < 0 ? -sp * ST(s).o[gCur] : sp; }
inline double askOf(const std::string& s){ return bidOf(s) + spreadOf(s); }
inline double lossConv(const std::string& s, double price){ return gSpec[s].quoteUSD ? 1.0 : 1.0 / price; }
inline double floatingPL(){ double pl = 0; for (auto& p : gPos){ double px = p.type == 0 ? bidOf(p.sym) : askOf(p.sym);
  pl += (px - p.open) * (p.type == 0 ? 1 : -1) * p.vol * gSpec[p.sym].contract * lossConv(p.sym, px); } return pl; }
inline long AccountInfoInteger(int what){ return what == ACCOUNT_MARGIN_MODE ? 2 : 0; }
inline double AccountInfoDouble(int what){ if (what == ACCOUNT_MARGIN_LEVEL) return 0; if (what == ACCOUNT_BALANCE) return gBalance; if (what == ACCOUNT_EQUITY) return gBalance + floatingPL(); if (what == ACCOUNT_MARGIN_FREE) return 1e12; return 0; }
inline int PositionsTotal(){ return (int)gPos.size(); }
inline ulong PositionGetTicket(int i){ if (i < 0 || i >= (int)gPos.size()) return 0; gSel = i; return gPos[i].ticket; }
inline long PositionGetInteger(int w){ auto& p = gPos[gSel]; if (w == POSITION_MAGIC) return (long)p.magic; if (w == POSITION_TYPE) return p.type; if (w == POSITION_TIME) return p.time; return 0; }
inline double PositionGetDouble(int w){ auto& p = gPos[gSel]; if (w == POSITION_PROFIT) { double px = p.type == 0 ? bidOf(p.sym) : askOf(p.sym); return (px - p.open) * (p.type == 0 ? 1 : -1) * p.vol * gSpec[p.sym].contract * lossConv(p.sym, px); } if (w == POSITION_PRICE_OPEN) return p.open; if (w == POSITION_SL) return p.sl; if (w == POSITION_TP) return p.tp; if (w == POSITION_VOLUME) return p.vol; return 0; }
inline string PositionGetString(int w){ if (w == POSITION_SYMBOL) return string(gPos[gSel].sym); if (w == POSITION_COMMENT) return string(gPos[gSel].comment); return string(""); }
inline bool OrderCalcProfit(ENUM_ORDER_TYPE t, const string& s, double vol, double open, double close, double& profit){
  profit = (close - open) * (t == ORDER_TYPE_BUY ? 1 : -1) * vol * gSpec[std::string(s)].contract * lossConv(std::string(s), close); return true; }
inline bool OrderCalcMargin(ENUM_ORDER_TYPE, const string&, double, double, double& m){ m = 1.0; return true; }
inline bool HistorySelect(datetime a, datetime b){ gDealSel.clear(); for (size_t i = 0; i < gDeals.size(); i++) if (gDeals[i].time >= a && gDeals[i].time <= b) gDealSel.push_back((int)i); return true; }
inline int HistoryDealsTotal(){ return (int)gDealSel.size(); }
inline ulong HistoryDealGetTicket(int i){ return (ulong)gDealSel[i] + 1; }
inline long HistoryDealGetInteger(ulong tk, int w){ auto& d = gDeals[tk - 1]; return w == DEAL_MAGIC ? (long)d.magic : (w == DEAL_ENTRY ? d.entry : 0); }
inline double HistoryDealGetDouble(ulong tk, int w){ auto& d = gDeals[tk - 1]; return w == DEAL_PROFIT ? d.profit : (w == DEAL_SWAP ? d.swap : (w == DEAL_COMMISSION ? d.commission : 0)); }
inline string HistoryDealGetString(ulong tk, int w){ return w == DEAL_COMMENT ? string(gDeals[tk - 1].comment) : string(""); }
inline int GlobalVariablesTotal(){ return (int)gGV.size(); }
inline string GlobalVariableName(int i){ auto it = gGV.begin(); std::advance(it, i); return string(it->first); }
inline bool PositionSelectByTicket(ulong tk){ for (size_t i = 0; i < gPos.size(); i++) if (gPos[i].ticket == tk){ gSel = (int)i; return true; } return false; }
inline bool ObjectCreate(long, const string& n, int, int, datetime, double){ gObj[std::string(n)] = Obj{"", 0, 0, 0}; return true; }
inline int ObjectFind(long, const string& n){ return gObj.count(std::string(n)) ? 0 : -1; }
inline bool ObjectSetInteger(long, const string& n, int w, long v){ auto& o = gObj[std::string(n)]; if (w == OBJPROP_XDISTANCE) o.x = v; else if (w == OBJPROP_YDISTANCE) o.y = v; else if (w == OBJPROP_COLOR) o.color = v; return true; }
inline bool ObjectSetString(long, const string& n, int w, const string& v){ if (w == OBJPROP_TEXT) gObj[std::string(n)].text = std::string(v); return true; }
inline long ObjectGetInteger(long, const string& n, int w){ auto& o = gObj[std::string(n)]; return w == OBJPROP_COLOR ? o.color : 0; }
inline string ObjectGetString(long, const string& n, int w){ return w == OBJPROP_TEXT ? string(gObj[std::string(n)].text) : string(""); }
inline int ObjectsDeleteAll(long, const string& p){ std::string pre(p); for (auto it = gObj.begin(); it != gObj.end();) { if (it->first.rfind(pre, 0) == 0) it = gObj.erase(it); else ++it; } return 0; }
inline long StringToInteger(const string& s){ return atoll(std::string(s).c_str()); }
inline double StringToDouble(const string& s){ return atof(std::string(s).c_str()); }
inline string DoubleToString(double v, int d){ char b[64]; snprintf(b, sizeof b, "%.*f", d, v); return string(std::string(b)); }
inline string TimeToString(datetime t, int){ time_t tt = (time_t)t; struct tm g; gmtime_r(&tt, &g); char b[64]; strftime(b, sizeof b, "%Y.%m.%d %H:%M", &g); return string(std::string(b)); }
inline double SymbolInfoDouble(const string& s, int w){ auto& sp = gSpec[std::string(s)];
  if (w == SYMBOL_ASK) return askOf(std::string(s)); if (w == SYMBOL_BID) return bidOf(std::string(s)); if (w == SYMBOL_POINT) return sp.point;
  if (w == SYMBOL_VOLUME_MIN) return sp.minLot; if (w == SYMBOL_VOLUME_MAX) return sp.maxLot; if (w == SYMBOL_VOLUME_STEP) return sp.step; return 0; }
inline long SymbolInfoInteger(const string& s, int w){ if (w == SYMBOL_DIGITS) return gSpec[std::string(s)].digits; if (w == SYMBOL_TRADE_MODE) return SYMBOL_TRADE_MODE_FULL; return 0; }
inline bool GlobalVariableCheck(const string& k){ return gGV.count(std::string(k)) > 0; }
inline bool GlobalVariableSet(const string& k, double v){ gGV[std::string(k)] = v; return true; }
inline double GlobalVariableGet(const string& k){ return gGV[std::string(k)]; }
inline bool GlobalVariableDel(const string& k){ gGV.erase(std::string(k)); return true; }
inline int StringSplit(const string& s, unsigned short sep, std::vector<string>& out){ out.clear(); std::string cur;
  for (char c : std::string(s)){ if (c == (char)sep){ out.push_back(string(cur)); cur.clear(); } else cur += c; } out.push_back(string(cur)); return (int)out.size(); }
inline void StringTrimLeft(string& s){ std::string x = s; size_t i = x.find_first_not_of(" \t"); s = string(i == std::string::npos ? "" : x.substr(i)); }
inline void StringTrimRight(string& s){ std::string x = s; size_t i = x.find_last_not_of(" \t"); s = string(i == std::string::npos ? "" : x.substr(0, i + 1)); }

inline void closePos(size_t idx, double px){
  Pos p = gPos[idx]; double pnl = (px - p.open) * (p.type == 0 ? 1 : -1) * p.vol * gSpec[p.sym].contract * lossConv(p.sym, px);
  gBalance += pnl; gDeals.push_back({gNextTicket++, gNow, DEAL_ENTRY_OUT, pnl, 0, 0, p.magic, p.comment});
  double total = p.pnlAcc + pnl;
  gRecs.push_back({p.time, gNow, p.sym, p.type == 0 ? 1 : -1, p.open, px, total / p.riskUnit, total}); gPos.erase(gPos.begin() + idx); }
struct CTrade {
  ulong magic = 0;
  void SetExpertMagicNumber(ulong m){ magic = m; } bool SetTypeFillingBySymbol(const string&){ return true; } void SetDeviationInPoints(ulong){}
  bool open(int type, double vol, const string& sym, double sl, double tp, const std::string& cm){ std::string sy(sym); double px = type == 0 ? askOf(sy) : bidOf(sy);
    double lossPerLot = std::fabs((sl - px) * gSpec[sy].contract * lossConv(sy, sl)); double ru = vol * lossPerLot;
    if (cm.rfind("CTE2C", 0) == 0) { ulong parent = (ulong)atoll(cm.c_str() + 5); for (auto& q : gPos) if (q.ticket == parent) ru = q.riskUnit; }
    gPos.push_back({gNextTicket++, sy, type, vol, px, sl, tp, sl, gNow, magic, cm, ru, 0.0}); gDeals.push_back({gNextTicket++, gNow, DEAL_ENTRY_IN, 0, 0, 0, magic, cm}); return true; }
  bool Buy(double v, const string& s, double, double sl, double tp, const string& cm){ return open(0, v, s, sl, tp, std::string(cm)); }
  bool Sell(double v, const string& s, double, double sl, double tp, const string& cm){ return open(1, v, s, sl, tp, std::string(cm)); }
  bool PositionModify(ulong tk, double sl, double tp){ for (auto& p : gPos) if (p.ticket == tk){ if (getenv("DBG")) fprintf(stderr, "MODIFY t=%ld %s sl %.5f -> %.5f\n", gNow, p.sym.c_str(), p.sl, sl); p.sl = sl; p.tp = tp; return true; } return false; }
  bool PositionClose(ulong tk){ for (size_t i = 0; i < gPos.size(); i++) if (gPos[i].ticket == tk){ closePos(i, gPos[i].type == 0 ? bidOf(gPos[i].sym) : askOf(gPos[i].sym)); return true; } return false; }
  bool PositionClosePartial(ulong tk, double v){ for (auto& p : gPos) if (p.ticket == tk){ double px = p.type == 0 ? bidOf(p.sym) : askOf(p.sym);
      double pnl = (px - p.open) * (p.type == 0 ? 1 : -1) * v * gSpec[p.sym].contract * lossConv(p.sym, px); gBalance += pnl; p.pnlAcc += pnl; p.vol -= v;
      gDeals.push_back({gNextTicket++, gNow, DEAL_ENTRY_OUT, pnl, 0, 0, p.magic, p.comment}); return true; } return false; }
  uint ResultRetcode(){ return 0; } string ResultRetcodeDescription(){ return string(""); }
};
