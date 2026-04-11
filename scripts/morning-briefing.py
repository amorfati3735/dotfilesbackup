#!/usr/bin/env python3
"""
Morning Finance Briefing - Production Ready
Run: python3 ~/scripts/morning-briefing.py
"""

import pdfplumber
from collections import defaultdict
from datetime import datetime

# === CONFIG ===
PDF_PATH = "/home/pratik/Downloads/ac/AccountStatement_unlocked.pdf"
VAULT_PATH = "/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"

ENTITY_MAP = {
    "snehansh": "Snehansh Tiwari",
    "arunya": "Arunya Srivastava",
    "adarsh": "Adarsh Kumar Singh",
    "yashart": "Yasharth Gupta",
    "srinivasan": "I Srinivasan",
    "rhema": "RHEMA Transport",
    "food court": "Food Court",
    "airtel": "Airtel",
    "alphamericals": "ALPHAMERICALS",
}


def fmt(n):
    return f"₹{n:,.0f}"


def parse():
    pdf = pdfplumber.open(PDF_PATH)
    tx = []
    for page in pdf.pages:
        for table in page.extract_tables():
            if not table:
                continue
            for row in table[1:]:
                if not row or len(row) < 6:
                    continue
                try:
                    dt = datetime.strptime(str(row[0]).strip(), "%d/%m/%Y")
                except:
                    continue

                debit = (
                    float(str(row[4] or "0").replace(",", ""))
                    if str(row[4]).strip() != "-"
                    else 0
                )
                credit = (
                    float(str(row[5] or "0").replace(",", ""))
                    if str(row[5]).strip() != "-"
                    else 0
                )
                if debit == 0 and credit == 0:
                    continue

                raw = str(row[2]).replace("\n", " ")[:50] if row[2] else ""
                entity = raw
                for k, v in ENTITY_MAP.items():
                    if k in raw.lower():
                        entity = v

                tx.append(
                    {
                        "date": dt,
                        "date_str": dt.strftime("%d-%b"),
                        "entity": entity,
                        "amount": max(debit, credit),
                        "kind": "received" if "CR/" in raw else "paid",
                    }
                )
    pdf.close()
    return tx


def analyze():
    tx = parse()
    total = sum(t["amount"] for t in tx if t["kind"] == "paid")
    received = sum(t["amount"] for t in tx if t["kind"] == "received")
    active_days = len(set(t["date_str"] for t in tx))

    # Days in period
    first_date = min(t["date"] for t in tx)
    last_date = max(t["date"] for t in tx)
    period_days = (last_date - first_date).days + 1

    # Friend debts
    friend_txns = defaultdict(lambda: {"gave": [], "got": []})
    for t in tx:
        for f in ENTITY_MAP:
            if f in t["entity"].lower():
                if t["kind"] == "paid":
                    friend_txns[f]["gave"].append(t)
                else:
                    friend_txns[f]["got"].append(t)

    total_owed = sum(
        sum(d["gave"]) - sum(d["got"])
        for d in friend_txns.values()
        if sum(d["gave"]) > sum(d["got"])
    )

    # Day analysis
    by_day = defaultdict(lambda: {"total": 0, "count": 0})
    for t in tx:
        if t["kind"] == "paid":
            d = t["date"].strftime("%a")
            by_day[d]["total"] += t["amount"]
            by_day[d]["count"] += 1

    # Impulse
    impulse = sum(t["amount"] for t in tx if t["kind"] == "paid" and t["amount"] < 40)
    impulse_count = len([t for t in tx if t["kind"] == "paid" and t["amount"] < 40])

    # Big tickets
    big = [t for t in tx if t["kind"] == "paid" and t["amount"] > 200]
    big_total = sum(t["amount"] for t in big)

    # Projection
    daily_avg = total / active_days if active_days else 0
    projected_monthly = daily_avg * 30

    # Top spends
    top5 = sorted(
        [t for t in tx if t["kind"] == "paid"], key=lambda x: x["amount"], reverse=True
    )[:5]

    return {
        "total": total,
        "received": received,
        "net": total - received,
        "active_days": active_days,
        "period_days": period_days,
        "total_owed": total_owed,
        "by_day": by_day,
        "impulse": impulse,
        "impulse_count": impulse_count,
        "big_total": big_total,
        "big_count": len(big),
        "projected": projected_monthly,
        "daily_avg": daily_avg,
        "top5": top5,
        "tx": tx,
    }


