#!/bin/bash
# Toggle wl-gammarelay-rs software brightness between 0.5 and 1.0
# Prints "on" or "off" to stdout for state tracking

BRIGHTNESS=$(busctl --user get-property rs.wl-gammarelay / rs.wl.gammarelay Brightness 2>/dev/null | awk '{print $2}')

if [ -z "$BRIGHTNESS" ]; then
    # Daemon not running, start it
    wl-gammarelay-rs &
    sleep 0.3
    busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 0.5
    echo "on"
elif (( $(echo "$BRIGHTNESS < 0.9" | bc -l) )); then
    busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 1.0
    echo "off"
else
    busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Brightness d 0.5
    echo "on"
fi
