#!/bin/bash
# Comprehensive dotfiles + hypr backup to GitHub
# Usage:
#   dotfiles-backup.sh --auto    (timer: timestamp commit, no prompt)
#   dotfiles-backup.sh           (manual: rofi prompt for commit message)

AUTO=false
if [[ "$1" == "--auto" ]]; then
    AUTO=true
fi

BACKUP_DIR="$HOME/backups/dotfiles"
HYPR_DIR="$HOME/.config/hypr"
mkdir -p "$BACKUP_DIR"

# ─── Configs to back up (relative to ~/.config/) ───
CONFIGS=(
    # Terminal / editor
    kitty
    foot
    micro
    # System / DE
    hypr
    quickshell
    matugen
    fontconfig
    # Bar / launcher / notifications
    waybar
    fuzzel
    rofi
    # Apps
    btop
    mpv
    cava
    fastfetch
    # GTK theming
    gtk-3.0
    gtk-4.0
)

for cfg in "${CONFIGS[@]}"; do
    if [ -e "$HOME/.config/$cfg" ]; then
        mkdir -p "$BACKUP_DIR/$cfg"
        rsync -a --delete \
            --exclude='.cache' \
            --exclude='__pycache__' \
            --exclude='*.pyc' \
            --exclude='.git' \
            "$HOME/.config/$cfg/" "$BACKUP_DIR/$cfg/"
    fi
done

# ─── Fish shell config ───
if [ -d "$HOME/.config/fish" ]; then
    mkdir -p "$BACKUP_DIR/fish"
    rsync -a --delete "$HOME/.config/fish/" "$BACKUP_DIR/fish/"
fi

# ─── Shell dotfiles ───
cp "$HOME/.bashrc" "$BACKUP_DIR/bashrc"
cp "$HOME/.bash_profile" "$BACKUP_DIR/bash_profile" 2>/dev/null
cp "$HOME/.profile" "$BACKUP_DIR/profile" 2>/dev/null
cp "$HOME/.gitconfig" "$BACKUP_DIR/gitconfig"

# ─── Scripts ───
mkdir -p "$BACKUP_DIR/local-bin"
rsync -a --delete "$HOME/.local/bin/" "$BACKUP_DIR/local-bin/" \
    --exclude='dotfiles-backup.sh.bak*' \
    --exclude='*.backup*'
mkdir -p "$BACKUP_DIR/scripts"
rsync -a --delete "$HOME/scripts/" "$BACKUP_DIR/scripts/"

# ─── Systemd user units ───
if [ -d "$HOME/.config/systemd/user" ]; then
    mkdir -p "$BACKUP_DIR/systemd-user"
    rsync -a --delete \
        --exclude='default.target.wants' \
        --exclude='timers.target.wants' \
        --exclude='graphical-session.target.wants' \
        "$HOME/.config/systemd/user/" "$BACKUP_DIR/systemd-user/"
fi

# ─── Package lists ───
pacman -Qqe  > "$BACKUP_DIR/pkglist.txt"
pacman -Qqem > "$BACKUP_DIR/aur-pkglist.txt"

# ─── Enabled systemd user services ───
systemctl --user list-unit-files --state=enabled --no-pager --no-legend \
    > "$BACKUP_DIR/enabled-services.txt" 2>/dev/null

# ─── System configs (need readable copies) ───
mkdir -p "$BACKUP_DIR/etc"
for f in /etc/pacman.conf /etc/mkinitcpio.conf /etc/environment; do
    [ -r "$f" ] && cp "$f" "$BACKUP_DIR/etc/"
done

# ─── dconf dump (GTK/app settings) ───
if command -v dconf >/dev/null 2>&1; then
    dconf dump / > "$BACKUP_DIR/dconf-dump.ini" 2>/dev/null
fi

# ─── Determine commit message ───
get_commit_msg() {
    if [[ "$AUTO" == true ]]; then
        echo "backup: $(date '+%Y-%m-%d %H:%M')"
        return
    fi
    local msg=""
    if command -v rofi >/dev/null 2>&1; then
        msg=$(rofi -dmenu -p "Commit message:" -l 0 < /dev/null) || true
    fi
    if [ -z "$msg" ] && command -v wofi >/dev/null 2>&1; then
        msg=$(wofi --dmenu -p "Commit message:" < /dev/null) || true
    fi
    if [ -z "$msg" ] && [ -t 0 ]; then
        read -rp "Enter commit message: " msg
    fi
    if [ -z "$msg" ]; then
        msg="backup: $(date '+%Y-%m-%d %H:%M')"
    fi
    echo "$msg"
}

COMMIT_MSG=$(get_commit_msg)

# ─── Helper: commit & push a git repo ───
push_repo() {
    local dir="$1" label="$2"
    cd "$dir" || return 1

    if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo "$label: no changes."
        return 0
    fi

    git add -A
    git commit -m "$COMMIT_MSG"
    git push origin main
    echo "$label: pushed."
    return 0
}

# ─── Push dotfiles repo ───
DOTFILES_OK=false
HYPR_OK=false

push_repo "$BACKUP_DIR" "Dotfiles" && DOTFILES_OK=true

# ─── Push hypr-dots repo (separate git repo at ~/.config/hypr) ───
if [ -d "$HYPR_DIR/.git" ]; then
    push_repo "$HYPR_DIR" "Hypr-dots" && HYPR_OK=true
fi

# ─── Notification ───
if [[ "$DOTFILES_OK" == true || "$HYPR_OK" == true ]]; then
    notify-send -a "Backup" "Dotfiles backup" "Pushed to GitHub: $COMMIT_MSG" -i dialog-information
elif [[ "$AUTO" == false ]]; then
    notify-send -a "Backup" "Dotfiles backup" "No changes to push" -i dialog-information
fi
