#!/bin/bash
source ~/.env_secrets

HOTSPOT="OnePlus Nord CE3"

try_login() {
  curl -s -o /dev/null -w "%{http_code}" \
    -X POST 'http://phc.prontonetworks.com/cgi-bin/authlogin?URI=http://example.com' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-raw "userId=${VIT_WIFI_USER}&password=${VIT_WIFI_PASS}&serviceName=ProntoAuthentication"
}

refresh_zen() {
  if hyprctl clients -j | jq -e '.[] | select(.class == "zen" or .class == "zen-browser")' &>/dev/null; then
    sleep 0.5
    hyprctl dispatch sendshortcut "CTRL, R, class:^(zen|zen-browser)$"
  fi
}

response=$(try_login)

if [ "$response" -eq 200 ]; then
  notify-send "N-VIT WiFi" "Login successful" -i network-wireless -t 3000
  refresh_zen
else
  notify-send "N-VIT WiFi" "Login failed (HTTP $response), retrying..." -i network-error -t 3000
  sleep 2

  # Try connecting to hotspot
  notify-send "Network" "Connecting to $HOTSPOT..." -i network-wireless -t 3000
  if nmcli device wifi connect "$HOTSPOT"; then
    notify-send "Network" "Connected to $HOTSPOT" -i network-wireless -t 3000
    refresh_zen
  else
    notify-send "Network" "Failed to connect to $HOTSPOT" -i network-error -t 3000
  fi
fi
