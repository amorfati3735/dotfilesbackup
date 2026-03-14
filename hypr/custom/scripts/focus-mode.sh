#!/bin/bash

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
DAILY_DIR="$VAULT/「日常」"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
FOCUS_WALLPAPER="$HOME/Wallpapers/focus.png"
POST_FOCUS_WALLPAPER="$HOME/Wallpapers/castlevania.png"
BONGOCAT_CMD="bongocat --config $HOME/.config/bongocat.conf"
JOURNAL_LOOP="$HOME/.config/hypr/custom/scripts/focus-journal-loop.sh"
DISTRACT_MONITOR="$HOME/.config/hypr/custom/scripts/focus-distract-monitor.sh"
SELF="$HOME/.config/hypr/custom/scripts/focus-mode.sh"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
}

# --- Material You rofi theme (shared) ---
source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

# --- Utility functions ---

format_duration() {
    local secs=$1
    local hours=$((secs / 3600))
    local mins=$(( (secs % 3600) / 60 ))
    if (( hours > 0 )); then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

format_time() {
    date -d "@$1" '+%-I:%M%P' | sed 's/:00\(.\{2\}\)$/\1/'
}

get_daily_note() {
    echo "$DAILY_DIR/$(date '+%d-%b').md"
}

ensure_focus_heading() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo -e "## Focus Sessions\n" > "$file"
    elif ! grep -q '^## Focus Sessions' "$file"; then
        echo -e "\n## Focus Sessions\n" >> "$file"
    fi
}

read_state() {
    if [[ -f "$STATE_FILE" ]]; then
        jq -r "$1" "$STATE_FILE" 2>/dev/null
    else
        echo ""
    fi
}

update_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local tmp
        tmp=$(mktemp)
        jq "$1" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
    fi
}

# --- Time parsing (robust: 10.52pm, 10.52, 1052, 10:52pm, 10:52, etc.) ---

