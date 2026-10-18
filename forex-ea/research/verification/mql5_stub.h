#pragma once
#include <string>
#include <vector>
#include <cfloat>
#include <cmath>
#include <iostream>
#include <type_traits>
typedef long datetime;
struct string : std::string {
  string() {}
  string(const char* s) : std::string(s) {}
  string(const std::string& s) : std::string(s) {}
  template<class T, class = typename std::enable_if<std::is_arithmetic<T>::value>::type> string(T v) : std::string(std::to_string(v)) {}
};
inline string operator+(const string& a, const string& b){ return string(std::string(a)+std::string(b)); }
inline string operator+(const char* a, const string& b){ return string(std::string(a)+std::string(b)); }
inline string operator+(const string& a, const char* b){ return string(std::string(a)+std::string(b)); }
struct DArr { std::vector<double> v; double& operator[](int i){ return v[i]; } };
template<class... A> void Print(A...){}
template<class... A> void PrintFormat(const char*, A...){}
template<class... A> string StringFormat(const char*, A...){ return string(""); }
inline bool StringToUpper(string&){ return true; }
inline int StringFind(const string& s, const string& t){ auto p = s.find(t); return p==std::string::npos ? -1 : (int)p; }
template<class T,size_t N> int ArraySize(T(&)[N]){ return (int)N; }
inline void ArraySetAsSeries(DArr&, bool){}
#define INVALID_HANDLE (-1)
#define INIT_FAILED 1
#define INIT_SUCCEEDED 0
enum ENUM_TIMEFRAMES { PERIOD_CURRENT=0, PERIOD_M15=15, PERIOD_H1=60, PERIOD_H4=240, PERIOD_D1=1440 };
enum ENUM_ORDER_TYPE { ORDER_TYPE_BUY=0, ORDER_TYPE_SELL=1 };
enum ENUM_ACCOUNT_MARGIN_MODE { ACCOUNT_MARGIN_MODE_RETAIL_NETTING=0, ACCOUNT_MARGIN_MODE_EXCHANGE=1, ACCOUNT_MARGIN_MODE_RETAIL_HEDGING=2 };
enum { POSITION_TYPE_BUY=0, POSITION_TYPE_SELL=1 };
enum { POSITION_MAGIC, POSITION_TYPE, POSITION_TIME, POSITION_PRICE_OPEN, POSITION_SL, POSITION_TP, POSITION_VOLUME, POSITION_SYMBOL, POSITION_PROFIT, POSITION_SWAP, POSITION_COMMENT };
enum { ACCOUNT_EQUITY, ACCOUNT_BALANCE, ACCOUNT_MARGIN_FREE, ACCOUNT_MARGIN_MODE, ACCOUNT_MARGIN_LEVEL };
enum { SYMBOL_ASK, SYMBOL_BID, SYMBOL_VOLUME_MIN, SYMBOL_VOLUME_MAX, SYMBOL_VOLUME_STEP, SYMBOL_TRADE_STOPS_LEVEL, SYMBOL_TRADE_MODE };
enum { SYMBOL_TRADE_MODE_FULL=4 };
enum { DEAL_MAGIC, DEAL_ENTRY, DEAL_PROFIT, DEAL_SWAP, DEAL_COMMISSION, DEAL_COMMENT };
enum { DEAL_ENTRY_IN=0, DEAL_ENTRY_OUT=1, DEAL_ENTRY_INOUT=2, DEAL_ENTRY_OUT_BY=3 };
enum { MODE_EMA, MODE_HIGH, MODE_LOW };
enum { PRICE_CLOSE };
enum { MQL_TESTER, MQL_VISUAL_MODE };
struct MqlDateTime { int year, mon, day, hour, min, sec, day_of_week, day_of_year; };
inline void TimeToStruct(datetime, MqlDateTime&){}
extern string _Symbol; extern double _Point; extern int _Digits;
inline datetime TimeCurrent(){ return 0; } inline datetime TimeTradeServer(){ return 0; } inline datetime TimeGMT(){ return 0; }
inline uint GetTickCount(){ return 0; }
inline long MQLInfoInteger(int){ return 0; }
inline long AccountInfoInteger(int){ return 0; } inline double AccountInfoDouble(int){ return 0; }
inline int PositionsTotal(){ return 0; } inline ulong PositionGetTicket(int){ return 0; }
inline long PositionGetInteger(int){ return 0; } inline double PositionGetDouble(int){ return 0; } inline string PositionGetString(int){ return string(""); }
inline bool OrderCalcProfit(ENUM_ORDER_TYPE, const string&, double, double, double, double&){ return true; }
inline bool OrderCalcMargin(ENUM_ORDER_TYPE, const string&, double, double, double&){ return true; }
inline bool HistorySelect(datetime, datetime){ return true; } inline int HistoryDealsTotal(){ return 0; } inline ulong HistoryDealGetTicket(int){ return 0; }
inline long HistoryDealGetInteger(ulong,int){ return 0; } inline double HistoryDealGetDouble(ulong,int){ return 0; }
inline double SymbolInfoDouble(const string&, int){ return 0; } inline long SymbolInfoInteger(const string&, int){ return 0; }
inline bool GlobalVariableCheck(const string&){ return false; } inline bool GlobalVariableSet(const string&, double){ return true; } inline double GlobalVariableGet(const string&){ return 0; }
inline double iOpen(const string&, ENUM_TIMEFRAMES, int){ return 0; } inline double iClose(const string&, ENUM_TIMEFRAMES, int){ return 0; }
inline double iHigh(const string&, ENUM_TIMEFRAMES, int){ return 0; } inline double iLow(const string&, ENUM_TIMEFRAMES, int){ return 0; }
inline datetime iTime(const string&, ENUM_TIMEFRAMES, int){ return 0; } inline int iBarShift(const string&, ENUM_TIMEFRAMES, datetime, bool){ return 0; }
inline int iHighest(const string&, ENUM_TIMEFRAMES, int, int, int){ return 0; } inline int iLowest(const string&, ENUM_TIMEFRAMES, int, int, int){ return 0; }
inline int iMA(const string&, ENUM_TIMEFRAMES, int, int, int, int){ return 0; } inline int iADX(const string&, ENUM_TIMEFRAMES, int){ return 0; }
inline int iRSI(const string&, ENUM_TIMEFRAMES, int, int){ return 0; } inline int iATR(const string&, ENUM_TIMEFRAMES, int){ return 0; }
inline bool IndicatorRelease(int){ return true; }
inline int CopyBuffer(int, int, int, int, DArr&){ return 0; }
template<class T> string EnumToString(T){ return string(""); }
inline double NormalizeDouble(double v, int){ return v; }
template<class A,class B> typename std::common_type<A,B>::type MathMax(A a, B b){ return a>b?a:b; }
template<class A,class B> typename std::common_type<A,B>::type MathMin(A a, B b){ return a<b?a:b; }
inline double MathFloor(double v){ return std::floor(v); } inline double MathRound(double v){ return std::round(v); }
struct CTrade {
  void SetExpertMagicNumber(ulong){} bool SetTypeFillingBySymbol(const string&){ return true; } void SetDeviationInPoints(ulong){}
  bool Buy(double, const string&, double, double, double, const string&){ return true; } bool Sell(double, const string&, double, double, double, const string&){ return true; }
  bool PositionModify(ulong, double, double){ return true; } bool PositionClose(ulong){ return true; } bool PositionClosePartial(ulong, double){ return true; }
  uint ResultRetcode(){ return 0; } string ResultRetcodeDescription(){ return string(""); }
};
template<class T> int ArraySize(std::vector<T>& v){ return (int)v.size(); }
template<class T> int ArrayResize(std::vector<T>& v, int n){ v.resize(n); return n; }
inline int StringSplit(const string&, unsigned short, std::vector<string>&){ return 0; }
inline void StringTrimLeft(string&){} inline void StringTrimRight(string&){}
inline int StringLen(const string& s){ return (int)s.size(); }
inline bool EventSetTimer(int){ return true; } inline void EventKillTimer(){}
inline bool GlobalVariableDel(const string&){ return true; }
inline datetime TimeLocal(){ return 0; }
inline bool SymbolSelect(const string&, bool){ return true; }
enum { SYMBOL_POINT = 100, SYMBOL_DIGITS = 101 };

