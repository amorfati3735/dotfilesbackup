#!/usr/bin/env python3
"""
bank-parse-v2.py — Enhanced bank statement parser with behavioural insights.
Forked from bank-parse.py with major improvements.

Key Features:
- pdfplumber for proper table extraction (SBI)
- Entity name resolution (unifies GPay + SBI names)
- Behavioural psychology insights
- Category recommendations
- Month-over-month progress tracking

Usage:  python3 bank-parse-v2.py <pdf_path> [password]
Outputs markdown to stdout.
"""

import re
import sys
import subprocess
import json
from pathlib import Path
from collections import defaultdict, OrderedDict
from datetime import datetime

try:
    import pdfplumber
except ImportError:
    print(
        "Error: pdfplumber not installed. Run: pip install pdfplumber", file=sys.stderr
    )
    sys.exit(1)


# ── Helpers ──────────────────────────────────────────────────


def fmt(n: float) -> str:
    """Format a number: no trailing zeros, no trailing dot."""
    s = f"{n:.2f}".rstrip("0").rstrip(".")
    return s


MONTH_MAP = {
    "Jan": "01",
    "Feb": "02",
    "Mar": "03",
    "Apr": "04",
    "May": "05",
    "Jun": "06",
    "Jul": "07",
    "Aug": "08",
    "Sep": "09",
    "Oct": "10",
    "Nov": "11",
    "Dec": "12",
}
MONTH_ABBR = {v: k for k, v in MONTH_MAP.items()}


def parse_date_sbi(s: str) -> datetime:
    """Parse dd/mm/yyyy"""
    return datetime.strptime(s.strip(), "%d/%m/%Y")


# ── Entity Resolution (The Game Changer) ────────────────────────────

# Known entity aliases - maps variations to canonical names
# Format: canonical_name -> [alias1, alias2, ...]
ENTITY_ALIASES = {
    "Snehansh Tiwari": ["Snehansh", "SN ehansh", "Sne hansh", "sne hansk", "snehans"],
    "Arunya Srivastava": ["Arunya", "ARUNYA", "Arun ya"],
    "Adarsh Kumar Singh": ["Adarsh", "ADARS", "Mr ADARS", "adars"],
    "Yasharth Gupta": ["YASHART", "Yashart", "YASHARTH", "yashart"],
    "I Srinivasan": ["I Srinivasan", "I Sriniv", "ISrinivasan", "SRINIVASAN"],
    "RHEMA Transport": ["RHEMA", "RHEMA TRANSPORT", "Rhema", "Rhe ma"],
    "SIVA STORE": ["SIVA", "Siva", "SIVA STORE"],
    "Food Court": ["FOOD COURT", "FOOD COURT2", "Foodcourt", "Food Court"],
    "Airtel": ["AIRTEL", "Airtel", "Bharti Hexacom", "BHARTI HEXACOM"],
    "McDonald's": ["MC DONALDS", "McDonalds", "MCDONALD", "Mc Donald"],
    "The Street Bites": ["THE STREET BITES", "Street Bites", "STREET BITES"],
    "Thilagavathi Iyyapan": ["THILAGAVATHI", "THILAGAV", "Tilaga", "Thilagavathi Iy"],
    "Muththagam": ["MUTHTHA", "MUTHTHAGAM", "Muththa"],
}


def resolve_entity(raw_name: str) -> str:
    """Resolve entity to canonical name."""
    if not raw_name:
        return ""

    raw_upper = raw_name.upper()
    raw_lower = raw_name.lower()

    # Direct match
    for canonical, aliases in ENTITY_ALIASES.items():
        for alias in aliases:
            if alias.upper() in raw_upper or alias.lower() in raw_lower:
                return canonical

    # UPI pattern: extract from UPI/DR/.../ENTITY/...
    upi_match = re.search(r"UPI/(?:DR|CR)/\d+/([^/]+)/", raw_name)
    if upi_match:
        potential = upi_match.group(1).strip()
        # Clean up: split on / or get first part
        potential = potential.split("/")[0].strip()
        if potential:
            return potential

    return raw_name.strip()


# ── Category Intelligence ──────────────────────────────────────

