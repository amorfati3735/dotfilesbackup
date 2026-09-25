#!/bin/bash
# Switch eDP-1 refresh rate based on power profile:
#   power-saver → 60Hz, otherwise → 120Hz
# shellcheck source=/dev/null
. "$HOME/.local/bin/hypr-dispatch.sh"

MONITOR="eDP-1"

set_refresh() {
    local profile="$1"
    if [[ "$profile" == "power-saver" ]]; then
        hd_monitor_set "$MONITOR" "1920x1080@60" "0x0" 1
    else
        hd_monitor_set "$MONITOR" "1920x1080@120" "0x0" 1
    fi
}

# Set on startup
set_refresh "$(powerprofilesctl get)"

# Listen for profile changes via D-Bus
dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',path=/net/hadess/PowerProfiles" 2>/dev/null |
while read -r line; do
    if [[ "$line" == *"ActiveProfile"* ]]; then
        # Next line with "variant" contains the profile name
        read -r variant_line
        profile=$(echo "$variant_line" | grep -oP 'string "\K[^"]+')
        if [[ -n "$profile" ]]; then
            set_refresh "$profile"
        fi
    fi
done
