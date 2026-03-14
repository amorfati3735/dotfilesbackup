#!/usr/bin/env bash
# Auto-closes Quickshell crash dialogs.
# Watches for floating windows with class "org.quickshell" and closes them.
# Listens to Hyprland IPC events via nc — no polling, instant reaction.

SOCKET="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

close_crash_dialogs() {
    local output
    output=$(hyprctl clients -j 2>/dev/null) || return
    echo "$output" | python3 -c "
import json, sys, subprocess
clients = json.load(sys.stdin)
for c in clients:
    if c.get('class') == 'org.quickshell' and c.get('floating'):
        subprocess.run(['hyprctl', 'dispatch', 'closewindow', f'address:{c[\"address\"]}'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f'Closed quickshell crash dialog: {c[\"address\"]}')
" 2>/dev/null
}

# Close any existing crash dialogs on startup
close_crash_dialogs

# Listen for window open events via Hyprland IPC
nc -U "$SOCKET" 2>/dev/null | while IFS= read -r line; do
    case "$line" in
        openwindow\>\>*)
            sleep 0.3
            close_crash_dialogs
            ;;
    esac
done
