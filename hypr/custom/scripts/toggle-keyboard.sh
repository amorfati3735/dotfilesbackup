#!/bin/bash
# Toggle internal laptop keyboard on/off
# Press Delete key on the internal keyboard to re-enable
# Device: AT Translated Set 2 keyboard (event2)

DEVICE="/dev/input/event2"
PID_FILE="/tmp/keyboard-disabled.pid"

disable_keyboard() {
    # evtest --grab exclusively grabs the device — all input is swallowed
    # We monitor output for Delete key press to re-enable
    notify-send "🚫 Keyboard DISABLED" "Press Delete on laptop keyboard to re-enable"
    
    sudo evtest --grab "$DEVICE" 2>/dev/null | while IFS= read -r line; do
        # KEY_DELETE (code 111), value 1 = key press
        if echo "$line" | grep -q "code 111.*value 1"; then
            # Kill the evtest process to release the grab
            sudo pkill -f "evtest --grab $DEVICE"
            notify-send "⌨️ Keyboard ENABLED" "Internal keyboard is back on"
            break
        fi
    done
}

# If already disabled, kill it
if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null
    sudo pkill -f "evtest --grab $DEVICE" 2>/dev/null
    rm -f "$PID_FILE"
    notify-send "⌨️ Keyboard ENABLED" "Internal keyboard is back on"
    exit 0
fi

# Disable in background
disable_keyboard &
echo $! > "$PID_FILE"
# Clean up pid file when background process exits
(wait $!; rm -f "$PID_FILE") &
