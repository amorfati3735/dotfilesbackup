#!/bin/bash
# Launch calc-black-three.vercel.app as a Chrome web app, tiled on the left

CLASS="calc-black-three"
URL="https://calc-black-three.vercel.app/"

# If already running, focus it
if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null 2>&1; then
    hyprctl dispatch focuswindow class:"$CLASS"
    exit 0
fi

# Launch and wait for window to appear
google-chrome-stable --app="$URL" --class="$CLASS" >/dev/null 2>&1 &
for i in $(seq 1 30); do
    sleep 0.1
    if hyprctl clients -j | jq -e --arg c "$CLASS" '.[] | select(.class == $c)' >/dev/null 2>&1; then
        break
    fi
done

sleep 0.2

# Focus the calc window and move it to the left
hyprctl dispatch focuswindow class:"$CLASS"
hyprctl dispatch layoutmsg swapwithmaster
hyprctl dispatch layoutmsg orientationleft

# Resize: default is 50% (960px), we want 377px, so shrink by 583px
hyprctl dispatch resizeactive -- -583 0
