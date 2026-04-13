#!/bin/bash
# Fixed-interval journal prompts (no ratings)
# - 30m intervals
# - 5-min "heads up" notification before each prompt
# - For sessions <30m: no prompts during, only at end
# - At session end: final journal prompt

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
DAILY_DIR="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」"
FOCUS_SCRIPT="$HOME/.config/hypr/custom/scripts/focus-mode.sh"

PROMPT_INTERVAL=1800  # 30 minutes
HEADS_UP=300          # 5 minutes before prompt

cleanup() {
    exit 0
}
trap cleanup SIGTERM SIGINT

log() {
    echo "[$(date '+%H:%M:%S')] [journal] $*" >> "$LOG_FILE"
}

# --- Material You rofi theme (shared) ---
source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

wait_for_unlock() {
    local session_id
    session_id=$(loginctl list-sessions --no-legend | awk '{print $1}' | head -1)
    if [[ -n "$session_id" ]]; then
        local locked
        locked=$(loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null)
        if [[ "$locked" == "yes" ]]; then
            log "Screen locked, waiting..."
            while [[ "$(loginctl show-session "$session_id" -p LockedHint --value 2>/dev/null)" == "yes" ]]; do
                sleep 10
            done
            sleep 30
        fi
    fi
}

check_active() {
    if [[ ! -f "$STATE_FILE" ]]; then
        log "No state file, exiting"
        exit 0
    fi
    local state
    state=$(jq -r '.state // empty' "$STATE_FILE" 2>/dev/null)
    if [[ "$state" != "active" ]]; then
        log "State is '$state', exiting"
        exit 0
    fi
}

do_journal_prompt() {
    local prompt_label="$1"
    wait_for_unlock
    check_active

    # Check if session time is up
    local end_time now
    end_time=$(jq -r '.end_time // 0' "$STATE_FILE" 2>/dev/null)
    now=$(date +%s)
    if (( now >= end_time )); then
        log "Time's up, calling --end"
        "$FOCUS_SCRIPT" --end
        exit 0
    fi

    # Prompt for journal entry (no rating)
    log "Prompting for journal ($prompt_label)..."
    local entry
    entry=$(focus_rofi "Check-in" "What did you just work on?" "input")
    [[ -z "$entry" ]] && { log "Dismissed journal prompt"; return; }

    # Append to state file journal array
    local timestamp
    timestamp=$(date +%s)
    jq --argjson t "$timestamp" --arg e "$entry" \
        '.journal += [{"type": "entry", "time": $t, "entry": $e}]' \
        "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

    # Append to daily note
    local daily_file time_str
    daily_file="$DAILY_DIR/$(date '+%d-%b-%y').md"
    time_str=$(date '+%-I:%M%P')
    echo "- **${time_str}** — ${entry}" >> "$daily_file"
    log "Logged journal entry: ${entry}"
}

# Write our PID to state file
jq --argjson pid "$$" '.journal_loop_pid = $pid' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
log "Started, PID=$$"

# Determine if this is a short session (<30m)
start_time=$(jq -r '.start_time // 0' "$STATE_FILE" 2>/dev/null)
end_time=$(jq -r '.end_time // 0' "$STATE_FILE" 2>/dev/null)
session_length=$((end_time - start_time))

if (( session_length < PROMPT_INTERVAL )); then
    # Short session — no prompts during, just wait for end
    log "Short session ($(( session_length / 60 ))m), no mid-session prompts"
    # Sleep until session ends, the timer handles the actual end
    sleep "$session_length"
    exit 0
fi

# Main loop: fixed 30m intervals with 5-min heads up
while true; do
    # Sleep for (interval - heads_up) = 25 minutes
    wait_phase1=$(( PROMPT_INTERVAL - HEADS_UP ))
    log "Sleeping ${wait_phase1}s ($(( wait_phase1 / 60 ))m) until heads-up..."
    sleep "$wait_phase1"

    check_active

    # Heads up notification
    notify-send -u low -a "Focus Mode" "📝 Check-in in 5 minutes" "Get to a stopping point."
    log "Sent heads-up notification"

    # Sleep the remaining 5 minutes
    log "Sleeping ${HEADS_UP}s until prompt..."
    sleep "$HEADS_UP"

    check_active
    do_journal_prompt "30m interval"
done
