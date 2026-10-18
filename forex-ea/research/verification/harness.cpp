#include "mql5_sim.h"
std::map<std::string, BarStore> gStore; std::map<std::string, SymSpec> gSpec; std::vector<IndStore> gInd;
std::vector<Pos> gPos; std::vector<Deal> gDeals; std::vector<int> gDealSel; std::vector<TradeRec> gRecs; std::map<std::string, double> gGV; std::map<std::string, Obj> gObj; bool gOvr = false; std::string gOvrSym; double gOvrBid = 0;
int gCur = 0, gSel = -1; long gNow = 0; double gBalance = 10000; ulong gNextTicket = 1;
string _Symbol("EURUSD"); double _Point = 0.00001; int _Digits = 5;
#include "ea_body.inc"
static void dumpDashboard(){
  std::map<long, std::map<long, std::string>> rows;
  for (auto& kv : gObj) if (kv.first.rfind("CTE_D_", 0) == 0 && !kv.second.text.empty()) rows[kv.second.y][kv.second.x] = kv.second.text;
  for (auto& r : rows){ std::string line; long col = 0; for (auto& c : r.second){ long target = c.first / 7; while (col < target) { line += ' '; col++; } line += c.second; col += (long)c.second.size(); } std::cout << line << "\n"; }
}
static bool loadBars(const std::string& sym, const std::string& file){
  std::ifstream in(file); if (!in) return false; std::string line; auto& b = gStore[sym];
  while (std::getline(in, line)){ std::stringstream ss(line); std::string a; std::vector<double> v; while (std::getline(ss, a, ',')) v.push_back(std::stod(a));
    b.t.push_back((long)v[0]); b.o.push_back(v[1]); b.h.push_back(v[2]); b.l.push_back(v[3]); b.c.push_back(v[4]); }
  return true; }
int main(int argc, char** argv){
  // args: outfile  sym:file:contract:spread:digits:quoteUSD ...   (list in InpSymbols order)
  std::string out = argv[1]; std::string symlist; int n = 0;
  for (int i = 2; i < argc; i++){ std::string a = argv[i]; std::vector<std::string> p; std::stringstream ss(a); std::string x; while (std::getline(ss, x, ':')) p.push_back(x);
    if (!loadBars(p[0], p[1])) { std::cerr << "load fail " << p[0] << "\n"; return 2; }
    SymSpec sp; sp.contract = std::stod(p[2]); sp.spread = std::stod(p[3]); sp.digits = std::stoi(p[4]); sp.quoteUSD = p[5] == "1";
    sp.point = std::pow(10.0, -sp.digits); sp.minLot = getenv("HEALTHDEMO") ? 0.01 : 0.0001; sp.maxLot = 1e6; sp.step = getenv("HEALTHDEMO") ? 0.01 : 0.0001; gSpec[p[0]] = sp;
    symlist += (n++ ? "," : "") + p[0]; }
  InpSymbols = string(" " + symlist + " ,, ");   // exercise the trimming / empty-entry handling
  InpBrokerGMTOffset = 0.0; InpLotMode = LOT_RISK_PERCENT; InpRiskPercent = 1.0; InpMaxRiskPerTradePct = 5.0;
  InpProfitTargetUSD = 1e12; InpStopAtProfitTarget = false; if (!getenv("CAPS")) { InpDailyLossPct = 1.4; InpMaxPositionsTotal = 99; InpMaxOpenRiskPct = 1000.0; }
  if (getenv("COUNTER")) { InpCounterEnabled = true; }
  size_t N = gStore.begin()->second.t.size();
  for (auto& kv : gStore) if (kv.second.t.size() != N || kv.second.t[0] != gStore.begin()->second.t[0]) { std::cerr << "symbol bars not aligned\n"; return 3; }
  gCur = (int)N - 1; gNow = gStore.begin()->second.t[gCur];
  if (getenv("BAL")) gBalance = atof(getenv("BAL"));
  if (OnInit() != INIT_SUCCEEDED) { std::cerr << "OnInit failed\n"; return 4; }
  std::cerr << "active symbols: " << ArraySize(gS) << "  hedging max/symbol=" << gMaxPosSym << "\n";
  size_t maxOpen = 0; int maxEntriesDay = 0; bool dumped = false;
  for (int cur = 260; cur < (int)N; cur++){
    gCur = cur; gNow = gStore.begin()->second.t[cur];
    RunAll();
    maxOpen = std::max(maxOpen, gPos.size());
    // intrabar processing, pessimistic: stop before anything else; sells use ask = price + spread
    for (size_t k = 0; k < gPos.size();){
      Pos& p = gPos[k]; auto& b = gStore[p.sym]; double sp = spreadOf(p.sym); bool stopped = false; double px = 0;
      if (p.type == 0){ if (b.l[cur] <= p.sl){ stopped = true; px = (b.o[cur] > p.sl) ? p.sl : b.o[cur]; } }
      else { double adv = b.h[cur] + sp; if (adv >= p.sl){ stopped = true; double opx = b.o[cur] + sp; px = (opx < p.sl) ? p.sl : opx; } }
      if (stopped) { closePos(k, px); continue; }
      // counter TP1 (EA-managed): emulate the tick that reaches the level, then TP2 as a resting order
      if (p.comment.rfind("CTE2C", 0) == 0) {
        std::string key = "CTE_T1_" + std::to_string(p.ticket);
        if (gGV.count(key) && gGV[key] > 0) {
          double lvl = gGV[key]; bool hit = p.type == 0 ? (b.h[cur] >= lvl) : (b.l[cur] + sp <= lvl);
          if (hit) { gOvr = true; gOvrSym = p.sym; gOvrBid = (p.type == 0) ? lvl : lvl - sp; ManageCounterTP1(); gOvr = false; }
        }
      }
      Pos& q = gPos[k];
      if (q.tp > 0) { bool tphit = q.type == 0 ? (b.h[cur] >= q.tp) : (b.l[cur] + sp <= q.tp); if (tphit) { closePos(k, q.tp); continue; } }
      k++;
    }
    if (getenv("DUMPAT") && !dumped && gPos.size() >= (size_t)atoi(getenv("DUMPAT"))) { UpdateDashboard(); std::cout << "---- dashboard at " << gNow << " ----\n"; dumpDashboard(); dumped = true; }
  }
  for (size_t k = 0; k < gPos.size();) closePos(k, gPos[k].type == 0 ? bidOf(gPos[k].sym) : askOf(gPos[k].sym));
  if (getenv("DUMPEND")) { UpdateDashboard(); std::cout << "---- dashboard at end ----\n"; dumpDashboard(); }
  std::ofstream o(out); o << "sym,t0,t1,dir,open,exit,R\n";
  for (auto& r : gRecs) o << r.sym << "," << r.t0 << "," << r.t1 << "," << r.dir << "," << r.open << "," << r.exitPx << "," << r.R << "\n";
  std::cerr << "trades=" << gRecs.size() << " finalBalance=" << gBalance << " maxSimultaneousPositions=" << maxOpen << "\n";
  if (getenv("PREVIEW")) { for (int i = 0; i < ArraySize(gS); i++) SizingPreview(gS[i]); }
  OnDeinit(0);
  return 0;
}
