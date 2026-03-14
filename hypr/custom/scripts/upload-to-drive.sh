#!/bin/bash
# Upload files to Google Drive QuickAccess folder via rclone

REMOTE="gdriveeee:QuickAccess"

for file in "$@"; do
    name=$(basename "$file")
    if rclone copy "$file" "$REMOTE" 2>&1; then
        notify-send "Drive Upload" "✓ $name uploaded" -i drive-harddisk
    else
        notify-send "Drive Upload" "✗ Failed to upload $name" -u critical
    fi
done
