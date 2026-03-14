#!/bin/bash
socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do
    if [[ "$line" == openwindow*org.quickshell* ]]; then
        # A normal window from Quickshell opened (crash reporter)
        echo "Crash reporter detected, closing..."
        ADDRESS=$(echo "$line" | grep -oP 'openwindow>>\K[0-9a-f]+' || true)
        if [ ! -z "$ADDRESS" ]; then
            hyprctl dispatch closewindow "address:0x$ADDRESS"
        else
            hyprctl dispatch closewindow "class:org.quickshell"
        fi
    fi
done
