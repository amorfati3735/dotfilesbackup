#!/bin/bash
VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
FILE="$VAULT/quick-jot.md"
note=$(kdialog --inputbox "Quick jot:" --title "Quick Jot" 2>/dev/null)
[ -z "$note" ] && exit 0
timestamp=$(date '+%a %b %d, %I:%M %p')
entry="- **$timestamp** — $note"
if [ -f "$FILE" ]; then
    tmp=$(mktemp)
    echo "$entry" > "$tmp"
    cat "$FILE" >> "$tmp"
    mv "$tmp" "$FILE"
else
    echo "$entry" > "$FILE"
fi
