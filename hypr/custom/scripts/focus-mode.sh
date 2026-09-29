#!/bin/bash

STATE_FILE="/tmp/focus-mode.json"
LOG_FILE="/tmp/focus-mode.log"
VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
DAILY_DIR="$VAULT/「日常」"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
SHELL_CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
FOCUS_WALL_DIR="$HOME/Wallpapers/lock-in"
FOCUS_WALL_FALLBACK="$FOCUS_WALL_DIR/focus.png"
BLOCKLIST_FILE="$HOME/.config/hypr/custom/scripts/focus-blocklist.md"
DECOMPRESS_WALL_DIR="$HOME/Wallpapers/decompress"
DECOMPRESS_WALL_FALLBACK="$HOME/Wallpapers/castlevania.png"

# Pick a random wallpaper from a directory, with fallback
random_wall() {
    local dir="$1" fallback="$2"
    local pick
    pick=$(find "$dir" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' -o -name '*.webp' \) 2>/dev/null | shuf -n1)
    echo "${pick:-$fallback}"
}

# Wallpaper currently set in the shell config (what the user had before a session)
current_wallpaper() {
    local path
    path=$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null)
    [[ -n "$path" && -f "$path" ]] && echo "$path"
}

# Print the domains under "## Blocked Websites"
get_blocked_websites() {
    local file="${1:-$BLOCKLIST_FILE}"
    [[ -f "$file" ]] || return 0
    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" == "## Blocked Websites" ]]; then
            in_section=true
            continue
        fi
        if [[ "$line" == "## "* ]] && $in_section; then
            break
        fi
        if $in_section && [[ "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}" | tr -d ' '
        fi
    done < "$file"
}

# Normalize a user-typed domain: strip scheme/path/spaces, lowercase
normalize_domain() {
    printf '%s' "$1" | tr -d ' ' | tr '[:upper:]' '[:lower:]' | sed -E 's#^https?://##; s#/.*$##'
}

# Add a single domain to "## Blocked Websites" (deduped)
add_blocked_website() {
    local file="$BLOCKLIST_FILE"
    local site
    site=$(normalize_domain "$1")
    [[ -z "$site" ]] && return 1

    local domains
    domains=$(get_blocked_websites "$file")
    if printf '%s\n' "$domains" | grep -qxF "$site"; then
        notify-send -a "Focus Mode" "Already blocked" "$site is already on the list."
        return 1
    fi

    if grep -q '^## Blocked Websites' "$file" 2>/dev/null; then
        awk -v site="$site" '
            { print }
            $0 == "## Blocked Websites" && !done { print "- " site; done = 1 }
        ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    else
        printf '\n## Blocked Websites\n- %s\n' "$site" >> "$file"
    fi

    log "Added to blocklist: $site"
    notify-send -a "Focus Mode" "Blocklist updated" "$site will be blocked this session."
}

# Remove a domain from "## Blocked Websites" (section-scoped, whitespace/case tolerant)
remove_blocked_website() {
    local file="$BLOCKLIST_FILE"
    local site
    site=$(normalize_domain "$1")
    [[ -z "$site" ]] && return 1

    awk -v site="$site" '
        /^## / { in_sec = ($0 == "## Blocked Websites") }
        in_sec {
            line = $0
            sub(/^-[[:space:]]+/, "", line)
            gsub(/[[:space:]]/, "", line)
            if (tolower(line) == site) next
        }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    log "Removed from blocklist: $site"
    notify-send -a "Focus Mode" "Blocklist updated" "$site removed."
}

# Interactive blocklist editor: type a domain + Enter to add, select one + Delete to
# remove, Esc to finish. Loops so multiple edits can be made in a single pass.
edit_blocklist() {
    while true; do
        local domains
        domains=$(get_blocked_websites "$BLOCKLIST_FILE")

        local mesg
        if [[ -n "$domains" ]]; then
            mesg="Enter = add  ·  Alt+d on a site = remove  ·  Esc = done"
        else
            mesg="Type a domain + Enter to add  ·  Esc = done"
        fi

        local out rc
        out=$({ [[ -n "$domains" ]] && printf '%s\n' "$domains"; } | \
            focus_rofi "Websites to block" "type a domain + Enter" "list" \
                -mesg "$mesg" -kb-custom-1 Alt+d)
        rc=$?

        case "$rc" in
            1) break ;;                                             # Esc / cancel
            10) [[ -n "$out" ]] && remove_blocked_website "$out" ;; # Delete pressed
            0) [[ -n "$out" ]] && add_blocked_website "$out" ;;     # Enter accepted
        esac
    done
}

