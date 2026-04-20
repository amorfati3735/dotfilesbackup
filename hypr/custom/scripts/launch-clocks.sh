#!/bin/bash
# Launch GNOME Clocks tiled on the left with ~377px width

# If already running, focus it
if hyprctl clients -j | jq -e '.[] | select(.class == "org.gnome.clocks")' >/dev/null 2>&1; then
    hyprctl dispatch focuswindow class:org.gnome.clocks
    exit 0
fi

# Launch and wait for window to appear
gnome-clocks &
for i in $(seq 1 30); do
    sleep 0.1
    if hyprctl clients -j | jq -e '.[] | select(.class == "org.gnome.clocks")' >/dev/null 2>&1; then
        break
    fi
done

sleep 0.2

# Focus the clocks window and move it to the left
hyprctl dispatch focuswindow class:org.gnome.clocks
hyprctl dispatch layoutmsg swapwithmaster
hyprctl dispatch layoutmsg orientationleft

# Resize: default is 50% (960px), we want 377px, so shrink by 583px
hyprctl dispatch resizeactive -- -583 0
