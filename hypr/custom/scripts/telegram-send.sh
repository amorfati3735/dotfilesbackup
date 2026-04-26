#!/bin/bash
# Quick send a message or file to phone via Telegram bot
source ~/.config/hypr/custom/scripts/focus-rofi-theme.sh

MODE=$(printf "💬 Message\n📎 File" | focus_rofi "📩 Telegram" "Send to phone..." "list")
[[ -z "$MODE" ]] && exit 0

case "$MODE" in
    *Message*)
        MSG=$(focus_rofi "💬 Message" "Type a message..." "input")
        [[ -z "$MSG" ]] && exit 0
        if telegram-send "$MSG" 2>/dev/null; then
            notify-send -a "Telegram" "📩 Sent" "$MSG" -t 3000
        else
            notify-send -a "Telegram" "❌ Failed to send" "$MSG" -t 5000
        fi
        ;;
    *File*)
        FILES=$(zenity --file-selection --multiple --separator='|' --filename="$HOME/Downloads/" --title="Pick file(s) to send" 2>/dev/null)
        [[ -z "$FILES" ]] && exit 0

        SUCCESS=0
        FAIL=0
        IFS='|' read -ra FILE_ARR <<< "$FILES"
        for FILE in "${FILE_ARR[@]}"; do
            if telegram-send --file "$FILE" 2>/dev/null; then
                SUCCESS=$((SUCCESS + 1))
            else
                FAIL=$((FAIL + 1))
            fi
        done

        TOTAL=${#FILE_ARR[@]}
        if [[ "$FAIL" -eq 0 ]]; then
            notify-send -a "Telegram" "📎 Sent $SUCCESS file(s)" -t 3000
        else
            notify-send -a "Telegram" "📎 Sent $SUCCESS/$TOTAL" "$FAIL failed" -t 5000
        fi
        ;;
esac
