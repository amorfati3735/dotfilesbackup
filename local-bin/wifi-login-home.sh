#!/bin/bash
# Home WiFi auto-connect: try JioFiber-1 first, fall back to phone hotspot.

PRIMARY="JioFiber-1"
HOTSPOT="OnePlus Nord CE3"

refresh_zen() {
  if hyprctl clients -j | jq -e '.[] | select(.class == "zen" or .class == "zen-browser")' &>/dev/null; then
    sleep 0.5
    hyprctl dispatch sendshortcut "CTRL, R, class:^(zen|zen-browser)$"
  fi
}

try_connect() {
  local ssid="$1"
  local attempts="$2"
  for attempt in $(seq 1 "$attempts"); do
    notify-send "Network" "Connecting to $ssid (attempt $attempt)..." -i network-wireless -t 3000
    if nmcli device wifi connect "$ssid" 2>/dev/null; then
      notify-send "Network" "Connected to $ssid" -i network-wireless -t 3000
      refresh_zen
      return 0
    fi
    sleep 4
  done
  return 1
}

nmcli device disconnect wlan0 2>/dev/null

if try_connect "$PRIMARY" 2; then
  exit 0
fi

notify-send "Network" "$PRIMARY failed, falling back to $HOTSPOT..." -i network-error -t 3000

if try_connect "$HOTSPOT" 2; then
  exit 0
fi

notify-send "Network" "Failed to connect to $HOTSPOT" -i network-error -t 3000
exit 1
