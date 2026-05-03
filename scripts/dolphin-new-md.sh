#!/usr/bin/env bash
# Triggered by Ctrl+Shift+X in Hyprland when Dolphin is focused.
# Asks via rofi for a filename, creates an .md file in the active
# Dolphin folder, and opens it in micro (kitty terminal).

set -euo pipefail

active=$(hyprctl activewindow -j)
class=$(printf '%s' "$active" | jq -r '.class')
title=$(printf '%s' "$active" | jq -r '.title')

# Bail out silently if Dolphin isn't focused.
[[ "$class" == "org.kde.dolphin" ]] || exit 0

# Title format with ShowFullPathInTitlebar=true: "/abs/path — Dolphin"
# Strip the trailing " — Dolphin".
folder=${title% — Dolphin}

# Expand ~ if Dolphin abbreviated $HOME.
[[ "$folder" == "~"* ]] && folder="${HOME}${folder:1}"

if [[ ! -d "$folder" ]]; then
    notify-send "New .md" "Could not resolve Dolphin folder:\n$folder"
    exit 1
fi

source "$HOME/.config/hypr/custom/scripts/focus-rofi-theme.sh"

name=$(focus_rofi "new .md" "filename in $(basename "$folder")" "input") || exit 0
name=${name## }
name=${name%% }
[[ -z "$name" ]] && exit 0

# Auto-append .md if no extension given.
[[ "$name" == *.* ]] || name="${name}.md"

target="$folder/$name"

if [[ -e "$target" ]]; then
    notify-send "New .md" "Already exists:\n$target"
else
    : > "$target"
fi

exec kitty --title "micro: $name" -e micro "$target"
