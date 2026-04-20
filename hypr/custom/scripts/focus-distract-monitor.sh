#!/bin/bash
# Distraction speed bump monitor for focus mode
# Polls hyprctl for distracting windows, sends nudge + logs to daily note

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
DAILY_DIR="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」"
WARNED_FILE="/tmp/focus-warned-windows"

BLOCKLIST="$HOME/.config/hypr/custom/scripts/focus-blocklist.md"

# Parse a section from blocklist file into an array
# Usage: load_section "## Section Name" ARRAY_NAME
load_section() {
    local header="$1"
    local -n arr="$2"
    arr=()
    [[ ! -f "$BLOCKLIST" ]] && return
    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" == "$header" ]]; then
            in_section=true
            continue
        fi
        if [[ "$line" == "## "* ]] && $in_section; then
            break
        fi
        if $in_section && [[ "$line" =~ ^-\ +(.+)$ ]]; then
            arr+=("$(echo "${BASH_REMATCH[1]}" | tr -d ' ' | tr '[:upper:]' '[:lower:]')")
        fi
    done < "$BLOCKLIST"
}

load_section "## Blocked Apps" DISTRACT_CLASSES
load_section "## Blocked Terms" BLOCKED_TERMS

# How often to poll (seconds)
POLL_INTERVAL=5

cleanup() {
    rm -f "$WARNED_FILE"
    exit 0
}
trap cleanup SIGTERM SIGINT

log() {
    echo "[$(date '+%H:%M:%S')] [distract] $*" >> "$LOG_FILE"
}

# Track which windows we've already warned about (by address) so we don't spam
touch "$WARNED_FILE"

log "Started distraction monitor, PID=$$"

while true; do
    sleep "$POLL_INTERVAL"

    # Check we're still in an active focus session
    if [[ ! -f "$STATE_FILE" ]]; then
        log "No state file, exiting"
        cleanup
    fi

    state=$(jq -r '.state // empty' "$STATE_FILE" 2>/dev/null)
    if [[ "$state" != "active" ]]; then
        # Paused or done — skip polling but stay alive (paused sessions resume)
        [[ "$state" == "paused" ]] && continue
        log "State is '$state', exiting"
        cleanup
    fi

    session_name=$(jq -r '.session_name // "your task"' "$STATE_FILE" 2>/dev/null)

    # Get all current windows
    clients=$(hyprctl clients -j 2>/dev/null)
    [[ -z "$clients" ]] && continue

    # Check each distracting class
    for dclass in "${DISTRACT_CLASSES[@]}"; do
        # Find windows with this class
        matches=$(echo "$clients" | jq -r --arg c "$dclass" \
            '.[] | select(.class | ascii_downcase == $c) | "\(.address)|\(.class)|\(.title[0:40])"' 2>/dev/null)

        while IFS= read -r match; do
            [[ -z "$match" ]] && continue

            addr=$(echo "$match" | cut -d'|' -f1)
            wclass=$(echo "$match" | cut -d'|' -f2)
            wtitle=$(echo "$match" | cut -d'|' -f3)

            # Already warned about this window?
            if grep -qF "$addr" "$WARNED_FILE" 2>/dev/null; then
                continue
            fi

            # New distraction! Record, notify, log
            echo "$addr" >> "$WARNED_FILE"
            log "Distraction detected: $wclass ($wtitle)"

            # Speed bump notification
            notify-send -a "Focus Mode" -u normal \
                "🫠 $wclass is open" \
                "You said you'd be on: $session_name"

            # Log to daily note
            daily_file="$DAILY_DIR/$(date '+%d-%b-%y').md"
            time_str=$(date '+%-I:%M%P')
            echo "- ⚠ **${time_str}** opened *${wclass}* during focus" >> "$daily_file"

        done <<< "$matches"
    done

    # Check window titles for blocked terms — close matching windows
    for term in "${BLOCKED_TERMS[@]}"; do
        matches=$(echo "$clients" | jq -r --arg t "$term" \
            '.[] | select(.title | ascii_downcase | contains($t)) | "\(.address)|\(.class)|\(.title[0:40])"' 2>/dev/null)

        while IFS= read -r match; do
            [[ -z "$match" ]] && continue

            addr=$(echo "$match" | cut -d'|' -f1)
            wclass=$(echo "$match" | cut -d'|' -f2)
            wtitle=$(echo "$match" | cut -d'|' -f3)

            # Already handled this window?
            if grep -qF "$addr" "$WARNED_FILE" 2>/dev/null; then
                continue
            fi

            echo "$addr" >> "$WARNED_FILE"
            log "Blocked term '$term' matched: $wclass ($wtitle) — closing"

            # Close the window
            hyprctl dispatch closewindow "address:$addr" > /dev/null 2>&1

            notify-send -a "Focus Mode" -u normal \
                "🚫 Blocked: $term" \
                "Closed $wclass — stay on: $session_name"

            # Log to daily note
            daily_file="$DAILY_DIR/$(date '+%d-%b-%y').md"
            time_str=$(date '+%-I:%M%P')
            echo "- 🚫 **${time_str}** blocked *${wtitle}* (matched: $term)" >> "$daily_file"

        done <<< "$matches"
    done
done
