#!/usr/bin/env python3
"""
bank-parse.py — Parse SBI & GPay bank statement PDFs into rich Obsidian markdown.

Usage:  python3 bank-parse.py <pdf_path> [password]

Outputs markdown to stdout.
"""

import json
import re
import sys
import subprocess
from pathlib import Path
from collections import defaultdict, OrderedDict
from datetime import datetime

import pdfplumber


# ── Helpers ──────────────────────────────────────────────────

def fmt(n: float) -> str:
    """Format a number: no trailing zeros, no trailing dot."""
    s = f"{n:.2f}".rstrip("0").rstrip(".")
    return s


MONTH_MAP = {
    "Jan": "01", "Feb": "02", "Mar": "03", "Apr": "04",
    "May": "05", "Jun": "06", "Jul": "07", "Aug": "08",
    "Sep": "09", "Oct": "10", "Nov": "11", "Dec": "12",
}
MONTH_ABBR = {v: k for k, v in MONTH_MAP.items()}


def parse_date_sbi(s: str) -> datetime:
    """Parse dd/mm/yyyy"""
    return datetime.strptime(s.strip(), "%d/%m/%Y")


def date_sort_key(d: str) -> str:
    """Convert 'dd-Mon' to sortable 'mm-dd'"""
    parts = d.split("-")
    if len(parts) == 2:
        day, mon = parts
        mm = MONTH_MAP.get(mon, "00")
        return f"{mm}-{day}"
    return d


# ── PDF text extraction (for GPay only) ─────────────────────