JOURNAL_LOOP="$HOME/.config/hypr/custom/scripts/focus-journal-loop.sh"
DISTRACT_MONITOR="$HOME/.config/hypr/custom/scripts/focus-distract-monitor.sh"
HOSTS_BLOCK="$HOME/.config/hypr/custom/scripts/focus-hosts-block.sh"
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
    echo "$DAILY_DIR/$(date '+%d-%b-%y').md"
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
        if jq "$@" "$STATE_FILE" > "$tmp"; then
            mv "$tmp" "$STATE_FILE"
        else
            rm -f "$tmp"
        fi
    fi
}

# Restore the wallpaper the user had before the session (falls back to a
# random decompress wallpaper only if the previous path is gone).
restore_wallpaper() {
    local prev
    prev=$(read_state '.prev_wallpaper // empty')
    if [[ -n "$prev" && -f "$prev" ]]; then
        log "Restoring previous wallpaper: $prev"
        nohup "$SWITCHWALL" "$prev" >> "$LOG_FILE" 2>&1 &
    else
        local pick
        pick=$(random_wall "$DECOMPRESS_WALL_DIR" "$DECOMPRESS_WALL_FALLBACK")
        log "Previous wallpaper unavailable, using decompress pick: $pick"
        nohup "$SWITCHWALL" "$pick" >> "$LOG_FILE" 2>&1 &
    fi
    disown
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

    # Poll-based, self-cancelling timer. Avoids `setsid` (which forks, making the
    # recorded PID fake) and avoids group-killing our own process group when the
    # timer itself triggers --expire. It exits on its own once the session is no
    # longer active, and `exec`s --expire so $$ == timer_pid is detectable in stop.
    nohup bash -c "
        end=$end_time
        while true; do
            sleep 5
            st=\$(jq -r '.state // empty' '$STATE_FILE' 2>/dev/null)
            case \"\$st\" in
                active) ;;
                *) exit 0 ;;
            esac
            if (( \$(date +%s) >= end )); then
                exec '$SELF' --expire
            fi
        done
    " >> "$LOG_FILE" 2>&1 &
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
    # When the timer itself invoked --expire, its PID equals ours: nothing to kill.
    if [[ "$pid" -gt 0 && "$pid" != "$$" ]] && kill -0 "$pid" 2>/dev/null; then
        pkill -TERM -P "$pid" 2>/dev/null || true   # the sleeping child
        kill "$pid" 2>/dev/null || true
    fi
    log "Stopped end timer"
}

# --- Expiry (offer to extend before ending) ---

expire_session() {
    # Single-flight, so the timer and journal loop can't both prompt at once
    exec 7>>"/tmp/focus-mode.expire.lock"
    if ! flock -n 7; then
        log "expire already in progress, skipping"
        return 0
    fi

    local name end_time now
    name=$(read_state '.session_name')
    end_time=$(read_state '.end_time // 0')
    now=$(date +%s)

    # Ignore early/spurious calls
    if (( now < end_time - 5 )); then
        log "expire called early (now=$now end=$end_time), ignoring"
        return 0
    fi

    local choice
    choice=$(printf '+15m\n+30m\nEnd session' | focus_rofi "Time's up ⏰" "${name}" "list")

    case "$choice" in
        "+15m"|"+30m")
            local add=900
            [[ "$choice" == "+30m" ]] && add=1800
            local new_end=$(( end_time + add ))
            update_state --argjson e "$new_end" --argjson t "$now" \
                '.end_time = $e | .journal += [{"type":"extend","time":$t}]'

            local daily_file time_str
            daily_file=$(get_daily_note)
            time_str=$(date '+%-I:%M%P')
            echo "- ⏭ **${time_str}** extended ${choice}" >> "$daily_file"

            start_end_timer
            notify-send -a "Focus Mode" "Extended ${choice}" "New end: $(format_time "$new_end")."
            log "Extended by ${add}s, new end $new_end"
            ;;
        *)
            log "No extension chosen; ending session"
            end_session
            ;;
    esac
}

# --- End session (the critical path) ---