CATEGORY_PATTERNS = {
    "🍔 Food & Dining": [
        "food",
        "court",
        "restaurant",
        "eat",
        "biryani",
        "kitchen",
        "mess",
        "canteen",
        "pizza",
        "burger",
        "mcdonald",
        "domino",
        "zomato",
        "swiggy",
        "cafe",
        "coffee",
        "tea",
        "dosa",
        "idli",
        "parotta",
        "tiffin",
        "hotel",
        "street bites",
        "street",
        "dhabba",
        "dhaba",
    ],
    "🛒 Shopping": [
        "amazon",
        "flipkart",
        "shop",
        "store",
        "mart",
        "mall",
        "forum",
        "zudio",
        "reliance",
        " Trends",
        "max",
        "pantaloons",
        "westside",
        "shoppers",
    ],
    "🚗 Transport": [
        "uber",
        "ola",
        "train",
        "irctc",
        "travel",
        "railway",
        "metro",
        "bus",
        "taxi",
        "auto",
        "cab",
        "flight",
        "ticket",
        "reservation",
    ],
    "📱 Recharge & Bills": [
        "airtel",
        "jio",
        "vodafone",
        "recharge",
        "mobile",
        "prepaid",
        "electricity",
        "bill",
        "water",
        "gas",
        "rent",
        "society",
    ],
    "🎓 Education": [
        "vit",
        "university",
        "college",
        "fee",
        "seminar",
        "workshop",
        "research",
        "course",
        "certificate",
        "exam",
        "library",
    ],
    "💊 Health & Pharma": [
        "medical",
        "pharmacy",
        "medicine",
        "hospital",
        "clinic",
        "doctor",
        "health",
        "wellness",
        "pathlab",
        "diagnostic",
    ],
    "🎬 Entertainment": [
        "netflix",
        "hotstar",
        "prime",
        "youtube",
        "spotify",
        " OTT",
        "movie",
        "cinema",
        "theatre",
        "concert",
        "event",
    ],
    "💳 Wallet Top-up": [
        "top-up",
        "topup",
        "wallet",
        "gpay",
        "phonepe",
        "paytm",
        "amazon pay",
        "freecharge",
    ],
}


def categorize_entity(entity: str, note: str = "") -> str:
    """Categorize transaction based on entity + note."""
    combined = f"{entity or ''} {note or ''}".lower()

    if not combined.strip():
        return "📦 Other"

    for category, patterns in CATEGORY_PATTERNS.items():
        for pattern in patterns:
            if pattern.lower() in combined:
                return category

    return "📦 Other"


def categorize_amount(amount: float, category: str) -> tuple[str, str]:
    """Determine if purchase is impulsive (<₹40) or planned."""
    if amount < 40 and category != "💳 Wallet Top-up":
        return "impulsive", "Yes"
    return "planned", "No"


# ── Behavioural Insights ────────────────────────────────────────────

BEHAVIOURAL_INSIGHTS = {
    "small_frequent": {
        "name": "Small Frequent Spender",
        "trigger": "Many transactions under ₹40",
        "psych": "Impulse buying driven by convenience and frictionless payments. The Rs.20 here, Rs.30 there adds up silently.",
        "fix": "Use UPI locked savings or remove from quick-access wallet.",
    },
    "friend_circles": {
        "name": "Social Circle Drain",
        "trigger": "High frequency to same friends",
        "psych": "Social obligations feel like transactions. Friends owe you but you pay first - creates silent resentment.",
        "fix": "Settle monthly via dedicated group split app or cash rounds.",
    },
    "food_focus": {
        "name": "Food-First Mindset",
        "trigger": "Food category >30% of spending",
        "psych": "Comfort eating or convenience-driven. Food delivery creates short dopamine hits.",
        "fix": "Cook 3 days/week, batch prep, or set delivery limits.",
    },
    "recharge_addiction": {
        "name": "Data Anxiety",
        "trigger": "Multiple small recharges",
        "psych": "Fear of running out drives over-buffering. You pay for data you don't use.",
        "fix": "Track actual usage, switch to annual plans with auto-debit.",
    },
}


