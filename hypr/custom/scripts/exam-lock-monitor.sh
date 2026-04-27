#!/bin/bash
# Exam-lock window-title monitor
# Polls hyprctl every 5s and force-closes any window whose title contains
# a term from focus-blocklist.md "## Blocked Terms".
#
# Reuses the same blocklist as focus-mode so there is one source of truth.

BLOCKLIST="$HOME/.config/hypr/custom/scripts/focus-blocklist.md"
LOG_FILE="/tmp/exam-lock.log"
POLL_INTERVAL=5

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Parse "## Blocked Terms" section into BLOCKED_TERMS array
load_blocked_terms() {
    BLOCKED_TERMS=()
    [[ ! -f "$BLOCKLIST" ]] && return
    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" == "## Blocked Terms" ]]; then
            in_section=true
            continue
        fi
        if [[ "$line" == "## "* ]] && $in_section; then
            break
        fi
        if $in_section && [[ "$line" =~ ^-\ +(.+)$ ]]; then
            BLOCKED_TERMS+=("$(echo "${BASH_REMATCH[1]}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')")
        fi
    done < "$BLOCKLIST"
}

cleanup() {
    log "Monitor stopping (PID=$$)"
    exit 0
}
trap cleanup SIGTERM SIGINT

log "Monitor started (PID=$$)"

while true; do
    sleep "$POLL_INTERVAL"

    # Reload terms each tick so edits take effect without restart
    load_blocked_terms
    [[ ${#BLOCKED_TERMS[@]} -eq 0 ]] && continue

    clients=$(hyprctl clients -j 2>/dev/null)
    [[ -z "$clients" ]] && continue

    for term in "${BLOCKED_TERMS[@]}"; do
        matches=$(echo "$clients" | jq -r --arg t "$term" \
            '.[] | select(.title | ascii_downcase | contains($t)) | "\(.address)|\(.class)|\(.title[0:60])"' 2>/dev/null)

        while IFS= read -r match; do
            [[ -z "$match" ]] && continue
            addr=$(echo "$match" | cut -d'|' -f1)
            wclass=$(echo "$match" | cut -d'|' -f2)
            wtitle=$(echo "$match" | cut -d'|' -f3)

            log "Closed [$wclass] '$wtitle' (matched: $term)"
            hyprctl dispatch closewindow "address:$addr" > /dev/null 2>&1
            notify-send -a "Exam Lock" -u normal \
                "🔒 Blocked: $term" \
                "Closed: $wtitle"
        done <<< "$matches"
    done
done