def print_report(a):
    now = datetime.now().strftime("%d %b %Y")
    print(f"""
╔══════════════════════════════════════════════════════════════════╗
║                    🌅 MORNING FINANCE BRIEFING                   ║
║                         {now:^35}                    ║
╚══════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────┐
│ 💰 THE MONEY FLOW                                                │
├──────────────────────────────────────────────────────────────────┤
│  Spent:     {fmt(a["total"]):>15}   │  Received:  {fmt(a["received"]):>15}  │
│  Net out:   {fmt(a["net"]):>15}   │  Active:     {a["active_days"]:>3} days         │
│  Daily avg: {fmt(a["daily_avg"]):>15}   │  This period: {a["period_days"]} days         │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ 👥 WHO OWES YOU (FRIEND CIRCLE)                                  │
├──────────────────────────────────────────────────────────────────┤""")

    for f, name in [
        ("snehansh", "Snehansh Tiwari"),
        ("yashart", "Yasharth Gupta"),
        ("arunya", "Arunya Srivastava"),
        ("srinivasan", "I Srinivasan"),
    ]:
        gave = sum(
            t["amount"]
            for t in a["tx"]
            if f in t["entity"].lower() and t["kind"] == "paid"
        )
        got = sum(
            t["amount"]
            for t in a["tx"]
            if f in t["entity"].lower() and t["kind"] == "received"
        )
        net = gave - got
        if net > 0:
            print(f"│  {name:25} → {fmt(net):>12} (they owe)       │")

    print(f"├──────────────────────────────────────────────────────────────────┤")
    print(f"│  📌 TOTAL THEY OWE YOU:     {fmt(a['total_owed']):>20}          │")
    print(
        f"│     That's {a['total_owed'] / a['total'] * 100:.0f}% of your spending - request settlement!       │"
    )
    print("└──────────────────────────────────────────────────────────────────┘")

    print(f"""
┌──────────────────────────────────────────────────────────────────┐
│ 🧠 BEHAVIOR INSIGHTS                                             │
├──────────────────────────────────────────────────────────────────┤
│  🟴 Highest day: {max(a["by_day"], key=lambda x: a["by_day"][x][
            "total"
        ])} (₹{a["by_day"][max(a["by_day"], key=lambda x: a["by_day"][x][
                "total"
            ])]["total"]:,.0f})     │  🟢 Low: {min(a["by_day"], key=lambda x: a["by_day"][x]["total"] if a["by_day"][x]["total"] > 0 else 999)} (₹{a["by_day"][min(a["by_day"], key=lambda x: a["by_day"][x]["total"] if a["by_day"][x]["total"] > 0 else 999)]["total"]:,.0f})   │
│  ⚡ Impulse zone (<₹40): {fmt(a["impulse"])} in {a["impulse_count"]} buys  │
│  💎 Big tickets (>₹200): {fmt(a["big_total"])} in {a["big_count"]} transactions        │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ 📈 MONTH PROJECTION                                               │
├──────────────────────────────────────────────────────────────────┤
│  Current rate: {fmt(a["daily_avg"])}/day × 30 = {fmt(a["projected"])}/month      │
│  If trend continues, you'll spend ~₹{a["projected"]:,} this month          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ 🎯 TODAY'S ACTION ITEMS                                          │
├──────────────────────────────────────────────────────────────────┤
│  1. 📱 WhatsApp friends: "Let's settle - you owe me ₹{a["total_owed"]:,}"    │
│  2. 💸 Set UPI daily limit to ₹200 to stop impulse buys           │
│  3. 🔍 Review big tickets: {a["big_count"]} transactions = ₹{a["big_total"]:,}                     │
│  4. 🍔 Food spending: Check if Food Court is a regular habit       │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│ 🏆 TOP 5 SPENDS THIS MONTH                                        │
├──────────────────────────────────────────────────────────────────┤""")

    for i, t in enumerate(a["top5"], 1):
        medal = "🥇" if i == 1 else "🥈" if i == 2 else "🥉" if i == 3 else f" {i}. "
        print(f"│  {medal} {fmt(t['amount']):>8} → {t['entity'][:28]:<30}│")
        print(f"│      {t['date_str']:<50}        │")

    print("└──────────────────────────────────────────────────────────────────┘")


if __name__ == "__main__":
    a = analyze()
    print_report(a)
