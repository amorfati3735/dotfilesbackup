#!/usr/bin/env bash
# Deep Morning Finance Analysis
# Run: bash ~/scripts/deep-analysis.sh

~/scripts/.bank-venv/bin/python3 << 'ENDOFSCRIPT'
import pdfplumber
from collections import defaultdict
from datetime import datetime

pdf = pdfplumber.open("/home/pratik/Downloads/ac/AccountStatement_unlocked.pdf")
tx = []

ENTITY = {"snehansh": "Snehansh Tiwari", "arunya": "Arunya Srivastava", 
         "adarsh": "Adarsh Kumar Singh", "yashart": "Yasharth Gupta", "srinivasan": "I Srinivasan"}

for page in pdf.pages:
    for table in page.extract_tables():
        if not table: continue
        for row in table[1:]:
            if not row or len(row) < 6: continue
            try:
                dt = datetime.strptime(str(row[0]).strip(), "%d/%m/%Y")
            except: continue
            
            debit = float(str(row[4] or "0").replace(",", "")) if str(row[4]).strip() != "-" else 0
            credit = float(str(row[5] or "0").replace(",", "")) if str(row[5]).strip() != "-" else 0
            if debit == 0 and credit == 0: continue
            
            raw = str(row[2]).replace("\n", " ")[:50] if row[2] else ""
            entity = raw
            for k, v in ENTITY.items():
                if k in raw.lower(): entity = v
            
            tx.append({"date": dt, "entity": entity, "amount": max(debit,credit), "kind": "received" if "CR/" in raw else "paid"})

pdf.close()

print("=" * 70)
print("DEEP ANALYSIS - YOUR MONEY STORY")
print("=" * 70)

# RECIPROCITY
friend_txns = defaultdict(lambda: {"gave": [], "got": []})
for t in tx:
    for f in ENTITY:
        if f in t["entity"].lower():
            if t["kind"] == "paid": friend_txns[f]["gave"].append(t)
            else: friend_txns[f]["got"].append(t)

name_map = {"snehansh": "Snehansh Tiwari", "arunya": "Arunya Srivastava", 
           "adarsh": "Adarsh Kumar Singh", "yashart": "Yasharth Gupta", "srinivasan": "I Srinivasan"}

print("\nDEBTS:")
total_owe = 0
for f, d in friend_txns.items():
    gave = sum(t["amount"] for t in d["gave"])
    got = sum(t["amount"] for t in d["got"])
    net = gave - got
    if net > 0:
        total_owe += net
        print(f"  {name_map[f]}: owed Rs{net:.0f}")

print(f"\nTotal owed TO YOU: Rs{total_owe:.0f}")

# BY DAY
by_day = defaultdict(lambda: {"total": 0, "count": 0})
for t in tx:
    if t["kind"] == "paid":
        d = t["date"].strftime("%a")
        by_day[d]["total"] += t["amount"]
        by_day[d]["count"] += 1

print("\nSPENDING BY DAY:")
for day in ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]:
    if day in by_day:
        x = by_day[day]
        print(f"  {day}: Rs{x['total']:.0f} ({x['count']} txns)")

# TOP
total = sum(t["amount"] for t in tx if t["kind"] == "paid")
print(f"\nTOTAL: Rs{total:.0f}")
print(f"YOU ARE OWED: Rs{total_owe:.0f}")

paid = sorted([t for t in tx if t["kind"] == "paid"], key=lambda x: x["amount"], reverse=True)[:5]
print("\nTOP SPENDS:")
for i, t in enumerate(paid, 1):
    print(f"  {i}. Rs{t['amount']:.0f} - {t['entity'][:20]}")
ENDOFSCRIPT