def get_behavioural_patterns(tx: list) -> dict:
    """Analyze spending patterns and return behavioural insights."""
    insights = {}

    # Count small transactions
    small_count = sum(
        1 for t in tx if t.get("kind") == "paid" and t.get("amount", 0) < 40
    )
    total_paid = sum(t.get("amount", 0) for t in tx if t.get("kind") == "paid")

    if small_count > 10 and small_count / max(len(tx), 1) > 0.3:
        insights["small_frequent"] = {
            "metric": f"{small_count} transactions under ₹40",
            "total": fmt(small_count * 30),  # avg estimate
            **BEHAVIOURAL_INSIGHTS["small_frequent"],
        }

    # Check friend spending
    friends = {
        "Snehansh Tiwari": 0,
        "Arunya Srivastava": 0,
        "Adarsh Kumar Singh": 0,
        "Yasharth Gupta": 0,
    }
    for t in tx:
        ent = t.get("entity", "")
        for friend in friends:
            if friend.lower() in ent.lower():
                friends[friend] += t.get("amount", 0)

    friend_total = sum(friends.values())
    if friend_total > 0 and friend_total / max(total_paid, 1) > 0.2:
        top_friend = max(friends, key=friends.get)
        insights["friend_circles"] = {
            "metric": f"₹{fmt(friend_total)} to friends ({fmt(friend_total / max(total_paid, 1) * 100)}%)",
            "top_friend": top_friend,
            "total": fmt(friend_total),
            **BEHAVIOURAL_INSIGHTS["friend_circles"],
        }

    return insights


# ── PDF extraction with pdfplumber (SBI) ───────────────────────


def extract_tables_sbi(pdf_path: str, password: str = "") -> list:
    """Extract transaction tables using pdfplumber."""
    pdf = pdfplumber.open(pdf_path, password=password or None)
    transactions = []

    for page in pdf.pages:
        tables = page.extract_tables()
        for table in tables:
            if not table or len(table) < 2:
                continue

            # Skip header rows
            for row in table[1:]:
                if not row or len(row) < 6:
                    continue

                # Column structure: [date, date, description, -, debit, credit, balance]
                date_str = row[0]
                if not date_str or not re.match(r"\d{2}/\d{2}/\d{4}", str(date_str)):
                    continue

                try:
                    dt = parse_date_sbi(str(date_str))
                except:
                    continue

                # Parse amounts - handle dashes and commas
                debit = 0.0
                credit = 0.0

                debit_str = str(row[4]).strip() if row[4] else ""
                credit_str = str(row[5]).strip() if row[5] else ""

                if debit_str and debit_str != "-":
                    debit = float(debit_str.replace(",", ""))
                if credit_str and credit_str != "-":
                    credit = float(credit_str.replace(",", ""))

                if debit == 0 and credit == 0:
                    continue

                # Parse description
                raw_desc = str(row[2]).replace("\n", " ") if row[2] else ""

                is_credit = (
                    "DEP TFR" in raw_desc.upper() or "UPI/CR/" in raw_desc.upper()
                )

                # Extract entity
                entity = resolve_entity(raw_desc)
                note = ""

                # Extract more details
                upi_match = re.search(r"UPI/(?:DR|CR)/\d+/([^/]+)/([A-Z]+)/", raw_desc)
                if upi_match:
                    note = upi_match.group(2)

                transactions.append(
                    {
                        "date_full": dt.strftime("%d %b, %Y"),
                        "date_display": dt.strftime("%d-%b"),
                        "date_sort": dt.strftime("%Y%m%d"),
                        "time": "",
                        "kind": "received" if is_credit else "paid",
                        "entity": entity,
                        "amount": max(debit, credit),
                        "reason": note,
                    }
                )

    pdf.close()
    return transactions


# Legacy GPay parser (kept for backward compatibility)


