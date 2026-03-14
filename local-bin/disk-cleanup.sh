#!/usr/bin/env bash
# disk-cleanup.sh — Safe periodic disk cleanup for EndeavourOS
# Run: ~/.local/bin/disk-cleanup.sh
# Dry run: ~/.local/bin/disk-cleanup.sh --dry-run

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

freed_total=0

dir_size() {
    du -sb "$1" 2>/dev/null | awk '{print $1}' || echo 0
}

human_size() {
    numfmt --to=iec --suffix=B "$1" 2>/dev/null || echo "${1}B"
}

clean_dir() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then
        local size
        size=$(dir_size "$path")
        if [[ "$size" -gt 0 ]]; then
            if $DRY_RUN; then
                echo -e "  ${YELLOW}[dry-run]${NC} Would clean $label: $(human_size "$size")"
            else
                rm -rf "${path:?}"/*
                echo -e "  ${GREEN}✓${NC} Cleaned $label: $(human_size "$size")"
            fi
            freed_total=$((freed_total + size))
        fi
    fi
}

remove_dir() {
    local label="$1" path="$2"
    if [[ -d "$path" ]]; then
        local size
        size=$(dir_size "$path")
        if [[ "$size" -gt 0 ]]; then
            if $DRY_RUN; then
                echo -e "  ${YELLOW}[dry-run]${NC} Would remove $label: $(human_size "$size")"
            else
                rm -rf "${path:?}"
                echo -e "  ${GREEN}✓${NC} Removed $label: $(human_size "$size")"
            fi
            freed_total=$((freed_total + size))
        fi
    fi
}

echo -e "${CYAN}━━━ Disk Cleanup ━━━${NC}"
echo -e "Mode: $($DRY_RUN && echo "${YELLOW}DRY RUN${NC}" || echo "${GREEN}LIVE${NC}")"
echo ""

# --- Disk status ---
echo -e "${CYAN}[Disk before]${NC}"
df -h / | tail -1 | awk '{printf "  %s used / %s total (%s)\n", $3, $2, $5}'
echo ""

# --- Browser caches ---
echo -e "${CYAN}[Browser caches]${NC}"
# Only clean HTTP cache dirs inside Zen profiles, preserving session/cookie data
for d in "$HOME"/.cache/zen/*/cache2; do
    [[ -d "$d" ]] && clean_dir "Zen cache2 ($(basename "$(dirname "$d")"))" "$d"
done
for d in "$HOME"/.cache/mozilla/firefox/*/cache2; do
    [[ -d "$d" ]] && clean_dir "Firefox cache2 ($(basename "$(dirname "$d")"))" "$d"
done

# --- App caches ---
echo -e "${CYAN}[App caches]${NC}"
clean_dir "Spotify cache" "$HOME/.cache/spotify"
clean_dir "VS Code cpptools" "$HOME/.cache/vscode-cpptools"
clean_dir "Quickshell cache" "$HOME/.cache/quickshell"
clean_dir "Thumbnails" "$HOME/.cache/thumbnails"

# --- Dev caches ---
echo -e "${CYAN}[Dev caches]${NC}"
clean_dir "Go build cache" "$HOME/.cache/go-build"
clean_dir "node-gyp cache" "$HOME/.cache/node-gyp"
clean_dir "Playwright cache" "$HOME/.cache/ms-playwright-go"

if command -v npm &>/dev/null; then
    local_npm_size=$(npm cache ls 2>/dev/null | wc -c || echo 0)
    if [[ "$local_npm_size" -gt 0 ]]; then
        if $DRY_RUN; then
            echo -e "  ${YELLOW}[dry-run]${NC} Would clean npm cache"
        else
            npm cache clean --force 2>/dev/null
            echo -e "  ${GREEN}✓${NC} Cleaned npm cache"
        fi
    fi
fi

# --- AUR build caches ---
echo -e "${CYAN}[AUR build caches]${NC}"
clean_dir "paru clone cache" "$HOME/.cache/paru/clone"
clean_dir "paru diff cache" "$HOME/.cache/paru/diff"
remove_dir "yay cache" "$HOME/.cache/yay"
remove_dir "~/paru build dir" "$HOME/paru"

# --- Pacman cache (keep latest 2 versions) — needs sudo ---
echo -e "${CYAN}[Pacman cache] ${YELLOW}(needs sudo)${NC}"
if command -v paccache &>/dev/null; then
    cache_size=$(du -sh /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[dry-run]${NC} Pacman cache is ${cache_size:-unknown}"
        echo -e "  ${YELLOW}[dry-run]${NC} Run manually: sudo paccache -rk2"
    elif [[ $EUID -eq 0 ]]; then
        paccache -rk2 2>/dev/null && echo -e "  ${GREEN}✓${NC} Trimmed pacman cache (kept last 2 versions)"
    else
        echo -e "  ${YELLOW}⚠${NC} Pacman cache is ${cache_size:-unknown} — run: ${CYAN}sudo paccache -rk2${NC}"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} paccache not found (install pacman-contrib)"
fi

# --- Old journal logs (keep 2 weeks) — needs sudo ---
echo -e "${CYAN}[System logs] ${YELLOW}(needs sudo)${NC}"
if $DRY_RUN; then
    echo -e "  ${YELLOW}[dry-run]${NC} Run manually: sudo journalctl --vacuum-time=2weeks"
elif [[ $EUID -eq 0 ]]; then
    journalctl --vacuum-time=2weeks 2>/dev/null && echo -e "  ${GREEN}✓${NC} Vacuumed journal logs (kept 2 weeks)"
else
    log_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '[\d.]+[KMGT]' || echo "unknown")
    echo -e "  ${YELLOW}⚠${NC} Journal logs using ${log_size} — run: ${CYAN}sudo journalctl --vacuum-time=2weeks${NC}"
fi

# --- Orphan packages — needs sudo ---
echo -e "${CYAN}[Orphan packages] ${YELLOW}(needs sudo)${NC}"
orphans=$(pacman -Qdtq 2>/dev/null || true)
if [[ -n "$orphans" ]]; then
    count=$(echo "$orphans" | wc -l)
    if $DRY_RUN; then
        echo -e "  ${YELLOW}[dry-run]${NC} Found $count orphan packages:"
        echo "$orphans" | sed 's/^/    /'
    elif [[ $EUID -eq 0 ]]; then
        echo "$orphans" | pacman -Rns --noconfirm - 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} Removed $count orphan packages"
    else
        echo -e "  ${YELLOW}⚠${NC} $count orphan packages — run: ${CYAN}sudo pacman -Rns \$(pacman -Qdtq)${NC}"
    fi
else
    echo -e "  ${GREEN}✓${NC} No orphan packages"
fi

# --- Summary ---
echo ""
echo -e "${CYAN}━━━ Summary ━━━${NC}"
if $DRY_RUN; then
    echo -e "  Would free: ${YELLOW}~$(human_size "$freed_total")${NC}"
else
    echo -e "  Freed: ${GREEN}~$(human_size "$freed_total")${NC}"
fi
echo ""
echo -e "${CYAN}[Disk after]${NC}"
df -h / | tail -1 | awk '{printf "  %s used / %s total (%s)\n", $3, $2, $5}'
