#!/usr/bin/env python3
"""daylog-write.py — writes daylog answers to habits.md and the daynote.

Invoked by daylog.sh. Args:
    daylog-write.py <daynote_path> <habits_path>
                    <id> <target> <column> <section> <style> <value>
                    [...repeated...]

`target` is one of:
    habits.md  → append/update today's row in the table
    daynote    → write to today's daynote file
    <other>    → treated as a path under the vault root

`style` (file targets only):
    append-section  → append `- HH:MM — value` under <section>
    prepend         → prepend `- **Day Mon DD, HH:MM AM** — value` at top of file

For habits.md: columns auto-extend, missing cells become "—", rows sorted by
date descending. Yes/No values render as ✅/❌.
"""
import re
import sys
import unicodedata
from datetime import datetime, timedelta
from pathlib import Path


def _cwidth(c: str) -> int:
    if unicodedata.east_asian_width(c) in ("W", "F"):
        return 2
    cp = ord(c)
    if 0x2600 <= cp <= 0x27BF:   # symbols & dingbats (✅ ❌ ✦ ✨ …)
        return 2
    if 0x1F000 <= cp <= 0x1FAFF:  # emoji
        return 2
    return 1


def dwidth(s: str) -> int:
    return sum(_cwidth(c) for c in s)


def dpad(s: str, width: int) -> str:
    return s + " " * max(0, width - dwidth(s))

NOW = datetime.now()
# Logical day rolls over at 4am — entries 00:00–03:59 count as the previous day
TODAY_ISO = (NOW - timedelta(hours=4)).strftime("%Y-%m-%d")
NOW_HM = NOW.strftime("%H:%M")
NOW_RICH = NOW.strftime("%a %b %d, %I:%M %p")  # e.g. "Wed May 13, 09:48 PM"
EMPTY = "—"


def to_glyph(v: str) -> str:
    if v == "Yes":
        return "✅"
    if v == "No":
        return "❌"
    return v


def prepend_to_file(file_path: Path, value: str) -> None:
    """Prepend a quick-jot-style line at the very top of the file."""
    file_path.parent.mkdir(parents=True, exist_ok=True)
    existing = file_path.read_text() if file_path.exists() else ""
    line = f"- **{NOW_RICH}** — {value}\n"
    if existing and not existing.startswith("\n"):
        new = line + existing
    else:
        new = line + existing
    file_path.write_text(new)


def append_to_section(file_path: Path, section: str, value: str) -> None:
    file_path.parent.mkdir(parents=True, exist_ok=True)
    text = file_path.read_text() if file_path.exists() else ""
    section = (section or "## Log").strip()
    line = f"- {NOW_HM} — {value}"

    if re.search(r"^" + re.escape(section) + r"\s*$", text, flags=re.MULTILINE):
        # Insert right after the section heading
        text = re.sub(
            r"(^" + re.escape(section) + r"\s*$)",
            r"\1\n" + line,
            text,
            count=1,
            flags=re.MULTILINE,
        )
    else:
        if text and not text.endswith("\n"):
            text += "\n"
        text += f"\n{section}\n{line}\n"

    file_path.write_text(text)


