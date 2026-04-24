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
        FILE=$(zenity --file-selection --filename="$HOME/Downloads/" --title="Pick a file to send" 2>/dev/null)
        [[ -z "$FILE" ]] && exit 0
        if telegram-send --file "$FILE" 2>/dev/null; then
            notify-send -a "Telegram" "📎 Sent" "$(basename "$FILE")" -t 3000
        else
            notify-send -a "Telegram" "❌ Failed to send" "$(basename "$FILE")" -t 5000
        fi
        ;;
esac