def extract_text(pdf_path: str, password: str = "") -> str:
    cmd = ["pdftotext", "-layout"]
    if password:
        cmd += ["-upw", password]
    cmd += [pdf_path, "-"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"pdftotext error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout


# ── Detect statement type ────────────────────────────────────

def detect_type(pdf_path: str, password: str = "") -> str:
    """Detect statement type by scanning first page text via pdfplumber."""
    try:
        pdf = pdfplumber.open(pdf_path, password=password or None)
        text = pdf.pages[0].extract_text() or ""
        pdf.close()
    except Exception:
        text = extract_text(pdf_path, password)

    if "State Bank of India" in text or "SBIN" in text or "UPI/DR/" in text:
        return "sbi"
    if "Paid to" in text or "Received from" in text or "Google Pay" in text:
        return "gpay"
    if re.search(r"\d{2}/\d{2}/\d{4}.*UPI", text):
        return "sbi"
    return "gpay"


# ── SBI parser (pdfplumber table extraction) ────────────────

BANK_CODES_SET = frozenset({
    "SBIN", "YESB", "PUNB", "UTIB", "CBIN", "ICIC", "INDB", "HDFC", "KKBK",
    "IDFB", "BARB", "CNRB", "MAHB", "BKID", "UBIN", "ALLA", "CORP", "ANDB",
    "IDIB", "IOBA", "ORBC", "PSIB", "RATN", "SIBL", "TMBL", "VIJB", "AIRP",
    "PYTM", "PAYT", "FDRL", "BNPA", "CIUB", "COSB", "DCBL", "ESFB", "HSBC",
    "IBKL", "JAKA", "KARB", "KVBL", "LAVB", "NKGS", "SCBL", "SRCB", "UCBA",
})
BANK_CODES_RE = r"(?:" + "|".join(BANK_CODES_SET) + r")"
ENTITY_SHORT_WORDS = {"TR", "MR", "DR", "MS", "ST", "CO", "IN"}


def _merge_desc_lines(raw: str) -> str:
    """Join pdfplumber's newline-split description into a single UPI string.

    pdfplumber gives us e.g.:
        "WDL TFR\\nUPI/DR/609189177055/ALPHAME\\nR/YESB/paytm.s1bk/UPI\\n..."
    We need: "WDL TFR UPI/DR/609189177055/ALPHAMER/YESB/paytm.s1bk/UPI ..."

    Handles entity-name splits like "RHEMA" + "TR/..." → "RHEMA TR/..."
    vs token splits like "ALPHAME" + "R/..." → "ALPHAMER/..."
    """
    lines = raw.split("\n")

    upi_start = None
    for i, line in enumerate(lines):
        if "UPI/" in line:
            upi_start = i
            break

    if upi_start is None:
        return re.sub(r"\s+", " ", raw.replace("\n", " ")).strip()

    # Prefix lines (e.g. "WDL TFR") before UPI
    prefix = " ".join(lines[:upi_start])
    upi_text = lines[upi_start]

    for line in lines[upi_start + 1:]:
        if re.match(r"^\d{7,}", line):
            break
        if upi_text.endswith("/") or line.startswith("/"):
            upi_text += line
        else:
            fragment = line.split("/", 1)[0]
            frag_upper = fragment.upper()
            if frag_upper in BANK_CODES_SET:
                upi_text += "/" + line
            elif len(fragment) == 1:
                upi_text += line
            elif len(fragment) <= 3 and frag_upper not in ENTITY_SHORT_WORDS and fragment.isupper():
                upi_text += line
            else:
                upi_text += " " + line

    full = f"{prefix} {upi_text}" if prefix else upi_text
    return re.sub(r"\s+", " ", full).strip()


def _extract_entity(desc: str):
    """Extract entity name and note from a merged UPI description string."""
    entity = ""
    note = ""

    upi_match = re.search(
        rf"UPI/(?:DR|CR)/\d+/(.+?)/({BANK_CODES_RE})/([^/\s]+)",
        desc
    )
    if upi_match:
        entity = upi_match.group(1).strip()

        after = desc[upi_match.end():]
        note_match = re.match(r"/(\S+)", after)
        if note_match:
            raw = note_match.group(1)
            if not re.match(r"^(UPI|UP)\b", raw) and not re.match(r"^\d{7,}", raw):
                note = raw
    else:
        simple = re.search(r"UPI/(?:DR|CR)/\d+/([^/]+)/([^/]+)/([^/]+)", desc)
        if simple:
            entity = simple.group(1).strip()
        else:
            entity = re.sub(r"\s*\d{7,}.*", "", desc).strip()[:40]

    return entity, note


def parse_sbi(pdf_path: str, password: str = "") -> list:
    transactions = []
    pdf = pdfplumber.open(pdf_path, password=password or None)

    for page in pdf.pages:
        tables = page.extract_tables()
        for table in tables:
            for row in table:
                if not row or len(row) < 7:
                    continue
                date_str = (row[0] or "").strip()
                if not re.match(r"\d{2}/\d{2}/\d{4}$", date_str):
                    continue

                raw_desc = row[2] or ""
                debit_str = (row[4] or "").strip()
                credit_str = (row[5] or "").strip()

                desc = _merge_desc_lines(raw_desc)

                # Determine debit/credit and amount
                is_credit = "UPI/CR/" in desc or "DEP TFR" in desc
                amount = None
                if is_credit and credit_str and credit_str != "-":
                    amount = float(credit_str.replace(",", ""))
                elif not is_credit and debit_str and debit_str != "-":
                    amount = float(debit_str.replace(",", ""))

                if amount is None or amount == 0:
                    continue

                entity, note = _extract_entity(desc)

                dt = parse_date_sbi(date_str)
                day_str = dt.strftime("%d")
                mon_str = MONTH_ABBR.get(dt.strftime("%m"), dt.strftime("%m"))

                transactions.append({
                    "date_full": dt.strftime("%d %b, %Y"),
                    "date_display": f"{day_str}-{mon_str}",
                    "date_sort": dt.strftime("%Y%m%d"),
                    "time": "",
                    "kind": "received" if is_credit else "paid",
                    "entity": entity,
                    "amount": amount,
                    "reason": note,
                })

    pdf.close()
    return transactions


# ── GPay parser (from original script) ──────────────────────

def parse_gpay(text: str) -> list:
    # GPay format: date, party, and amount are all on one line:
    #   01 Oct, 2025                  Paid to Adarsh Kumar singh                    ₹50
    #   07:21 PM                      UPI Transaction ID: 564060869029
    #                                     Paid by State Bank of India 4421
    line_re = re.compile(
        r"(\d{1,2}\s[A-Za-z]{3},\s\d{4})\s+"
        r"(Paid to|Received from|Top-up to)\s+(.+?)\s+"
        r"₹([\d,\.]+)\s*$"
    )
    time_pattern = re.compile(r"(\d{1,2}:\d{2}\s(?:AM|PM))")

    lines = text.splitlines()
    transactions = []
    n = len(lines)

    for i, line in enumerate(lines):
        m = line_re.search(line)
        if not m:
            continue

        date_str, mode, entity, amt_str = m.groups()
        entity = entity.strip()
        amount = float(amt_str.replace(",", ""))

        dt = datetime.strptime(date_str, "%d %b, %Y")
        date_sort = dt.strftime("%Y%m%d")
        day_str = dt.strftime("%d")
        mon_str = dt.strftime("%b")

        time_match = time_pattern.search(lines[i + 1]) if i + 1 < n else None
        time = time_match.group(1) if time_match else ""

        if mode == "Paid to":
            kind = "paid"
            reason = ""
        elif mode == "Received from":
            kind = "received"
            reason = ""
        else:
            kind = "topup"
            reason = "top-up"

        transactions.append({
            "date_full": f"{int(day_str)} {mon_str}, {dt.strftime('%Y')}",
            "date_display": f"{day_str}-{mon_str}",
            "date_sort": date_sort,
            "time": time,
            "kind": kind,
            "entity": entity,
            "amount": amount,
            "reason": reason,
        })

    return transactions


# ── Entity dictionary ────────────────────────────────────────

ENTITY_DB = Path(__file__).parent / ".bank-entities.json"

# Manual overrides for names that can't be auto-matched
MANUAL_MAP = {
    "Mr ADARS": "Adarsh Kumar singh",
    "MrADARS": "Adarsh Kumar singh",
}


def _load_entity_db() -> dict:
    if ENTITY_DB.exists():
        return json.loads(ENTITY_DB.read_text())
    return {}


def _save_entity_db(db: dict):
    ENTITY_DB.write_text(json.dumps(db, indent=2, ensure_ascii=False) + "\n")


def learn_entities(tx: list):
    """Update entity DB with full names from GPay transactions."""
    db = _load_entity_db()
    for t in tx:
        name = (t.get("entity") or "").strip()
        if name and len(name) > 3:
            key = name.lower().replace(" ", "")
            db[key] = name
    _save_entity_db(db)


def resolve_entity(name: str, db: dict) -> str:
    """Try to resolve a truncated SBI entity to its full GPay name."""
    if not name:
        return name

    # Manual overrides first
    if name in MANUAL_MAP:
        return MANUAL_MAP[name]

    norm = name.lower().replace(" ", "")

    # Exact match
    if norm in db:
        return db[norm]

    # SBI name is prefix of a GPay name
    matches = [(k, v) for k, v in db.items() if k.startswith(norm)]
    if len(matches) == 1:
        return matches[0][1]

    # GPay name is prefix of SBI name (e.g. "airtel" matches "airtelp")
    matches = [(k, v) for k, v in db.items() if norm.startswith(k) and len(k) >= 4]
    if len(matches) == 1:
        return matches[0][1]

    return name


def resolve_all_entities(tx: list) -> list:
    """Resolve all entity names in transactions using the entity DB."""
    db = _load_entity_db()
    if not db and not MANUAL_MAP:
        return tx
    for t in tx:
        t["entity"] = resolve_entity(t["entity"], db)
    return tx


# ── Group adjustment (reimburse logic) ──────────────────────

FRIENDS = {"adarsh", "snehansh", "arunya", "yasharth"}


def _is_friend(entity: str) -> bool:
    e = (entity or "").lower()
    return any(f in e for f in FRIENDS)


def apply_group_adjustment(tx):
    by_date = defaultdict(list)
    for t in tx:
        by_date[t["date_display"]].append(t)

    for date, items in by_date.items():
        reimburse = sum(
            t["amount"] for t in items
            if t["kind"] == "received" and 50 < t["amount"] <= 2000
            and _is_friend(t["entity"])
        )
        if reimburse == 0:
            continue

        paid_items = [t for t in items if t["kind"] == "paid"]
        if not paid_items:
            continue

        largest = max(paid_items, key=lambda t: t["amount"])
        original = largest["amount"]
        adjusted = original - reimburse
        if adjusted < 0:
            continue
        largest["amount"] = adjusted
        largest["reason"] = "group-adjusted"

    return tx


# ── Build markdown ──────────────────────────────────────────

def build_markdown(tx, source_type: str, filename: str) -> str:
    md = []

    # Header
    months = sorted({t["date_display"].split("-")[1] for t in tx})
    years = sorted({t["date_full"].split(", ")[-1].strip() for t in tx})
    month_str = ", ".join(months)
    year_str = years[0] if years else ""
    bank = "SBI" if source_type == "sbi" else "GPay"

    md.append("---")
    md.append(f"tags: [finance, {bank.lower()}, bank-statement]")
    md.append(f"source: \"{filename}\"")
    md.append(f"bank: {bank}")
    md.append(f"period: \"{month_str} {year_str}\"")
    md.append("---")
    md.append("")
    md.append(f"# {bank} — {month_str} {year_str}")
    md.append("")

    # ── 1. DAILY SPENDING TABLE ──
    # Group by date, show each txn with running sum per day
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
            note = f" *({t['reason']})*" if t["reason"] else ""

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
                # topup etc — treat as debit
                day_debits.append(t["amount"])
                grand_debit += t["amount"]
                debit_cell = fmt(t["amount"])
                credit_cell = ""

            date_cell = f"**{date}**" if first else ""
            day_total_cell = ""
            md.append(f"| {date_cell} | {entity}{note} | {debit_cell} | {credit_cell} | {day_total_cell} |")
            first = False

        # Day summary row
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

    md.append(f"| **TOTAL** | | **{fmt(grand_debit)}** | **{fmt(grand_credit)}** | **net: {fmt(grand_debit - grand_credit)}** |")
    md.append("")

    # ── 2. TOP SPENDS (sorted by amount) ──
    paid_tx = sorted([t for t in tx if t["kind"] in ("paid", "topup")], key=lambda x: x["amount"], reverse=True)
    md.append("## Top spends")
    md.append("")
    md.append("| # | Entity | ₹ | Date |")
    md.append("|---|--------|---|------|")
    for rank, t in enumerate(paid_tx[:15], 1):
        medal = {1: "🥇", 2: "🥈", 3: "🥉"}.get(rank, str(rank))
        md.append(f"| {medal} | {t['entity']} | {fmt(t['amount'])} | {t['date_display']} |")
    md.append("")

    # ── 3. REPEATED ENTITIES (with net) ──
    md.append("## Repeated entities")
    md.append("")

    per_entity = defaultdict(lambda: {"terms": [], "net": 0, "count": 0})
    for t in tx:
        if t["kind"] not in ("paid", "received"):
            continue
        ent = t["entity"]
        amt = t["amount"]
        sign = "+" if t["kind"] == "paid" else "-"
        signed = amt if t["kind"] == "paid" else -amt
        per_entity[ent]["terms"].append((sign, amt))
        per_entity[ent]["net"] += signed
        per_entity[ent]["count"] += 1

    repeated = {e: d for e, d in per_entity.items() if d["count"] > 1}
    repeated_sorted = sorted(repeated.items(), key=lambda kv: kv[1]["net"], reverse=True)

    if not repeated_sorted:
        md.append("_No repeated entities._")
    else:
        for ent, data in repeated_sorted:
            expr = ""
            for idx, (sign, amt) in enumerate(data["terms"]):
                val = fmt(amt)
                if idx == 0:
                    expr += val if sign == "+" else f"-{val}"
                else:
                    expr += f" {sign} {val}"
            net = data["net"]
            net_str = fmt(abs(net))
            prefix = "+" if net > 0 else "-"
            md.append(f"- **{ent}** ({data['count']}x) — `{expr}` = `{prefix}{net_str}`")
    md.append("")

    # ── 4. IMPULSIVE SPENDS (<₹40) ──
    imp_items = [t for t in tx if t["kind"] == "paid" and t["amount"] < 40]
    imp_total = sum(t["amount"] for t in imp_items)

    md.append("## Impulsive spends (<₹40)")
    md.append("")
    if imp_items:
        parts = [f"{fmt(t['amount'])}({t['entity'][:10]})" for t in imp_items]
        md.append(f"**{len(imp_items)}** transactions → `{' + '.join(fmt(t['amount']) for t in imp_items)}` = **₹{fmt(imp_total)}**")
    else:
        md.append("_None._")
    md.append("")

    # ── 5. CATEGORY BREAKDOWN (heuristic) ──
    md.append("## Category hints")
    md.append("")

    categories = defaultdict(lambda: {"total": 0, "items": []})
    for t in tx:
        if t["kind"] != "paid":
            continue
        ent_lower = (t["entity"] or "").lower()
        reason_lower = (t["reason"] or "").lower()
        combined = ent_lower + " " + reason_lower

        if any(k in combined for k in ["food", "court", "restaurant", "cafe", "eat", "biryani", "kitchen", "mess", "canteen"]):
            cat = "🍔 Food"
        elif any(k in combined for k in ["airtel", "jio", "vodafone", "recharge", "mobile"]):
            cat = "📱 Recharge"
        elif any(k in combined for k in ["amazon", "flipkart", "shop", "store", "mart"]):
            cat = "🛒 Shopping"
        elif any(k in combined for k in ["uber", "ola", "train", "irctc", "travel", "railway"]):
            cat = "🚗 Transport"
        elif any(k in combined for k in ["top-up", "topup", "wallet"]):
            cat = "💳 Top-up"
        else:
            cat = "📦 Other"

        categories[cat]["total"] += t["amount"]
        categories[cat]["items"].append(t)

    for cat in sorted(categories, key=lambda c: categories[c]["total"], reverse=True):
        data = categories[cat]
        md.append(f"- {cat}: **₹{fmt(data['total'])}** ({len(data['items'])} txns)")
    md.append("")

    # ── 6. SUMMARY ──
    md.append("## Summary")
    md.append("")
    md.append(f"- 💸 Total debited: **₹{fmt(grand_debit)}**")
    md.append(f"- 💰 Total credited: **₹{fmt(grand_credit)}**")
    md.append(f"- 📊 Net outflow: **₹{fmt(grand_debit - grand_credit)}**")
    date_objs = sorted(datetime.strptime(t["date_sort"], "%Y%m%d") for t in tx)
    span_days = (date_objs[-1] - date_objs[0]).days + 1 if date_objs else 0
    md.append(f"- 📅 Active days: **{len(by_date)}/{span_days}**")
    if paid_tx:
        avg_daily = grand_debit / len(by_date)
        md.append(f"- 📈 Avg spend/active day: **₹{fmt(avg_daily)}**")
    md.append("")

    return "\n".join(md)


# ── Main ─────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: bank-parse.py <pdf_path> [password]", file=sys.stderr)
        sys.exit(1)

    pdf_path = sys.argv[1]
    password = sys.argv[2] if len(sys.argv) > 2 else ""
    filename = Path(pdf_path).name

    stmt_type = detect_type(pdf_path, password)

    if stmt_type == "sbi":
        tx = parse_sbi(pdf_path, password)
    else:
        text = extract_text(pdf_path, password)
        if not text.strip():
            print(f"Error: No text extracted from {pdf_path}", file=sys.stderr)
            sys.exit(1)
        tx = parse_gpay(text)
        learn_entities(tx)

    if not tx:
        print(f"Error: No transactions found in {pdf_path}", file=sys.stderr)
        sys.exit(1)

    tx = resolve_all_entities(tx)
    tx = apply_group_adjustment(tx)
    md = build_markdown(tx, stmt_type, filename)
    print(md)


if __name__ == "__main__":
    main()