def update_habits(habits_path: Path, updates: list[tuple[str, str]]) -> None:
    """updates = [(column_name, value), ...] for today."""
    habits_path.parent.mkdir(parents=True, exist_ok=True)
    text = habits_path.read_text() if habits_path.exists() else ""

    lines = text.split("\n") if text else []

    # Find existing table header (first line starting with "| Date")
    header_idx = next(
        (i for i, ln in enumerate(lines) if ln.strip().startswith("| Date")),
        None,
    )

    if header_idx is None:
        cols = ["Date"] + [c for c, _ in updates]
        rows_by_date = {TODAY_ISO: {"Date": TODAY_ISO}}
        for c, v in updates:
            rows_by_date[TODAY_ISO][c] = to_glyph(v)
        # Compose fresh file
        new_text = compose_file(text, lines, header_idx=None, cols=cols, rows_by_date=rows_by_date)
        habits_path.write_text(new_text)
        return

    # Parse header
    header_line = lines[header_idx]
    cols = [c.strip() for c in header_line.strip().strip("|").split("|")]

    # Find table extent
    sep_idx = header_idx + 1
    row_start = header_idx + 2
    row_end = row_start
    while row_end < len(lines) and lines[row_end].strip().startswith("|"):
        row_end += 1
    table_rows = lines[row_start:row_end]

    # Add new columns if any
    new_cols = [c for c, _ in updates if c not in cols]
    cols = cols + new_cols

    rows_by_date: dict[str, dict[str, str]] = {}
    for r in table_rows:
        cells = [c.strip() for c in r.strip().strip("|").split("|")]
        while len(cells) < len(cols):
            cells.append(EMPTY)
        date = cells[0]
        rows_by_date[date] = dict(zip(cols, cells))

    # Update / create today's row
    today = rows_by_date.get(TODAY_ISO, {c: EMPTY for c in cols})
    today["Date"] = TODAY_ISO
    for c in cols:
        today.setdefault(c, EMPTY)
    for c, v in updates:
        today[c] = to_glyph(v)
    rows_by_date[TODAY_ISO] = today

    new_text = compose_file(text, lines, header_idx, cols, rows_by_date,
                            sep_idx=sep_idx, row_end=row_end)
    habits_path.write_text(new_text)


def compose_file(original_text, lines, header_idx, cols, rows_by_date,
                 sep_idx=None, row_end=None) -> str:
    # Compute column widths (display width, not char count — handles ✅/❌)
    widths = {c: dwidth(c) for c in cols}
    for d, row in rows_by_date.items():
        for c in cols:
            widths[c] = max(widths[c], dwidth(row.get(c, EMPTY)))

    def fmt_row(rd):
        return "| " + " | ".join(dpad(rd.get(c, EMPTY), widths[c]) for c in cols) + " |"

    new_header = "| " + " | ".join(dpad(c, widths[c]) for c in cols) + " |"
    new_sep = "|" + "|".join("-" * (widths[c] + 2) for c in cols) + "|"
    sorted_dates = sorted(rows_by_date.keys(), reverse=True)
    new_rows = [fmt_row(rows_by_date[d]) for d in sorted_dates]
    new_table = [new_header, new_sep] + new_rows

    if header_idx is None:
        # Fresh file: just the table, no header
        if not original_text:
            return "\n".join(new_table) + "\n"
        if not original_text.endswith("\n"):
            original_text += "\n"
        return original_text + "\n" + "\n".join(new_table) + "\n"

    new_lines = lines[:header_idx] + new_table + lines[row_end:]
    out = "\n".join(new_lines)
    if not out.endswith("\n"):
        out += "\n"
    return out


def resolve_target_path(target: str, daynote_path: Path, habits_path: Path) -> Path:
    if target == "daynote":
        return daynote_path
    return habits_path.parent / target


def write_to_file(target_path: Path, style: str, section: str, value: str) -> None:
    style = (style or "append-section").strip()
    if style == "prepend":
        prepend_to_file(target_path, value)
    else:  # append-section (default)
        append_to_section(target_path, section, value)


def main() -> None:
    args = sys.argv[1:]
    if len(args) < 2:
        sys.exit("usage: daylog-write.py <daynote_path> <habits_path> <6-tuples...>")
    daynote_path = Path(args[0])
    habits_path = Path(args[1])
    rest = args[2:]
    if len(rest) % 6 != 0:
        sys.exit(f"expected groups of 6 args, got {len(rest)} extra")

    habit_updates: list[tuple[str, str]] = []

    for i in range(0, len(rest), 6):
        _id, target, column, section, style, value = rest[i:i + 6]
        if target == "habits.md":
            habit_updates.append((column, value))
        else:
            target_path = resolve_target_path(target, daynote_path, habits_path)
            write_to_file(target_path, style, section, to_glyph(value))

    if habit_updates:
        update_habits(habits_path, habit_updates)


if __name__ == "__main__":
    main()
