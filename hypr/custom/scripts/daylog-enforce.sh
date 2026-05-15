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
# Logical day rolls over at 4am — 00:00-03:59 count as the previous day
TODAY=$(date -d '4 hours ago' '+%Y-%m-%d')
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

# Refresh Hyprland instance signature in case the session was restarted
# (systemd user env can hold a stale sig pointing to a dead socket).
if [[ -d /run/user/$(id -u)/hypr ]]; then
    latest_sig=$(find "/run/user/$(id -u)/hypr" -maxdepth 1 -mindepth 1 -type d \
        -printf '%T@ %f\n' 2>/dev/null | sort -nr | head -1 | awk '{print $2}')
    if [[ -n "$latest_sig" ]]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$latest_sig"
    fi
fi

# Active window: 22:00–03:59 (matches the 4am logical-day rollover)
hour=$((10#$(date +%H)))
if (( hour < 22 && hour >= 4 )); then
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

# Save current wallpaper path (config first, quickshell state as fallback)
cur_wall=$(jq -r '.wallpaperPath // empty' "$WALLP_CONFIG" 2>/dev/null)
if [[ -z "$cur_wall" || ! -f "$cur_wall" ]]; then
    state_wall=$(cat "$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt" 2>/dev/null)
    [[ -n "$state_wall" && -f "$state_wall" ]] && cur_wall="$state_wall"
fi
if [[ -n "$cur_wall" && -f "$cur_wall" ]]; then
    echo "$cur_wall" > "$PREV_WALL_FILE"
    log "saved prev wall: $cur_wall"
else
    log "WARN: could not determine current wallpaper"
fi

# Save current temperature, then apply nag temperature.
# If the daemon isn't running or the socket is dead, restart it ourselves.
cur_temp=$(hyprctl hyprsunset temperature 2>/dev/null | head -1)
if [[ "$cur_temp" =~ ^[0-9]+$ ]]; then
    echo "$cur_temp" > "$PREV_TEMP_FILE"
fi

if ! hyprctl hyprsunset temperature "$NAG_TEMP" >/dev/null 2>&1; then
    log "hyprctl failed — (re)spawning hyprsunset at ${NAG_TEMP}K via systemd-run"
    pkill -x hyprsunset 2>/dev/null
    systemctl --user reset-failed daylog-hyprsunset 2>/dev/null
    systemctl --user stop daylog-hyprsunset 2>/dev/null
    sleep 0.3
    # Run as a transient user unit so it survives this oneshot service exiting
    systemd-run --user --quiet --unit=daylog-hyprsunset --collect \
        hyprsunset --temperature "$NAG_TEMP" >/dev/null 2>&1 \
        || log "systemd-run also failed"
    sleep 0.5
fi

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
