#!/bin/bash
MAC="08:12:87:86:4A:46"

if bluetoothctl info "$MAC" 2>/dev/null | grep -q "Connected: yes"; then
    notify-send "Nord Buds 3" "Reconnecting..." -i bluetooth -t 3000
    bluetoothctl disconnect "$MAC"
    sleep 3
    bluetoothctl connect "$MAC"
else
    notify-send "Nord Buds 3" "Connecting..." -i bluetooth -t 3000
    bluetoothctl connect "$MAC"
fi
