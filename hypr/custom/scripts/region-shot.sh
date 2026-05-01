#!/usr/bin/env bash
# Region-shot: capture a remembered screen region into an Obsidian note.
#   region-shot.sh           -> capture (re-selects if no state)
#   region-shot.sh --reselect-> force re-select region + rofi for note name

set -euo pipefail

VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
ATT_DIR="$VAULT/attachments/region-shots"
STATE_DIR="$HOME/.cache/region-shot"
REGION_FILE="$STATE_DIR/region"
NOTE_FILE="$STATE_DIR/note"

mkdir -p "$STATE_DIR" "$ATT_DIR"

reselect() {
    local current=""
    [[ -f "$NOTE_FILE" ]] && current="$(cat "$NOTE_FILE")"

    local name
    name=$(printf '%s' "$current" | rofi -dmenu -p "Region note name" \
            -theme-str 'window {width: 30em;}' || true)
    [[ -z "${name// }" ]] && { notify-send "Region-shot" "Cancelled"; exit 0; }
    name="${name%.md}"

    local region
    region=$(slurp -d 2>/dev/null || true)
    [[ -z "$region" ]] && { notify-send "Region-shot" "No region selected"; exit 0; }

    printf '%s' "$region" > "$REGION_FILE"
    printf '%s' "$name"   > "$NOTE_FILE"

    # Ensure the note exists
    [[ -f "$VAULT/$name.md" ]] || : > "$VAULT/$name.md"

    notify-send "Region-shot" "Region set → $name.md\n$region"
    capture
}

capture() {
    local region note ts img link
    region="$(cat "$REGION_FILE")"
    note="$(cat "$NOTE_FILE")"
    ts="$(date +%Y%m%d%H%M%S)"
    img="Pasted image ${ts}.png"

    grim -g "$region" "$ATT_DIR/$img"

    link="![[${img}]]"
    # blank line before link if file has content
    if [[ -s "$VAULT/$note.md" ]]; then
        printf '\n%s\n' "$link" >> "$VAULT/$note.md"
    else
        printf '%s\n' "$link" >> "$VAULT/$note.md"
    fi

    notify-send -i "$ATT_DIR/$img" "Region-shot" "→ $note.md"
}

case "${1:-}" in
    --reselect) reselect ;;
    *)
        if [[ -f "$REGION_FILE" && -f "$NOTE_FILE" ]]; then
            capture
        else
            reselect
        fi
        ;;
esac
