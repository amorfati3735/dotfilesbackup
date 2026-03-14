#!/usr/bin/env bash
set -euo pipefail

VAULT="/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala"
REPO_DIR="$HOME/.local/share/obsidian-vault-backup"
MAX_SIZE="10M"

notify() { notify-send -i folder-sync "Obsidian Backup" "$1"; }

if [[ ! -d "$VAULT" ]]; then
    notify "❌ Vault not found — is Windows partition mounted?"
    exit 1
fi

if [[ ! -d "$REPO_DIR/.git" ]]; then
    mkdir -p "$REPO_DIR"
    git -C "$REPO_DIR" init -b main
fi

rsync -a --delete \
    --exclude='.git/' \
    --exclude='.obsidian/' \
    --exclude='.trash/' \
    --include='*/' \
    --include='*.md' \
    --include='*.txt' \
    --exclude='*' \
    "$VAULT/" "$REPO_DIR/"

cd "$REPO_DIR"

# Generate .gitignore for files over 10MB
find . -type f -size +$MAX_SIZE -not -path './.git/*' | sed 's|^\./||' > .gitignore

git add -A

if git diff --cached --quiet; then
    notify "✅ Already up to date"
    exit 0
fi

git commit -m "vault backup: $(date '+%Y-%m-%d %H:%M')"
notify "✅ Vault backed up locally"
