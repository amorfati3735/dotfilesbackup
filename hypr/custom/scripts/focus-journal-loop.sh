#!/bin/bash

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
DAILY_DIR="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」"
FOCUS_SCRIPT="$HOME/.config/hypr/custom/scripts/focus-mode.sh"

cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT

log() {
    echo "[$(date '+%H:%M:%S')] [journal] $*" >> "$LOG_FILE"
}

# --- Material You rofi theme (shared) ---
source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

# Write our PID to state file
jq --argjson pid "$$" '.journal_loop_pid = $pid' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
log "Started, PID=$$"

while true; do
    # Random sleep 15-25 minutes
    sleep_mins=$(( (RANDOM % 11) + 15 ))
    log "Sleeping ${sleep_mins}m..."
    sleep $(( sleep_mins * 60 ))

    # Check state file exists and session is active
    if [[ ! -f "$STATE_FILE" ]]; then
        log "No state file, exiting"
        exit 0
    fi
    state=$(jq -r '.state // empty' "$STATE_FILE" 2>/dev/null)
    if [[ "$state" != "active" ]]; then
        log "State is '$state', exiting"
        exit 0
    fi

    # Check if screen is locked — wait until unlocked
    session_id=$(loginctl list-sessions --no-legend | awk '{print $1}' | head -1)
    if [[ -n "$session_id" ]]; then
        locked=$(loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null)
        if [[ "$locked" == "yes" ]]; then
            log "Screen locked, waiting..."
            while [[ "$(loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null)" == "yes" ]]; do
                sleep 10
            done
            sleep 30
        fi
    fi

    # Re-check state after potential lock wait
    if [[ ! -f "$STATE_FILE" ]]; then
        exit 0
    fi
    state=$(jq -r '.state // empty' "$STATE_FILE" 2>/dev/null)
    if [[ "$state" != "active" ]]; then
        exit 0
    fi

    # Check if session time is up
    end_time=$(jq -r '.end_time // 0' "$STATE_FILE" 2>/dev/null)
    now=$(date +%s)
    if (( now >= end_time )); then
        log "Time's up, calling --end"
        "$FOCUS_SCRIPT" --end
        exit 0
    fi

    # Prompt for journal entry
    log "Prompting for journal..."
    notify-send -u low "Focus" "What'd you just work through?"
    entry=$(focus_rofi "Journal" "What did you work on?" "input")
    [[ -z "$entry" ]] && { log "Dismissed journal prompt"; continue; }

    # Prompt for rating
    rating=$(echo -e "1\n2\n3\n4\n5" | focus_rofi "Rating (1-5)" "" "list")
    [[ -z "$rating" ]] && { log "Dismissed rating prompt"; continue; }

    # Validate rating is 1-5
    case "$rating" in
        1|2|3|4|5) ;;
        *) continue ;;
    esac

    # Append to state file journal array
    timestamp=$(date +%s)
    jq --argjson t "$timestamp" --arg e "$entry" --argjson r "$rating" \
        '.journal += [{"type": "rating", "time": $t, "entry": $e, "value": ($r | tonumber)}]' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    # Append to daily note
    daily_file="$DAILY_DIR/$(date '+%d-%b').md"
    time_str=$(date '+%-I:%M%P')
    echo "- **${time_str}** [${rating}/5] — ${entry}" >> "$daily_file"
    log "Logged journal entry: [${rating}/5] ${entry}"
done
