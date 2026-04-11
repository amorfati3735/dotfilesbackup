#!/usr/bin/env python3
"""
Finance Dashboard - Monthly summary with trends and behavioural insights.
Run this to get your morning finance briefing.
"""

import sys
import re
from pathlib import Path
from collections import defaultdict
from datetime import datetime

try:
    import pdfplumber
except ImportError:
    print("Error: pdfplumber not installed")
    sys.exit(1)


def fmt(n):
    s = f"{n:.2f}".rstrip("0").rstrip(".")
    return s


ENTITY_ALIASES = {
    "Snehansh Tiwari": ["Snehansh", "sne", "snehans"],
    "Arunya Srivastava": ["Arunya", "ARUNYA", "Arun"],
    "Adarsh Kumar Singh": ["Adarsh", "ADARS", "adars", "Mr ADARS"],
    "Yasharth Gupta": ["YASHART", "Yashart", "YASHARTH"],
    "I Srinivasan": ["I Srinivasan", "SRINIVASAN", "I Sriniv"],
    "RHEMA Transport": ["RHEMA", "RHEMA TRANSPORT"],
    "Food Court": ["FOOD COURT", "FOOD COURT2", "Foodcourt"],
}


CATEGORY_PATTERNS = {
    "🍔 Food": [
        "food",
        "court",
        "restaurant",
        "mess",
        "biryani",
        "pizza",
        "burger",
        "cafe",
        "dosa",
    ],
    "🛒 Shopping": [
        "amazon",
        "flipkart",
        "shop",
        "store",
        "mart",
        "mall",
        "zudio",
        "reliance",
    ],
    "🚗 Transport": ["uber", "ola", "train", "metro", "travel", "irctc"],
    "📱 Recharge": ["airtel", "jio", "recharge", "mobile"],
    "🎓 Education": ["vit", "university", "fee", "college", "seminar"],
    "💊 Health": ["medical", "pharmacy", "hospital", "doctor"],
}


def categorize(entity):
    combined = (entity or "").lower()
    for cat, patterns in CATEGORY_PATTERNS.items():
        for p in patterns:
            if p in combined:
                return cat
    return "📦 Other"


def resolve_entity(raw):
    if not raw:
        return ""
    raw_upper = raw.upper()
    for canonical, aliases in ENTITY_ALIASES.items():
        for alias in aliases:
            if alias.upper() in raw_upper:
                return canonical
    return raw.strip()


def analyze_pdf(pdf_path, password=""):
    pdf = pdfplumber.open(pdf_path, password=password or None)
    tx = []

    for page in pdf.pages:
        for table in page.extract_tables():
            if not table or len(table) < 2:
                continue
            for row in table[1:]:
                if not row or len(row) < 6:
                    continue
                date_str = row[0]
                if not date_str or not re.match(r"\d{2}/\d{2}/\d{4}", str(date_str)):
                    continue

                try:
                    dt = datetime.strptime(str(date_str).strip(), "%d/%m/%Y")
                except:
                    continue

                debit = credit = 0.0
                debit_str = str(row[4]).strip() if row[4] else ""
                credit_str = str(row[5]).strip() if row[5] else ""

                if debit_str and debit_str != "-":
                    debit = float(debit_str.replace(",", ""))
                if credit_str and credit_str != "-":
                    credit = float(credit_str.replace(",", ""))

                if debit == 0 and credit == 0:
                    continue

                raw_desc = str(row[2]).replace("\n", " ") if row[2] else ""
                is_credit = (
                    "DEP TFR" in raw_desc.upper() or "UPI/CR/" in raw_desc.upper()
                )
                entity = resolve_entity(raw_desc)

                tx.append(
                    {
                        "date": dt,
                        "date_display": dt.strftime("%d-%b"),
                        "entity": entity,
                        "amount": max(debit, credit),
                        "kind": "received" if is_credit else "paid",
                    }
                )

    pdf.close()
    return tx


