#!/bin/bash
# Close Quickshell's crash-reporter window as soon as it appears.
# shellcheck source=/dev/null
. "$HOME/.local/bin/hypr-dispatch.sh"

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Any of these can read a unix event socket; socat was the original choice, but it is not
# installed on this machine (the script then died silently on line 5 with no output).
if command -v socat >/dev/null 2>&1; then
    listen_events() { socat -U - UNIX-CONNECT:"$SOCK"; }
elif command -v ncat >/dev/null 2>&1; then
    listen_events() { ncat --unix "$SOCK"; }
elif command -v nc >/dev/null 2>&1; then
    listen_events() { stdbuf -oL nc -U "$SOCK"; }
else
    echo "qs-crash-killer: no unix-socket reader available — install one (sudo pacman -S socat)" >&2
    exit 1
fi

listen_events | while read -r line; do
    if [[ "$line" == openwindow*org.quickshell* ]]; then
        # A normal window from Quickshell opened (crash reporter)
        echo "Crash reporter detected, closing..."
        ADDRESS=$(echo "$line" | grep -oP 'openwindow>>\K[0-9a-f]+' || true)
        if [ ! -z "$ADDRESS" ]; then
            hd_close_window "address:0x$ADDRESS"
        else
            hd_close_window "class:org.quickshell"
        fi
    fi
done
