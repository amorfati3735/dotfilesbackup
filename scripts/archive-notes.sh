#!/usr/bin/env bash
# Archive past-month daily notes and logs into YYYY/Mon subfolders.
# Current month's files stay in the root. Everything older gets moved.
#
# Usage: archive-notes.sh [--dry-run]

set -euo pipefail

VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
DAILY_DIR="$VAULT/「日常」"
LOGS_DIR="$VAULT/logs"
DAILY_ARCHIVE="$DAILY_DIR/archive"
LOGS_ARCHIVE="$LOGS_DIR/archive"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Current month/year
CUR_MON=$(date +%b)  # e.g. Apr
CUR_YEAR=$(date +%y) # e.g. 26

archive_folder() {
    local src_dir="$1"
    local archive_dir="$2"
    local moved=0

    # Match files like DD-Mon-YY.md or DD-Mon.md
    for f in "$src_dir"/*.md; do
        [[ -f "$f" ]] || continue
        local name
        name=$(basename "$f")

        # Extract month and year from filename
        local mon year
        if [[ "$name" =~ ^[0-9]{2}-([A-Za-z]{3})-([0-9]{2})\.md$ ]]; then
            mon="${BASH_REMATCH[1]}"
            year="${BASH_REMATCH[2]}"
        elif [[ "$name" =~ ^[0-9]{2}-([A-Za-z]{3})\.md$ ]]; then
            # Files like 23-Mar.md (no year) — assume current year context
            mon="${BASH_REMATCH[1]}"
            year="$CUR_YEAR"
        else
            continue  # skip non-daily-note files
        fi

        # Skip current month
        [[ "$mon" == "$CUR_MON" && "$year" == "$CUR_YEAR" ]] && continue

        local dest="$archive_dir/20${year}/${mon}"
        if $DRY_RUN; then
            echo "[dry-run] $name -> $dest/"
        else
            mkdir -p "$dest"
            mv "$f" "$dest/"
            echo "moved $name -> $dest/"
        fi
        moved=$((moved + 1))
    done

    echo "  ($moved files)"
}

echo "=== Daily notes (「日常」) ==="
archive_folder "$DAILY_DIR" "$DAILY_ARCHIVE"

echo ""
echo "=== Logs ==="
archive_folder "$LOGS_DIR" "$LOGS_ARCHIVE"
