#!/bin/bash
# daylog-enforce.sh — friction kicker for daylog
#
# Run periodically by a systemd user timer. Active 22:00 — 02:00.
# If today's daylog isn't done:
#   - cranks hyprsunset to 1000K (max warmth, ugly red tint)
#   - swaps wallpaper to the nag image
#   - launches the rofi prompt
# Saves prior state so daylog.sh can restore on completion.

set -uo pipefail

DONE_DIR="$HOME/.cache/daylog"
TODAY=$(date '+%Y-%m-%d')
DONE_FLAG="$DONE_DIR/done-$TODAY"
NAG_WALL="$HOME/Wallpapers/50f2b5e6f6edcc9891f23132f7b32aaf.jpg"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
WALLP_CONFIG="$HOME/.config/illogical-impulse/config.json"
DAYLOG_SH="$HOME/.config/hypr/custom/scripts/daylog.sh"
FRICTION_FLAG="/tmp/daylog-friction-active"
PREV_WALL_FILE="/tmp/daylog-prev-wall"
PREV_TEMP_FILE="/tmp/daylog-prev-temp"
LOG="/tmp/daylog.log"

NAG_TEMP=1000   # max warmth — visually punishing

log() { echo "[$(date '+%H:%M:%S')] enforce: $*" >> "$LOG"; }

mkdir -p "$DONE_DIR"

# Active window: 22:00–01:59
hour=$((10#$(date +%H)))
if (( hour < 22 && hour >= 2 )); then
    exit 0
fi

# Already logged? Lift any leftover friction & exit.
if [[ -f "$DONE_FLAG" ]]; then
    if [[ -f "$FRICTION_FLAG" ]]; then
        log "done flag exists but friction still active — cleaning up"
        bash "$DAYLOG_SH" --lift-only 2>/dev/null || true
    fi
    exit 0
fi

# Already friction-active? Just relaunch rofi (don't re-stack wallpaper).
if [[ -f "$FRICTION_FLAG" ]]; then
    log "re-prompting (friction already on)"
    setsid "$DAYLOG_SH" >/dev/null 2>&1 < /dev/null &
    exit 0
fi

# --- Apply friction ---
log "applying friction"

# Save current wallpaper path
cur_wall=$(jq -r '.wallpaperPath // empty' "$WALLP_CONFIG" 2>/dev/null)
if [[ -n "$cur_wall" && -f "$cur_wall" ]]; then
    echo "$cur_wall" > "$PREV_WALL_FILE"
fi

# Save current temperature
cur_temp=$(hyprctl hyprsunset temperature 2>/dev/null | head -1)
if [[ "$cur_temp" =~ ^[0-9]+$ ]]; then
    echo "$cur_temp" > "$PREV_TEMP_FILE"
fi

# Apply nag temperature
hyprctl hyprsunset temperature "$NAG_TEMP" >/dev/null 2>&1

# Apply nag wallpaper
if [[ -f "$NAG_WALL" ]]; then
    "$SWITCHWALL" "$NAG_WALL" >/dev/null 2>&1 &
else
    log "nag wallpaper not found at $NAG_WALL"
fi

touch "$FRICTION_FLAG"

notify-send -u critical "Daylog" "Log your day to lift the warm tint"

# Launch the prompt now (detached so timer service exits cleanly)
setsid "$DAYLOG_SH" >/dev/null 2>&1 < /dev/null &
