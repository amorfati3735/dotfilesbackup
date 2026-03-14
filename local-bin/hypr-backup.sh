#!/bin/bash
# Backs up ~/.config/hypr and ~/.config/quickshell to GitHub if there are changes

HYPR_DIR="$HOME/.config/hypr"
QS_DIR="$HOME/.config/quickshell"
QS_DEST="$HYPR_DIR/quickshell"

# Sync quickshell config into the hypr repo
if [ -d "$QS_DIR" ]; then
    mkdir -p "$QS_DEST"
    rsync -a --delete --exclude='.cache' --exclude='__pycache__' "$QS_DIR/" "$QS_DEST/"
fi

cd "$HYPR_DIR" || exit 1

# Check for changes
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    notify-send -a "Backup" "Hypr + Quickshell backup" "No changes to push" -i dialog-information
    echo "No changes to backup."
    exit 0
fi

git add -A
git commit -m "backup: $(date '+%Y-%m-%d %H:%M')"
git push origin main
notify-send -a "Backup" "Hypr + Quickshell backup" "Pushed to GitHub" -i dialog-information
echo "Hyprland + Quickshell config backed up."
