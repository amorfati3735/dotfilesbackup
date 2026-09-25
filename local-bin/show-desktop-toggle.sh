#!/bin/bash
# Toggle "show desktop" — Super+D to go to empty workspace, Super+D again to come back
# shellcheck source=/dev/null
. "$HOME/.local/bin/hypr-dispatch.sh"

STATE_FILE="/tmp/qs-show-desktop-state"

CURRENT_WS=$(hyprctl activeworkspace -j | jq -r '.id')

if [ -f "$STATE_FILE" ]; then
    SAVED_WS=$(cat "$STATE_FILE")
    DESKTOP_WS=$(cat "/tmp/qs-show-desktop-ws" 2>/dev/null)
    
    # Only toggle back if we're still on the desktop workspace
    if [ "$CURRENT_WS" = "$DESKTOP_WS" ]; then
        rm -f "$STATE_FILE" "/tmp/qs-show-desktop-ws"
        hd_focus_workspace "$SAVED_WS"
        exit 0
    fi
    # Otherwise we've moved on — treat as fresh press
    rm -f "$STATE_FILE" "/tmp/qs-show-desktop-ws"
fi

echo "$CURRENT_WS" > "$STATE_FILE"
hd_focus_workspace empty
# Save which workspace we landed on
sleep 0.1
hyprctl activeworkspace -j | jq -r '.id' > "/tmp/qs-show-desktop-ws"
