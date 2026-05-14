#!/bin/bash
# daylog.sh — rofi-driven daily log ritual
#
# Reads ~/.config/daylog/questions.md, prompts each question via rofi (with
# the same Material You theme used by focus mode), then writes answers to:
#   - habits.md  (table at vault root, columns auto-extend)
#   - today's daynote (bullet under the configured section)
#
# On successful completion: marks today done, lifts friction (warm temp +
# nag wallpaper) if it was active, and notifies.

set -uo pipefail

CONFIG="$HOME/.config/daylog/questions.md"
VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
DAILY_DIR="$VAULT/「日常」"
HABITS="$VAULT/habits.md"
DONE_DIR="$HOME/.cache/daylog"
LOCK="/tmp/daylog.lock"
LOG="/tmp/daylog.log"
TODAY=$(date '+%Y-%m-%d')
DONE_FLAG="$DONE_DIR/done-$TODAY"
DAYNOTE="$DAILY_DIR/$(date '+%d-%b-%y').md"
PYHELPER="$HOME/.config/hypr/custom/scripts/daylog-write.py"
SWITCHWALL="$HOME/.config/quickshell/ii/scripts/colors/switchwall.sh"
FRICTION_FLAG="/tmp/daylog-friction-active"
PREV_WALL_FILE="/tmp/daylog-prev-wall"
PREV_TEMP_FILE="/tmp/daylog-prev-temp"

mkdir -p "$DONE_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

# --- CLI flags ---
if [[ "${1:-}" == "--lift-only" ]]; then
    [[ -f "$FRICTION_FLAG" ]] || exit 0
    if [[ -f "$PREV_TEMP_FILE" ]]; then
        prev_temp=$(cat "$PREV_TEMP_FILE")
        [[ -n "$prev_temp" ]] && hyprctl hyprsunset temperature "$prev_temp" >/dev/null 2>&1
    fi
    if [[ -f "$PREV_WALL_FILE" ]]; then
        prev_wall=$(cat "$PREV_WALL_FILE")
        [[ -n "$prev_wall" && -f "$prev_wall" ]] && \
            "$SWITCHWALL" "$prev_wall" >/dev/null 2>&1 &
    fi
    rm -f "$FRICTION_FLAG" "$PREV_WALL_FILE" "$PREV_TEMP_FILE"
    exit 0
fi

# --- Single-instance lock ---
exec 9>"$LOCK"
if ! flock -n 9; then
    notify-send "Daylog" "Already running"
    exit 0
fi

# --- Theme ---
# shellcheck disable=SC1091
source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

# --- Parse questions.md ---
declare -a Q_IDS=() Q_PROMPTS=() Q_TYPES=() Q_TARGETS=() Q_COLUMNS=() Q_SECTIONS=() Q_STYLES=()

parse_questions() {
    local in_q=0 cur=""
    local idx
    while IFS= read -r line; do
        if [[ "$line" =~ ^##[[:space:]]+Questions ]]; then
            in_q=1; continue
        fi
        (( in_q )) || continue
        if [[ "$line" =~ ^###[[:space:]]+(.+) ]]; then
            cur="${BASH_REMATCH[1]}"
            Q_IDS+=("$cur"); Q_PROMPTS+=(""); Q_TYPES+=("")
            Q_TARGETS+=(""); Q_COLUMNS+=(""); Q_SECTIONS+=(""); Q_STYLES+=("")
        elif [[ -n "$cur" && "$line" =~ ^-[[:space:]]+([a-z_]+):[[:space:]]*(.*)$ ]]; then
            local k="${BASH_REMATCH[1]}" v="${BASH_REMATCH[2]}"
            idx=$(( ${#Q_IDS[@]} - 1 ))
            case "$k" in
                prompt)  Q_PROMPTS[$idx]="$v" ;;
                type)    Q_TYPES[$idx]="$v" ;;
                target)  Q_TARGETS[$idx]="$v" ;;
                column)  Q_COLUMNS[$idx]="$v" ;;
                section) Q_SECTIONS[$idx]="$v" ;;
                style)   Q_STYLES[$idx]="$v" ;;
            esac
        fi
    done < "$CONFIG"
}

ask_yesno() { printf "Yes\nNo" | focus_rofi "$1" "" "list"; }
ask_text()  { focus_rofi "$1" "$2" "input"; }

# --- Friction lift ---
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

# --- Main flow ---
parse_questions

if (( ${#Q_IDS[@]} == 0 )); then
    notify-send "Daylog" "No questions defined in $CONFIG"
    exit 1
fi

declare -A ANSWERS

for i in "${!Q_IDS[@]}"; do
    id="${Q_IDS[$i]}"
    prompt="${Q_PROMPTS[$i]}"
    type="${Q_TYPES[$i]}"
    ans=""
    case "$type" in
        yesno)
            ans=$(ask_yesno "$prompt") || { log "cancelled at $id"; exit 0; }
            ;;
        number)
            ans=$(ask_text "$prompt" "number") || { log "cancelled at $id"; exit 0; }
            if [[ -n "$ans" && ! "$ans" =~ ^[0-9]+$ ]]; then
                notify-send "Daylog" "Skipping '$id' (not a number: $ans)"
                continue
            fi
            ;;
        text)
            ans=$(ask_text "$prompt" "...") || { log "cancelled at $id"; exit 0; }
            ;;
        *)
            notify-send "Daylog" "Unknown type '$type' for '$id'"
            continue
            ;;
    esac
    [[ -z "$ans" ]] && continue
    ANSWERS[$id]="$ans"
done

# Build python args in question order
PY_ARGS=()
for i in "${!Q_IDS[@]}"; do
    id="${Q_IDS[$i]}"
    if [[ -n "${ANSWERS[$id]:-}" ]]; then
        PY_ARGS+=( "$id" "${Q_TARGETS[$i]}" "${Q_COLUMNS[$i]}" "${Q_SECTIONS[$i]}" "${Q_STYLES[$i]}" "${ANSWERS[$id]}" )
    fi
done

if (( ${#PY_ARGS[@]} == 0 )); then
    notify-send "Daylog" "Nothing to log (all skipped)"
    exit 0
fi

if ! python3 "$PYHELPER" "$DAYNOTE" "$HABITS" "${PY_ARGS[@]}" 2>>"$LOG"; then
    notify-send -u critical "Daylog" "Write failed — see $LOG"
    exit 1
fi

touch "$DONE_FLAG"
lift_friction
notify-send "Daylog" "Logged ✦"
log "done"
