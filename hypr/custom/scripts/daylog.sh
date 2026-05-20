#!/bin/bash
# daylog.sh — Super+Shift+D entry point.
#
# Thin wrapper around `habits ritual`. The habits CLI handles prompts,
# logging, and rendering. This wrapper preserves the older system's:
#   - single-instance lock
#   - "done flag" for today (read by daylog-enforce.sh)
#   - friction lift (restore wallpaper + screen temp)
#
# Flags:
#   --lift-only     restore prior wallpaper/temp without running the ritual

set -uo pipefail

LOCK="/tmp/daylog.lock"
DONE_DIR="$HOME/.cache/daylog"
TODAY=$(date -d '4 hours ago' '+%Y-%m-%d')
DONE_FLAG="$DONE_DIR/done-$TODAY"
FRICTION_FLAG="/tmp/daylog-friction-active"
PREV_WALL_FILE="/tmp/daylog-prev-wall"
PREV_TEMP_FILE="/tmp/daylog-prev-temp"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"

mkdir -p "$DONE_DIR"

lift_friction() {
    [[ -f "$FRICTION_FLAG" ]] || return 0
    if [[ -f "$PREV_TEMP_FILE" ]]; then
        local prev_temp
        prev_temp=$(cat "$PREV_TEMP_FILE")
        [[ -n "$prev_temp" ]] && hyprctl hyprsunset temperature "$prev_temp" >/dev/null 2>&1
    fi
    if [[ -f "$PREV_WALL_FILE" ]]; then
        local prev_wall
        prev_wall=$(cat "$PREV_WALL_FILE")
        [[ -n "$prev_wall" && -f "$prev_wall" ]] && \
            "$SWITCHWALL" "$prev_wall" >/dev/null 2>&1 &
    fi
    rm -f "$FRICTION_FLAG" "$PREV_WALL_FILE" "$PREV_TEMP_FILE"
}

if [[ "${1:-}" == "--lift-only" ]]; then
    lift_friction
    exit 0
fi

exec 9>"$LOCK"
if ! flock -n 9; then
    notify-send "Daylog" "Already running"
    exit 0
fi

# Delegate the whole ritual to the habits CLI.
# Exit 0 → completed (some or all answered); exit 1 → user ESC'd mid-flow.
if "$HOME/.local/bin/habits" ritual; then
    touch "$DONE_FLAG"
    lift_friction
fi