typedef unsigned int color;
inline color RGB(int r, int g, int b){ return (color)(r | (g << 8) | (b << 16)); }
inline string HistoryDealGetString(ulong, int){ return string(""); }
inline int GlobalVariablesTotal(){ return 0; } inline string GlobalVariableName(int){ return string(""); }
inline bool PositionSelectByTicket(ulong){ return false; }
enum { OBJ_LABEL, OBJ_RECTANGLE_LABEL };
enum { OBJPROP_CORNER, OBJPROP_ANCHOR, OBJPROP_SELECTABLE, OBJPROP_HIDDEN, OBJPROP_FONTSIZE, OBJPROP_FONT, OBJPROP_XDISTANCE, OBJPROP_YDISTANCE, OBJPROP_TEXT, OBJPROP_COLOR, OBJPROP_XSIZE, OBJPROP_YSIZE, OBJPROP_BGCOLOR, OBJPROP_BORDER_TYPE };
enum { CORNER_LEFT_UPPER, ANCHOR_LEFT_UPPER, BORDER_FLAT };
enum { TIME_DATE = 1, TIME_MINUTES = 2 };
inline bool ObjectCreate(long, const string&, int, int, datetime, double){ return true; }
inline int ObjectFind(long, const string&){ return -1; }
inline bool ObjectSetInteger(long, const string&, int, long){ return true; } inline bool ObjectSetString(long, const string&, int, const string&){ return true; }
inline long ObjectGetInteger(long, const string&, int){ return 0; } inline string ObjectGetString(long, const string&, int){ return string(""); }
inline int ObjectsDeleteAll(long, const string&){ return 0; } inline void ChartRedraw(long){}
inline long StringToInteger(const string&){ return 0; } inline double StringToDouble(const string&){ return 0; }
inline string StringSubstr(const string& s, int a, int b = -1){ return string(b < 0 ? s.substr(a) : s.substr(a, b)); }
inline string DoubleToString(double, int){ return string(""); } inline string TimeToString(datetime, int){ return string(""); }
enum { CALENDAR_IMPORTANCE_HIGH = 3 };
struct MqlCalendarValue { ulong id; ulong event_id; datetime time; };
struct MqlCalendarEvent { int importance; string name; };
inline int CalendarValueHistory(std::vector<MqlCalendarValue>&, datetime, datetime, const char*, const string&){ return 0; }
inline bool CalendarEventById(ulong, MqlCalendarEvent&){ return false; }

inline double MathAbs(double v){ return std::fabs(v); }
