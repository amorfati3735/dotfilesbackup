#!/bin/bash
# Launch GNOME Clocks tiled on the left with ~377px width
# shellcheck source=/dev/null
. "$HOME/.local/bin/hypr-dispatch.sh"

# If already running, focus it
if hyprctl clients -j | jq -e '.[] | select(.class == "org.gnome.clocks")' >/dev/null 2>&1; then
    hd_focus_window "class:org.gnome.clocks"
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
hd_focus_window "class:org.gnome.clocks"
hd_layoutmsg swapwithmaster
hd_layoutmsg orientationleft

# Resize: default is 50% (960px), we want 377px, so shrink by 583px
hd_resize_active -583 0