def build_dashboard():
    vault = Path("/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala")

    # Files to analyze
    files = [
        ("/home/pratik/Downloads/ac/AccountStatement_unlocked.pdf", ""),
    ]

    all_tx = []
    for pdf_path, password in files:
        try:
            tx = analyze_pdf(pdf_path, password)
            all_tx.extend(tx)
        except Exception as e:
            pass

    if not all_tx:
        print("No transactions found")
        return

    # Group by date
    by_date = defaultdict(list)
    for t in all_tx:
        by_date[t["date_display"]].append(t)

    # Calculate totals
    total_debit = sum(t["amount"] for t in all_tx if t["kind"] == "paid")
    total_credit = sum(t["amount"] for t in all_tx if t["kind"] == "received")

    # Top entities
    by_entity = defaultdict(lambda: {"total": 0, "count": 0})
    for t in all_tx:
        if t["kind"] == "paid":
            by_entity[t["entity"]]["total"] += t["amount"]
            by_entity[t["entity"]]["count"] += 1

    top_entities = sorted(by_entity.items(), key=lambda x: x[1]["total"], reverse=True)[
        :10
    ]

    # Categories
    by_category = defaultdict(lambda: {"total": 0, "count": 0})
    for t in all_tx:
        if t["kind"] == "paid":
            cat = categorize(t["entity"])
            by_category[cat]["total"] += t["amount"]
            by_category[cat]["count"] += 1

    # Friends analysis
    friends_total = sum(
        by_entity[e]["total"]
        for e, d in by_entity.items()
        if any(
            f.lower() in e.lower()
            for f in ["snehansh", "arunya", "adarsh", "yashart", "srinivasan"]
        )
    )

    # Impulse
    impulse = sum(
        t["amount"] for t in all_tx if t["kind"] == "paid" and t["amount"] < 40
    )

    # === BUILD REPORT ===
    print("=" * 50)
    print("🌅 GOOD MORNING - YOUR FINANCE BRIEFING")
    print("=" * 50)
    print(f"📅 {datetime.now().strftime('%d %b %Y')}")
    print("")

    print("💰 SPENDING SUMMARY")
    print(f"- This period: ₹{fmt(total_debit)} debited")
    print(f"- Received: ₹{fmt(total_credit)}")
    print(f"- Net outflow: ₹{fmt(total_debit - total_credit)}")
    print("")

    print("🏆 TOP SPENDS")
    for i, (entity, data) in enumerate(top_entities[:5], 1):
        medal = {1: "🥇", 2: "🥈", 3: "🥉"}.get(i, f"{i}")
        print(f"  {medal} {entity}: ₹{fmt(data['total'])} ({data['count']}x)")
    print("")

    print("📊 CATEGORY BREAKDOWN")
    for cat in sorted(by_category, key=lambda c: by_category[c]["total"], reverse=True):
        data = by_category[cat]
        pct = fmt(data["total"] / total_debit * 100)
        print(f"  {cat}: ₹{fmt(data['total'])} ({pct}%)")
    print("")

    print("🎯 BEHAVIOURAL INSIGHTS")
    if impulse > 200:
        print(
            f"- ⚠️ ImpulseZone: ₹{fmt(impulse)} in {len([t for t in all_tx if t['kind'] == 'paid' and t['amount'] < 40])} small purchases"
        )
    if friends_total / max(total_debit, 1) > 0.3:
        pct = fmt(friends_total / total_debit * 100)
        print(f"- 👥 FriendCircle: {pct}% goes to friends")
    print("")

    print("💡 QUICK WINS")
    if impulse > 200:
        print(f"  1. Cut impulse buys <₹40 - save ~₹{fmt(impulse * 0.3)}/month")
    if friends_total > 500:
        print(f"  2. Settle with friends - track who owes what")
    food_cat = by_category.get("🍔 Food", {}).get("total", 0)
    if food_cat > 500:
        print(f"  3. Food delivery: ₹{fmt(food_cat)} this month")
    print("")

    print("=" * 50)


if __name__ == "__main__":
    build_dashboard()
