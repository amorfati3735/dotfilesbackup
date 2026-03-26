#!/bin/bash
# Reorganize daily notes:
# 1. Rename archived DD-Mon.md → DD-Mon-YY.md (with correct year)
# 2. Move loose root files into archive under year folders (archive/2025/, archive/2026/)
# 3. Restructure month-based archive folders into year-based
# 4. Handle duplicates (24-Mar.md vs 24-Mar-26.md, 25-Mar.md vs 25-Mar-26.md)
# 5. Handle conflict files, non-day-note files

set -euo pipefail

VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」"
ARCHIVE="$VAULT/archive"
DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

log() { echo "  $*"; }
run() {
    if $DRY_RUN; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

# Month abbreviations → month numbers
declare -A MONTH_NUM=(
    [Jan]=01 [Feb]=02 [Mar]=03 [Apr]=04 [May]=05 [Jun]=06
    [Jul]=07 [Aug]=08 [Sep]=09 [Oct]=10 [Nov]=11 [Dec]=12
)

# Archive month folders → year mapping (from file timestamps)
declare -A ARCHIVE_MONTH_YEAR=(
    [Jul]=25 [Aug]=25 [Sep]=25 [Oct]=25 [Nov]=25 [Dec]=25
    [Jan]=26
)

echo "=== Step 1: Create year-based archive folders ==="
run mkdir -p "$ARCHIVE/2025"
run mkdir -p "$ARCHIVE/2026"

echo ""
echo "=== Step 2: Rename & move archived files from month folders → year folders ==="
for month_dir in "$ARCHIVE"/*/; do
    month_name=$(basename "$month_dir")
    # Skip year folders we just created
    [[ "$month_name" == "2025" || "$month_name" == "2026" ]] && continue

    yy="${ARCHIVE_MONTH_YEAR[$month_name]:-}"
    if [[ -z "$yy" ]]; then
        log "SKIP: Unknown month folder: $month_name"
        continue
    fi

    year_dir="$ARCHIVE/20$yy"

    for f in "$month_dir"*; do
        [[ -f "$f" ]] || continue
        fname=$(basename "$f")

        # Match day notes: DD-Mon.md pattern
        if [[ "$fname" =~ ^([0-9]{2})-([A-Z][a-z]{2})\.md$ ]]; then
            day="${BASH_REMATCH[1]}"
            mon="${BASH_REMATCH[2]}"
            new_name="${day}-${mon}-${yy}.md"
            log "$month_name/$fname → 20$yy/$new_name"
            run mv "$f" "$year_dir/$new_name"

        # Conflict/duplicate files: keep as-is but move to year folder
        else
            log "$month_name/$fname → 20$yy/$fname (non-standard, kept as-is)"
            run mv "$f" "$year_dir/$fname"
        fi
    done

    # Remove empty month folder
    if ! $DRY_RUN; then
        rmdir "$month_dir" 2>/dev/null && log "Removed empty folder: $month_name/" || true
    fi
done

echo ""
echo "=== Step 3: Handle loose files in root ==="

# Merge 25-Mar.md content into 25-Mar-26.md (25-Mar has focus session data the -26 one lacks)
if [[ -f "$VAULT/25-Mar.md" && -f "$VAULT/25-Mar-26.md" ]]; then
    log "Merging 25-Mar.md into 25-Mar-26.md"
    if ! $DRY_RUN; then
        echo "" >> "$VAULT/25-Mar-26.md"
        cat "$VAULT/25-Mar.md" >> "$VAULT/25-Mar-26.md"
        rm "$VAULT/25-Mar.md"
    fi
fi

# 24-Mar.md is identical to 24-Mar-26.md — just remove the old one
if [[ -f "$VAULT/24-Mar.md" && -f "$VAULT/24-Mar-26.md" ]]; then
    log "Removing duplicate 24-Mar.md (identical to 24-Mar-26.md)"
    run rm "$VAULT/24-Mar.md"
fi

# Remove root dupes of files already moved to archive (11-Jan, 25-Jan)
for f in "$VAULT"/*.md; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")
    if [[ "$fname" =~ ^([0-9]{2})-([A-Z][a-z]{2})\.md$ ]]; then
        day="${BASH_REMATCH[1]}"
        mon="${BASH_REMATCH[2]}"
        file_year=$(stat --format='%Y' "$f" | xargs -I{} date -d @{} +%y)
        candidate="$ARCHIVE/20${file_year}/${day}-${mon}-${file_year}.md"
        if [[ -f "$candidate" ]] && diff -q "$f" "$candidate" >/dev/null 2>&1; then
            log "Removing root dupe: $fname (identical to archive/20${file_year}/${day}-${mon}-${file_year}.md)"
            run rm "$f"
        fi
    fi
done

# Move remaining loose DD-Mon.md files to archive with -YY suffix
for f in "$VAULT"/*.md; do
    [[ -f "$f" ]] || continue
    fname=$(basename "$f")

    # Skip sessions.md, Untitled files, and already-renamed -26 files
    [[ "$fname" == "sessions.md" ]] && continue
    [[ "$fname" == Untitled* ]] && continue

    # Already has year suffix (DD-Mon-YY.md) — these are current, leave in root
    if [[ "$fname" =~ ^[0-9]{2}-[A-Z][a-z]{2}-[0-9]{2}\.md$ ]]; then
        continue
    fi

    # Match DD-Mon.md pattern
    if [[ "$fname" =~ ^([0-9]{2})-([A-Z][a-z]{2})\.md$ ]]; then
        day="${BASH_REMATCH[1]}"
        mon="${BASH_REMATCH[2]}"

        # Determine year from file modification time
        file_year=$(stat --format='%Y' "$f" | xargs -I{} date -d @{} +%y)
        new_name="${day}-${mon}-${file_year}.md"
        dest="$ARCHIVE/20${file_year}/$new_name"

        # Don't overwrite if destination exists
        if [[ -f "$dest" ]]; then
            log "CONFLICT: $fname → $new_name already exists in archive, skipping"
            continue
        fi

        log "$fname → archive/20${file_year}/$new_name"
        run mv "$f" "$dest"
    fi
done

echo ""
echo "=== Step 4: Handle Jan files already in archive that overlap with root ==="
# The Jan archive already has some files (01-Jan, etc.) and root had 11-Jan, 25-Jan, 26-Jan
# These were already moved in step 2 (archive/Jan/) and step 3 (root loose files)
# Just verify no conflicts

echo ""
echo "=== Done! Final structure ==="
echo "Root (current notes):"
ls "$VAULT"/*.md 2>/dev/null | xargs -I{} basename {} | head -10
echo ""
echo "Archive:"
for yd in "$ARCHIVE"/*/; do
    yname=$(basename "$yd")
    count=$(ls "$yd"/*.md 2>/dev/null | wc -l)
    echo "  $yname/ — $count files"
    ls "$yd" | head -5
    echo "  ..."
done