end_session() {
    # Guard against concurrent ends (e.g. timer + manual end)
    exec 8>"/tmp/focus-mode.end.lock"
    if ! flock -n 8; then
        log "end_session already in progress, skipping"
        return 0
    fi

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

    # Final journal prompt
    local final_entry
    final_entry=$(focus_rofi "Session done" "How'd it go? What did you accomplish?" "input")
    if [[ -n "$final_entry" ]]; then
        local daily_note_j time_str_j
        daily_note_j=$(get_daily_note)
        time_str_j=$(date '+%-I:%M%P')
        echo "- **${time_str_j}** ✦ ${final_entry}" >> "$daily_note_j"

        local timestamp_j
        timestamp_j=$(date +%s)
        update_state --argjson t "$timestamp_j" --arg e "$final_entry" \
            '.journal += [{"type": "entry", "time": $t, "entry": $e}]'
    fi

    # Count journal entries
    local entry_count
    entry_count=$(jq '[.journal[] | select(.type == "entry")] | length' "$STATE_FILE" 2>/dev/null || echo 0)

    # Build summary notification
    local summary="${session_name} | ${start_fmt} → ${end_fmt} (${duration_str})"
    if (( entry_count > 0 )); then
        summary+="\n${entry_count} check-ins logged"
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
    echo "> ✦ ${duration_str} session${pause_info}" >> "$daily_note"

    # Unblock websites
    "$HOSTS_BLOCK" unblock &
    log "Unblocking websites"

    restore_wallpaper

    # Write done state (QML watcher detects content change reliably)
    echo '{"state":"done"}' > "$STATE_FILE"

    log "Sending notification..."
    notify-send -a "Focus Mode" "Session complete ✦" "$(echo -e "$summary")"
    log "=== END SESSION DONE ==="
}

abort_session() {
    exec 8>"/tmp/focus-mode.end.lock"
    if ! flock -n 8; then
        log "abort_session already in progress, skipping"
        return 0
    fi

    log "=== ABORT SESSION ==="
    stop_journal_loop || true
    stop_end_timer || true
    stop_distract_monitor || true

    local session_name
    session_name=$(read_state '.session_name')

    # Ask for journal on abort
    local entry
    entry=$(focus_rofi "Aborting" "why tho" "input")
    if [[ -n "$entry" ]]; then
        local daily_note time_str
        daily_note=$(get_daily_note)
        time_str=$(date '+%-I:%M%P')
        echo "- **${time_str}** 🛑 Aborted: ${entry}" >> "$daily_note"
    fi

    # Unblock websites
    "$HOSTS_BLOCK" unblock &
    log "Unblocking websites"

    log "Restoring wallpaper..."
    restore_wallpaper

    echo '{"state":"done"}' > "$STATE_FILE"

    notify-send -a "Focus Mode" "Session aborted" "See you next time."
    log "=== ABORT SESSION DONE ==="
}

# --- Start session ---

start_session() {
    local session_name
    session_name=$(focus_rofi "Session" "What are you working on?" "input")
    [[ -z "$session_name" ]] && exit 0

    # Phone check
    local phone_check
    phone_check=$(focus_rofi "Phone down?" "yes" "input")
    [[ "${phone_check,,}" != "yes" ]] && exit 0

    # Review / edit the website blocklist for this session (add or remove)
    edit_blocklist

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

    # Remember the wallpaper to restore when the session ends
    local prev_wall
    prev_wall=$(current_wallpaper)

    # Block distracting websites
    "$HOSTS_BLOCK" block &
    log "Blocking websites"

    # Switch wallpaper
    "$SWITCHWALL" "$(random_wall "$FOCUS_WALL_DIR" "$FOCUS_WALL_FALLBACK")" >> "$LOG_FILE" 2>&1 &
    log "Switching wallpaper to lock-in (will restore: ${prev_wall:-<none>})"

    # Write state file
    jq -n \
        --arg state "active" \
        --arg name "$session_name" \
        --arg prev "$prev_wall" \
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
            prev_wallpaper: $prev,
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

if [[ "$1" == "--blocklist" ]]; then
    edit_blocklist
    exit 0
fi

if [[ "$1" == "--expire" ]]; then
    log "Received --expire signal"
    if [[ -f "$STATE_FILE" ]]; then
        st=$(read_state '.state')
        if [[ "$st" == "active" || "$st" == "paused" ]]; then
            expire_session
        else
            log "State is '$st', not expiring"
        fi
    fi
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
