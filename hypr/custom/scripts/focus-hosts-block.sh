#!/bin/bash
# Manage /etc/hosts blocking for focus mode
# Usage: focus-hosts-block.sh [block|unblock]

BLOCKLIST="$HOME/.config/hypr/custom/scripts/focus-blocklist.md"
HOSTS="/etc/hosts"
MARKER_START="# >>> focus-mode-block"
MARKER_END="# <<< focus-mode-block"

get_blocked_domains() {
    # Parse domains from the "## Blocked Websites" section
    local in_section=false
    while IFS= read -r line; do
        if [[ "$line" == "## Blocked Websites" ]]; then
            in_section=true
            continue
        fi
        if [[ "$line" == "## "* ]] && $in_section; then
            break
        fi
        if $in_section && [[ "$line" =~ ^-\ +(.+)$ ]]; then
            echo "${BASH_REMATCH[1]}" | tr -d ' '
        fi
    done < "$BLOCKLIST"
}

block() {
    [[ ! -f "$BLOCKLIST" ]] && return 0

    local domains
    domains=$(get_blocked_domains)
    [[ -z "$domains" ]] && return 0

    # Build hosts entries
    local entries="$MARKER_START"$'\n'
    while IFS= read -r domain; do
        entries+="127.0.0.1  $domain"$'\n'
    done <<< "$domains"
    entries+="$MARKER_END"

    # Check if already blocked
    if grep -qF "$MARKER_START" "$HOSTS" 2>/dev/null; then
        return 0
    fi

    # Write via pkexec (polkit — no terminal password prompt)
    echo "$entries" | pkexec tee -a "$HOSTS" > /dev/null 2>&1
}

unblock() {
    if ! grep -qF "$MARKER_START" "$HOSTS" 2>/dev/null; then
        return 0
    fi

    # Remove the block section
    pkexec sed -i "/$MARKER_START/,/$MARKER_END/d" "$HOSTS" 2>/dev/null
}

case "$1" in
    block) block ;;
    unblock) unblock ;;
    *) echo "Usage: $0 [block|unblock]" ;;
esac