def extract_text(pdf_path: str, password: str = "") -> str:
    """Extract text using pdftotext (for GPay)."""
    cmd = ["pdftotext", "-layout"]
    if password:
        cmd += ["-upw", password]
    cmd += [pdf_path, "-"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"pdftotext error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout


def detect_type(text: str) -> str:
    """Detect if SBI or GPay statement."""
    if "State Bank of India" in text or "SBIN" in text or "UPI/DR/" in text:
        return "sbi"
    if "Paid to" in text or "Received from" in text or "Google Pay" in text:
        return "gpay"
    return "gpay"


# ── Group adjustment (reimburse logic) ─────────────────────────


def apply_group_adjustment(tx: list) -> list:
    """If someone pays you >50 in a day, offset their largest debit that day."""
    by_date = defaultdict(list)
    for t in tx:
        by_date[t["date_display"]].append(t)

    for date, items in by_date.items():
        reimburse = sum(
            t["amount"] for t in items if t["kind"] == "received" and t["amount"] > 50
        )
        if reimburse == 0:
            continue

        paid_items = [t for t in items if t["kind"] == "paid"]
        if not paid_items:
            continue

        largest = max(paid_items, key=lambda t: t["amount"])
        original = largest["amount"]
        adjusted = original - reimburse
        largest["amount"] = max(adjusted, 0)
        largest["reason"] = "group-adjusted"

    return tx


# ── Build improved markdown ─────────────────────────────────────


def build_markdown(tx: list, source_type: str, filename: str) -> str:
    """Build markdown with behavioural insights."""
    md = []

    # Header
    months = sorted({t["date_display"].split("-")[1] for t in tx})
    years = sorted({t["date_full"].split(", ")[-1].strip() for t in tx})
    month_str = ", ".join(months)
    year_str = years[0] if years else ""
    bank = "SBI" if source_type == "sbi" else "GPay"

    md.append("---")
    md.append(f"tags: [finance, {bank.lower()}, bank-statement, v2]")
    md.append(f'source: "{filename}"')
    md.append(f"bank: {bank}")
    md.append(f'period: "{month_str} {year_str}"')
    md.append("---")
    md.append("")
    md.append(f"# {bank} — {month_str} {year_str}")
    md.append("")

    # ── 1. DAILY SPENDING TABLE ──
    md.append("## Daily spending")
    md.append("")
    md.append("| Date | Entity | ₹ Debit | ₹ Credit | Day Total |")
    md.append("|------|--------|---------|----------|-----------|")

    by_date = OrderedDict()
    for t in sorted(tx, key=lambda x: x["date_sort"]):
        by_date.setdefault(t["date_display"], []).append(t)

    grand_debit = 0
    grand_credit = 0

    for date, items in by_date.items():
        day_debits = []
        day_credits = []
        first = True

        for t in items:
            entity = t["entity"] or "—"
            note = f" *({t['reason']})*" if t.get("reason") else ""

            if t["kind"] == "paid":
                day_debits.append(t["amount"])
                grand_debit += t["amount"]
                debit_cell = fmt(t["amount"])
                credit_cell = ""
            elif t["kind"] == "received":
                day_credits.append(t["amount"])
                grand_credit += t["amount"]
                debit_cell = ""
                credit_cell = fmt(t["amount"])
            else:
                day_debits.append(t["amount"])
                grand_debit += t["amount"]
                debit_cell = fmt(t["amount"])
                credit_cell = ""

            date_cell = f"**{date}**" if first else ""
            md.append(
                f"| {date_cell} | {entity}{note} | {debit_cell} | {credit_cell} | |"
            )
            first = False

        # Day summary
        if len(day_debits) > 1:
            expr = "+".join(fmt(d) for d in day_debits)
            day_total = f"💸 {expr} = **{fmt(sum(day_debits))}**"
        elif len(day_debits) == 1:
            day_total = f"💸 **{fmt(day_debits[0])}**"
        else:
            day_total = "—"

        if day_credits:
            cr_sum = sum(day_credits)
            day_total += f" ┃ 💰 +{fmt(cr_sum)}"

        md.append(f"| | | | | {day_total} |")

    md.append(
        f"| **TOTAL** | | **{fmt(grand_debit)}** | **{fmt(grand_credit)}** | **net: {fmt(grand_debit - grand_credit)}** |"
    )
    md.append("")

    # ── 2. TOP SPENDS ──
    paid_tx = sorted(
        [t for t in tx if t["kind"] in ("paid", "topup")],
        key=lambda x: x["amount"],
        reverse=True,
    )
    md.append("## Top spends")
    md.append("")
    md.append("| # | Entity | ₹ | Category | Date |")
    md.append("|---|--------|---|---------|------|")
    for rank, t in enumerate(paid_tx[:15], 1):
        medal = {1: "🥇", 2: "🥈", 3: "🥉"}.get(rank, str(rank))
        cat = categorize_entity(t["entity"], t.get("reason"))
        md.append(
            f"| {medal} | {t['entity']} | {fmt(t['amount'])} | {cat} | {t['date_display']} |"
        )
    md.append("")

    # ── 3. REPEATED ENTITIES ──
    md.append("## Repeated entities")
    md.append("")

    per_entity = defaultdict(lambda: {"terms": [], "net": 0, "count": 0})
    for t in tx:
        if t["kind"] not in ("paid", "received"):
            continue
        ent = t["entity"]
        amt = t["amount"]
        signed = amt if t["kind"] == "paid" else -amt
        per_entity[ent]["terms"].append((t["kind"], amt))
        per_entity[ent]["net"] += signed
        per_entity[ent]["count"] += 1

    repeated = {e: d for e, d in per_entity.items() if d["count"] > 1}
    repeated_sorted = sorted(
        repeated.items(), key=lambda kv: kv[1]["net"], reverse=True
    )

    if not repeated_sorted:
        md.append("_No repeated entities._")
    else:
        for ent, data in repeated_sorted[:10]:
            expr = ""
            for idx, (kind, amt) in enumerate(data["terms"][:5]):
                val = fmt(amt)
                sign = "+" if kind == "paid" else "-"
                if idx == 0:
                    expr = f"{sign}{val}"
                else:
                    expr += f" {sign} {val}"
            net = data["net"]
            net_str = fmt(abs(net))
            prefix = "+" if net > 0 else "-"
            md.append(
                f"- **{ent}** ({data['count']}x) — `{expr}` = `{prefix}{net_str}`"
            )
    md.append("")

    # ── 4. IMPULSIVE SPENDS ──
    imp_items = [t for t in tx if t["kind"] == "paid" and t["amount"] < 40]
    imp_total = sum(t["amount"] for t in imp_items)

    md.append("## Impulsive spends (<₹40)")
    md.append("")
    if imp_items:
        md.append(
            f"**{len(imp_items)}** transactions → `{' + '.join(fmt(t['amount']) for t in imp_items[:10])}` = **���{fmt(imp_total)}**"
        )
        if len(imp_items) > 10:
            md.append(f"... and {len(imp_items) - 10} more")
    else:
        md.append("_None._")
    md.append("")

    # ── 5. CATEGORY BREAKDOWN ──
    md.append("## Category breakdown")
    md.append("")

    categories = defaultdict(lambda: {"total": 0, "items": []})
    for t in tx:
        if t["kind"] != "paid":
            continue
        cat = categorize_entity(t["entity"], t.get("reason"))
        categories[cat]["total"] += t["amount"]
        categories[cat]["items"].append(t)

    for cat in sorted(categories, key=lambda c: categories[c]["total"], reverse=True):
        data = categories[cat]
        md.append(f"- {cat}: **₹{fmt(data['total'])}** ({len(data['items'])} txns)")
    md.append("")

    # ── 6. BEHAVIOURAL INSIGHTS ──
    insights = get_behavioural_patterns(tx)
    if insights:
        md.append("## Behavioural insights")
        md.append("")
        md.append("*Psychology-rooted analysis of your spending patterns.*")
        md.append("")
        for key, data in insights.items():
            md.append(f"### {data['name']}")
            md.append(f"- **Trigger**: {data['trigger']}")
            md.append(f"- **Your metric**: {data['metric']}")
            md.append(f"- **Why it matters**: {data['psych']}")
            md.append(f"- **Fix**: {data['fix']}")
            md.append("")
    md.append("")

    # ── 7. SUMMARY ──
    md.append("## Summary")
    md.append("")
    md.append(f"- 💸 Total debited: **₹{fmt(grand_debit)}**")
    md.append(f"- 💰 Total credited: **₹{fmt(grand_credit)}**")
    md.append(f"- 📊 Net outflow: **₹{fmt(grand_debit - grand_credit)}**")
    md.append(f"- 📅 Active days: **{len(by_date)}**")
    if paid_tx:
        avg_daily = grand_debit / len(by_date)
        md.append(f"- 📈 Avg spend/active day: **₹{fmt(avg_daily)}**")
    md.append("")

    return "\n".join(md)


# ── Main ────────────────────────────────────────────────────


def main():
    if len(sys.argv) < 2:
        print("Usage: bank-parse-v2.py <pdf_path> [password]", file=sys.stderr)
        sys.exit(1)

    pdf_path = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 else ""
    filename = Path(pdf_path).name

    # Try pdfplumber first (SBI), fallback to pdftotext (GPay)
    try:
        tx = extract_tables_sbi(pdf_path, password)
        source_type = "sbi"
    except Exception as e:
        print(f"pdfplumber failed: {e}, trying pdftotext...", file=sys.stderr)
        text = extract_text(pdf_path, password)
        source_type = detect_type(text)
        # Would need GPay parser here - for now exit
        print("Error: GPay parsing not implemented in v2 yet", file=sys.stderr)
        sys.exit(1)

    if not tx:
        print(f"Error: No transactions found in {pdf_path}", file=sys.stderr)
        sys.exit(1)

    tx = apply_group_adjustment(tx)
    md = build_markdown(tx, source_type, filename)
    print(md)


if __name__ == "__main__":
    main()