parse_time_input() {
    local raw="$1"

    # Normalize: dots → colons, strip spaces, lowercase
    raw=$(echo "$raw" | tr '.' ':' | tr -d ' ' | tr '[:upper:]' '[:lower:]')

    # Extract am/pm suffix if present
    local ampm=""
    if [[ "$raw" =~ (am|pm)$ ]]; then
        ampm="${BASH_REMATCH[1]}"
        raw="${raw%$ampm}"
    fi

    # Try parsing with colon (e.g. 10:52)
    local hour min
    if [[ "$raw" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        hour="${BASH_REMATCH[1]}"
        min="${BASH_REMATCH[2]}"
    elif [[ "$raw" =~ ^([0-9]{1,2})$ ]]; then
        # Just an hour, e.g. "11" or "1"
        hour="$raw"
        min="00"
    elif [[ "$raw" =~ ^([0-9]{1,2})([0-9]{2})$ ]]; then
        # No separator, e.g. "1052"
        hour="${BASH_REMATCH[1]}"
        min="${BASH_REMATCH[2]}"
    else
        echo ""
        return 1
    fi

    # Remove leading zeros for arithmetic
    hour=$((10#$hour))
    min=$((10#$min))

    # Validate
    (( min > 59 )) && { echo ""; return 1; }

    # If no am/pm, infer based on "session < 3 hours" rule
    if [[ -z "$ampm" ]]; then
        local now_epoch=$(date +%s)
        local now_hour=$(date +%-H)

        # Try as-is in 24h (if hour >= 13, it's already 24h)
        if (( hour >= 13 )); then
            # Already 24h format
            :
        else
            # Try both AM and PM, pick the one that's in the future and < 3 hours away
            local try_am_h=$hour
            local try_pm_h=$((hour + 12))
            (( hour == 12 )) && { try_am_h=0; try_pm_h=12; }

            local am_epoch=$(date -d "$(printf '%02d:%02d' $try_am_h $min)" +%s 2>/dev/null)
            local pm_epoch=$(date -d "$(printf '%02d:%02d' $try_pm_h $min)" +%s 2>/dev/null)

            # If AM is in the past, add a day
            (( am_epoch <= now_epoch )) && am_epoch=$((am_epoch + 86400))
            (( pm_epoch <= now_epoch )) && pm_epoch=$((pm_epoch + 86400))

            local am_diff=$((am_epoch - now_epoch))
            local pm_diff=$((pm_epoch - now_epoch))

            # Pick the one that's < 3 hours (10800s), prefer the closer one
            if (( am_diff <= 10800 && pm_diff <= 10800 )); then
                # Both valid, pick closer
                if (( am_diff < pm_diff )); then
                    hour=$try_am_h
                else
                    hour=$try_pm_h
                fi
            elif (( am_diff <= 10800 )); then
                hour=$try_am_h
            elif (( pm_diff <= 10800 )); then
                hour=$try_pm_h
            else
                # Neither is < 3h away, pick the closer future one
                if (( am_diff < pm_diff )); then
                    hour=$try_am_h
                else
                    hour=$try_pm_h
                fi
            fi
        fi
    else
        # Apply am/pm
        if [[ "$ampm" == "am" ]]; then
            (( hour == 12 )) && hour=0
        elif [[ "$ampm" == "pm" ]]; then
            (( hour != 12 )) && hour=$((hour + 12))
        fi
    fi

    # Build epoch
    local target_epoch
    target_epoch=$(date -d "$(printf '%02d:%02d' $hour $min)" +%s 2>/dev/null)
    if [[ -z "$target_epoch" ]]; then
        echo ""
        return 1
    fi

    local now_epoch=$(date +%s)
    # If in the past, add 24 hours
    (( target_epoch <= now_epoch )) && target_epoch=$((target_epoch + 86400))

    echo "$target_epoch"
}

# --- Process management ---

start_journal_loop() {
    # Kill any existing loops first
    pkill -f "focus-journal-loop\\.sh" 2>/dev/null || true
    sleep 0.2

    nohup "$JOURNAL_LOOP" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    disown "$pid"
    update_state ".journal_loop_pid = $pid"
    log "Started journal loop PID=$pid"
}

start_end_timer() {
    local end_time
    end_time=$(read_state '.end_time // 0')
    local now
    now=$(date +%s)
    local wait_secs=$(( end_time - now ))
    (( wait_secs < 1 )) && wait_secs=1

    # Use setsid to fully detach the timer from this process group
    setsid bash -c "sleep $wait_secs; '$SELF' --end" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    disown "$pid" 2>/dev/null
    update_state ".timer_pid = $pid"
    log "Started end timer PID=$pid, wait=${wait_secs}s"
}

stop_journal_loop() {
    local pid
    pid=$(read_state '.journal_loop_pid // 0')
    if [[ "$pid" -gt 0 ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null
    fi
    pkill -f "focus-journal-loop\\.sh" 2>/dev/null || true
    log "Stopped journal loop"
}

start_distract_monitor() {
    pkill -f "focus-distract-monitor\\.sh" 2>/dev/null || true
    sleep 0.2
    nohup "$DISTRACT_MONITOR" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    disown "$pid"
    update_state ".distract_pid = $pid"
    log "Started distraction monitor PID=$pid"
}

stop_distract_monitor() {
    local pid
    pid=$(read_state '.distract_pid // 0')
    if [[ "$pid" -gt 0 ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
    fi
    pkill -f "focus-distract-monitor\\.sh" 2>/dev/null || true
    log "Stopped distraction monitor"
}

stop_end_timer() {
    local pid
    pid=$(read_state '.timer_pid // 0')
    if [[ "$pid" -gt 0 ]]; then
        kill -- -"$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
        pkill -P "$pid" 2>/dev/null || true
    fi
    log "Stopped end timer"
}

# --- Rating visualization ---

build_bar() {
    local val=$1
    local bar=""
    for i in 1 2 3 4 5; do
        if (( i <= val )); then
            bar+="█"
        else
            bar+="░"
        fi
    done
    echo "$bar"
}

# --- End session (the critical path) ---

end_session() {
    log "=== END SESSION ==="
    stop_journal_loop || true
    stop_end_timer || true
    stop_distract_monitor || true

    local session_name start_time end_actual total_pause_seconds
    session_name=$(read_state '.session_name')
    start_time=$(read_state '.start_time')
    end_actual=$(date +%s)
    total_pause_seconds=$(read_state '.total_pause_seconds // 0')

    local pause_count
    pause_count=$(jq '[.journal[] | select(.type == "pause")] | length' "$STATE_FILE" 2>/dev/null || echo 0)

    local raw_duration=$((end_actual - start_time))
    local active_duration=$((raw_duration - total_pause_seconds))
    (( active_duration < 0 )) && active_duration=0

    local duration_str
    duration_str=$(format_duration "$active_duration")
    local start_fmt end_fmt
    start_fmt=$(format_time "$start_time")
    end_fmt=$(format_time "$end_actual")

    # Build rating bars from journal entries
    local ratings_json bars_line avg_rating
    ratings_json=$(jq '[.journal[] | select(.type == "rating") | .value]' "$STATE_FILE" 2>/dev/null)
    local rating_count
    rating_count=$(echo "$ratings_json" | jq 'length' 2>/dev/null || echo 0)

    if (( rating_count > 0 )); then
        avg_rating=$(echo "$ratings_json" | jq 'add / length * 10 | round / 10')
        bars_line=""
        for r in $(echo "$ratings_json" | jq '.[]'); do
            bars_line+="$(build_bar "$r")  "
        done
        bars_line="${bars_line%  }"
    else
        avg_rating="—"
        bars_line=""
    fi

    # Build summary notification
    local summary="${session_name} | ${start_fmt} → ${end_fmt} (${duration_str})"
    if [[ -n "$bars_line" ]]; then
        summary+="\n${bars_line}\nAvg: ${avg_rating}/5"
    fi

    # Append summary to daily note
    local daily_note
    daily_note=$(get_daily_note)
    local pause_info=""
    if (( pause_count > 0 )); then
        local pause_dur_str
        pause_dur_str=$(format_duration "$total_pause_seconds")
        pause_info=" — ${pause_count} pause (${pause_dur_str})"
    fi
    local avg_str=""
    [[ "$avg_rating" != "—" ]] && avg_str=" — Avg ${avg_rating}/5"
    echo "> ✦ ${duration_str} session${avg_str}${pause_info}" >> "$daily_note"

    log "Switching wallpaper to castlevania..."
    # Switch to post-focus wallpaper
    nohup "$SWITCHWALL" "$POST_FOCUS_WALLPAPER" >/dev/null 2>&1 &
    disown

    log "Relaunching bongocat..."
    # Relaunch bongocat
    nohup $BONGOCAT_CMD >/dev/null 2>&1 &
    disown

    # Write done state (QML watcher detects content change reliably)
    echo '{"state":"done"}' > "$STATE_FILE"

    log "Sending notification..."
    notify-send -a "Focus Mode" "Session complete ✦" "$(echo -e "$summary")"
    log "=== END SESSION DONE ==="
}

abort_session() {
    log "=== ABORT SESSION ==="
    stop_journal_loop || true
    stop_end_timer || true
    stop_distract_monitor || true

    local session_name
    session_name=$(read_state '.session_name')

    # Ask for journal on abort
    local entry
    entry=$(focus_rofi "Aborting" "why tho" "input")
    local rating="—"
    if [[ -n "$entry" ]]; then
        rating=$(echo -e "1\n2\n3\n4\n5" | focus_rofi "Rating (1-5)" "" "list")
        [[ -z "$rating" || ! "$rating" =~ ^[1-5]$ ]] && rating="—"
        
        # Log to daily note
        local daily_note time_str
        daily_note=$(get_daily_note)
        time_str=$(date '+%-I:%M%P')
        local rating_str=""
        [[ "$rating" != "—" ]] && rating_str=" [${rating}/5]"
        echo "- **${time_str}** 🛑 Aborted session: ${entry}${rating_str}" >> "$daily_note"
    fi

    log "Switching wallpaper to castlevania..."
    nohup "$SWITCHWALL" "$POST_FOCUS_WALLPAPER" >/dev/null 2>&1 &
    disown

    log "Relaunching bongocat..."
    nohup $BONGOCAT_CMD >/dev/null 2>&1 &
    disown

    echo '{"state":"done"}' > "$STATE_FILE"

    notify-send -a "Focus Mode" "Session aborted" "See you next time."
    log "=== ABORT SESSION DONE ==="
}

# --- Start session ---

start_session() {
    local session_name
    session_name=$(focus_rofi "Session" "What are you working on?" "input")
    [[ -z "$session_name" ]] && exit 0

    local end_input
    end_input=$(focus_rofi "Until when?" "e.g. 12am, 11.30, 1am" "input")
    [[ -z "$end_input" ]] && exit 0

    # Parse end time with robust parser
    local end_epoch
    end_epoch=$(parse_time_input "$end_input")
    if [[ -z "$end_epoch" ]]; then
        notify-send -a "Focus Mode" "Error" "Couldn't parse time: $end_input"
        exit 1
    fi

    log "=== START SESSION: $session_name until $(date -d @$end_epoch '+%H:%M') ==="

    local now
    now=$(date +%s)

    # Kill bongocat
    pkill -f bongocat 2>/dev/null
    log "Killed bongocat"

    # Switch wallpaper
    "$SWITCHWALL" "$FOCUS_WALLPAPER" >> "$LOG_FILE" 2>&1 &
    log "Switching wallpaper to focus"

    # Write state file
    jq -n \
        --arg state "active" \
        --arg name "$session_name" \
        --argjson start "$now" \
        --argjson end "$end_epoch" \
        '{
            state: $state,
            session_name: $name,
            start_time: $start,
            end_time: $end,
            paused: false,
            pause_start: 0,
            total_pause_seconds: 0,
            journal: [],
            journal_loop_pid: 0,
            timer_pid: 0
        }' > "$STATE_FILE"

    # Log to daily note
    local daily_note start_fmt end_fmt
    daily_note=$(get_daily_note)
    start_fmt=$(format_time "$now")
    end_fmt=$(format_time "$end_epoch")
    ensure_focus_heading "$daily_note"
    echo "### ${session_name} (${start_fmt} → ${end_fmt})" >> "$daily_note"

    notify-send -a "Focus Mode" "Focus mode on" "Let's go — $(format_duration $((end_epoch - now))) ahead."

    # Start journal loop, end timer, and distraction monitor
    start_journal_loop
    start_end_timer
    start_distract_monitor
}

# --- Pause/Resume ---

pause_session() {
    local prefilled_reason="$1"
    local now
    now=$(date +%s)
    stop_journal_loop || true
    stop_end_timer || true
    stop_distract_monitor || true
    
    # Prompt for pause journal
    local entry="$prefilled_reason"
    if [[ -z "$entry" ]]; then
        entry=$(focus_rofi "Pausing" "why ho" "input")
    fi
    if [[ -n "$entry" ]]; then
        local daily_note time_str
        daily_note=$(get_daily_note)
        time_str=$(date '+%-I:%M%P')
        echo "- **${time_str}** ⏸ Paused: ${entry}" >> "$daily_note"
    fi

    update_state ".state = \"paused\" | .paused = true | .pause_start = $now | .journal += [{\"type\": \"pause\", \"time\": $now}]"
    notify-send -a "Focus Mode" "Paused" "Take your time."
    log "Session paused"
}

resume_session() {
    local now pause_start pause_duration total_pause
    now=$(date +%s)
    pause_start=$(read_state '.pause_start // 0')
    pause_duration=$((now - pause_start))
    total_pause=$(read_state '.total_pause_seconds // 0')
    total_pause=$((total_pause + pause_duration))

    # If paused > 15 minutes, offer choice
    if (( pause_duration > 900 )); then
        local choice
        choice=$(printf "Resume\nEnd session" | focus_rofi "Paused $(format_duration $pause_duration)" "" "list")
        if [[ "$choice" == "End session" ]]; then
            update_state ".total_pause_seconds = $total_pause"
            end_session
            return
        elif [[ -z "$choice" ]]; then
            return
        fi
    fi

    update_state ".state = \"active\" | .paused = false | .pause_start = 0 | .total_pause_seconds = $total_pause"
    start_journal_loop
    start_end_timer
    start_distract_monitor
    notify-send -a "Focus Mode" "Resumed" "Back at it."
    log "Session resumed"
}

# --- Timer check ---

check_timer() {
    if [[ ! -f "$STATE_FILE" ]]; then
        exit 0
    fi
    local state end_time now
    state=$(read_state '.state')
    end_time=$(read_state '.end_time // 0')
    now=$(date +%s)

    if [[ "$state" == "active" ]] && (( now >= end_time )); then
        end_session
    fi
}

# --- Main ---

if [[ "$1" == "--check-timer" ]]; then
    check_timer
    exit 0
fi

if [[ "$1" == "--end" ]]; then
    log "Received --end signal"
    if [[ -f "$STATE_FILE" ]]; then
        local_state=$(read_state '.state')
        if [[ "$local_state" == "active" || "$local_state" == "paused" ]]; then
            end_session
        else
            log "State is '$local_state', not ending"
        fi
    else
        log "No state file, nothing to end"
    fi
    exit 0
fi

# Toggle logic
if [[ ! -f "$STATE_FILE" ]]; then
    start_session
else
    state=$(read_state '.state')
    case "$state" in
        active)
            # Hidden abort flow
            action=$(focus_rofi "Focus active" "Press Enter to pause, or type 'abort'" "input")
            if [[ $? -ne 0 ]]; then exit 0; fi

            if [[ "${action,,}" == "abort" ]]; then
                abort_session
            else
                if [[ -n "$action" && "${action,,}" != "pause" ]]; then
                    pause_session "$action"
                else
                    pause_session
                fi
            fi
            ;;
        paused)
            resume_session
            ;;
        done|""|null)
            rm -f "$STATE_FILE"
            start_session
            ;;
        *)
            rm -f "$STATE_FILE"
            start_session
            ;;
    esac
fi
