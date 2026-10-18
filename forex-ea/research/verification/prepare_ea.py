"""Turn ConfirmedTrendEA.mq5 into C++ that compiles against mql5_stub.h / mql5_sim.h.

Usage:  python3 prepare_ea.py ../../ConfirmedTrendEA.mq5 > ea_body.inc
        g++ -std=c++17 -O1 -w -o harness harness.cpp
        ./harness out.csv "BTCUSD:bars.csv:1:-0.0003:2:1"

bars.csv rows are: epoch_seconds,open,high,low,close (hourly, UTC).
Symbol spec is name:file:contract_size:spread:digits:quote_is_usd; a negative spread is a fraction of price.
The shim only mirrors MetaTrader's behaviour as I understand it. It is not MetaTrader.
"""
import re, sys

src = open(sys.argv[1]).read()
out = []
for line in src.splitlines():
    t = line.strip()
    if t.startswith(("#property", "#include", "input group")):
        continue
    if t.startswith("input "):
        line = line.replace("input ", "", 1)
    out.append(line)
body = "\n".join(out)
body = re.sub(r"C'(\d+),(\d+),(\d+)'", r"RGB(\1,\2,\3)", body)
swaps = [("double f[], sl[], a[];", "DArr f, sl, a;"), ("double a[], b[];", "DArr a, b;"), ("double a[];", "DArr a;"),
         ("double e20[], e50[], rs[], at[];", "DArr e20, e50, rs, at;"), ("double at[];", "DArr at;"), ("double atrNow[];", "DArr atrNow;"),
         ("SymState gS[];", "std::vector<SymState> gS;"), ("string names[];", "std::vector<string> names;"),
         ("string parts[];", "std::vector<string> parts;"), ("ulong  cTk[];", "std::vector<ulong> cTk;"),
         ("long   cType[];", "std::vector<long> cType;"), ("double cVol[];", "std::vector<double> cVol;"),
         ("double cOpen[];", "std::vector<double> cOpen;"), ("string cur[];", "std::vector<string> cur;"),
         ("MqlCalendarValue vals[];", "std::vector<MqlCalendarValue> vals;")]
for a, b in swaps:
    body = body.replace(a, b)
print(body)
