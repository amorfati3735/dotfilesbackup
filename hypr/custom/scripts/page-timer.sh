#!/bin/bash
# Page-by-page handwriting timer
# Toggle: launch to start, launch again to stop
# ` = start session / mark page done
# ~ (Shift+`) = add a timestamped comment via rofi
# Escape = end session & save

VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
FILE="$VAULT/sessions.md"
PID_FILE="/tmp/page-timer.pid"

source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

# --- Toggle: kill existing instance ---
if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    kill -TERM "$(cat "$PID_FILE")" 2>/dev/null
    exit 0
fi

# --- State ---
PAGE=0
SESSION_START=""
LAST_TICK=""
ROWS=""
DATE_HEADER="[$(date '+%d-%b-%y')]"

fmt_duration() {
    local secs=$1
    local mins=$(( secs / 60 ))
    local s=$(( secs % 60 ))
    if (( mins > 0 )); then
        printf "%dm %02ds" "$mins" "$s"
    else
        printf "%ds" "$s"
    fi
}

write_to_file() {
    [[ -z "$ROWS" ]] && return
    local now=$(date +%s)
    local total=$(( now - SESSION_START ))
    local total_fmt=$(fmt_duration $total)

    local block=""
    block+="$DATE_HEADER"$'\n'
    block+=""$'\n'
    block+="| Page | Time | Comment |"$'\n'
    block+="|------|------|---------|"$'\n'
    block+="$ROWS"
    block+="| **Total** | **${total_fmt}** | ${PAGE} pages |"$'\n'
    block+=""$'\n'

    if [[ -f "$FILE" ]]; then
        local tmp=$(mktemp)
        head -2 "$FILE" > "$tmp"
        echo "$block" >> "$tmp"
        tail -n +3 "$FILE" >> "$tmp"
        mv "$tmp" "$FILE"
    else
        echo "| | |" > "$FILE"
        echo "| --- | --- |" >> "$FILE"
        echo "$block" >> "$FILE"
    fi
}

do_tick() {
    local now=$(date +%s)
    if [[ -z "$SESSION_START" ]]; then
        SESSION_START=$now
        LAST_TICK=$now
        notify-send -a "Page Timer" -u normal "📖 Session began" "Press \` after each page"
        return
    fi
    PAGE=$(( PAGE + 1 ))
    local elapsed=$(( now - LAST_TICK ))
    LAST_TICK=$now
    ROWS+="| ${PAGE} | $(fmt_duration $elapsed) | |"$'\n'
    notify-send -a "Page Timer" -u normal "✅ Page ${PAGE}" "$(fmt_duration $elapsed)"
}

do_comment() {
    local comment
    comment=$(focus_rofi "Note" "add a comment..." "input")
    [[ -z "$comment" ]] && return
    if [[ -z "$SESSION_START" ]]; then
        ROWS+="| — | — | ${comment} |"$'\n'
    else
        local now=$(date +%s)
        local since=$(( now - LAST_TICK ))
        ROWS+="| 💬 | +$(fmt_duration $since) | ${comment} |"$'\n'
    fi
    notify-send -a "Page Timer" -u low "📝 Noted" "$comment"
}

unbind_keys() {
    hyprctl --batch "\
        keyword unbind ,grave;\
        keyword unbind SHIFT,grave" >/dev/null 2>&1
}

do_end() {
    unbind_keys
    if [[ -n "$SESSION_START" && $PAGE -gt 0 ]]; then
        write_to_file
        local total=$(( $(date +%s) - SESSION_START ))
        notify-send -a "Page Timer" -u normal "📕 Session done" "${PAGE} pages in $(fmt_duration $total)"
    else
        notify-send -a "Page Timer" -u low "📕 Session ended" "No pages recorded"
    fi
    rm -f "$PID_FILE"
    exit 0
}

# Write PID
echo $$ > "$PID_FILE"

# Bind keys (user is handwriting on paper, not typing)
hyprctl --batch "\
    keyword bind ,grave,exec,kill -USR1 $$;\
    keyword bind SHIFT,grave,exec,kill -USR2 $$" >/dev/null 2>&1

# Signals
trap 'do_tick' USR1
trap 'do_comment' USR2
trap 'do_end' TERM INT

notify-send -a "Page Timer" -u low "⏱ Page Timer ready" "\` start/page · ~  comment · relaunch to stop"

# Wait forever, woken by signals
while true; do
    sleep infinity &
    wait $!
done
