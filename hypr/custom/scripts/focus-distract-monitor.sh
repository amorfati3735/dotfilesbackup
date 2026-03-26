#!/bin/bash
# Distraction speed bump monitor for focus mode
# Polls hyprctl for distracting windows, sends nudge + logs to daily note

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
DAILY_DIR="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」"
WARNED_FILE="/tmp/focus-warned-windows"

# Distracting window classes (lowercase)
DISTRACT_CLASSES=("kitty" "antigravity")

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
done
