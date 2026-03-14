#!/bin/bash
source ~/.env_secrets

response=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST 'http://phc.prontonetworks.com/cgi-bin/authlogin?URI=http://example.com' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-raw "userId=${VIT_WIFI_USER}&password=${VIT_WIFI_PASS}&serviceName=ProntoAuthentication")

if [ "$response" -eq 200 ]; then
  notify-send "N-VIT WiFi" "Login successful" -i network-wireless -t 3000
else
  notify-send "N-VIT WiFi" "Login failed (HTTP $response)" -i network-error -t 3000
  notify-send "Network" "Attempting fallback to OnePlus Nord CE 3..." -i network-wireless -t 3000
  
  if nmcli device wifi connect "OnePlus Nord CE 3"; then
    notify-send "Network" "Successfully connected to OnePlus Nord CE 3" -i network-wireless -t 3000
  else
    notify-send "Network" "Failed to connect to OnePlus Nord CE 3" -i network-error -t 3000
  fi
fi
