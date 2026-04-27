#!/bin/bash
# Exam Lock — persistent baseline distraction blocker.
# - Force-closes windows whose title matches "## Blocked Terms" in focus-blocklist.md
# - Blocks websites in "## Blocked Websites" via /etc/hosts
# - Disabling requires typing a passphrase EXACTLY (no shortcut, no toggle)
#
# Usage:
#   exam-lock.sh enable     # start daemon + block hosts (idempotent)
#   exam-lock.sh disable    # passphrase challenge -> stop daemon + unblock hosts
#   exam-lock.sh status     # show running state
#   exam-lock.sh edit       # open blocklist for editing

SCRIPT_DIR="$HOME/.config/hypr/custom/scripts"
MONITOR="$SCRIPT_DIR/exam-lock-monitor.sh"
HOSTS_BLOCK="$SCRIPT_DIR/focus-hosts-block.sh"
PASSPHRASE_FILE="$SCRIPT_DIR/exam-lock-passphrase.txt"
BLOCKLIST="$SCRIPT_DIR/focus-blocklist.md"
PID_FILE="/tmp/exam-lock.pid"
LOG_FILE="/tmp/exam-lock.log"
BREAK_LOG="$HOME/Documents/notes/exam-lock-breaks.md"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [main] $*" >> "$LOG_FILE"
}

is_running() {
    [[ -f "$PID_FILE" ]] || return 1
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

enable_lock() {
    if is_running; then
        notify-send -a "Exam Lock" "🔒 Already active" "PID $(cat "$PID_FILE")"
        log "enable: already running"
        return 0
    fi

    # Block websites (idempotent, polkit-authed)
    "$HOSTS_BLOCK" block

    # Spawn the monitor detached
    setsid "$MONITOR" >/dev/null 2>&1 < /dev/null &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    log "enable: started monitor PID=$pid"
    notify-send -a "Exam Lock" -u normal "🔒 Exam Lock active" "Eyes on the prize."
}

disable_lock() {
    if ! is_running && ! grep -qF "# >>> focus-mode-block" /etc/hosts 2>/dev/null; then
        notify-send -a "Exam Lock" "Already inactive"
        log "disable: not active"
        return 0
    fi

    # Spawn the passphrase challenge in a kitty terminal.
    # The challenge script writes "OK" to a temp file on success.
    local result_file
    result_file=$(mktemp /tmp/exam-lock-challenge.XXXXXX)
    chmod 600 "$result_file"

    kitty --title "exam-lock-challenge" \
        --override "font_size=14" \
        --override "remember_window_size=no" \
        --override "initial_window_width=1100" \
        --override "initial_window_height=700" \
        bash -c "
            clear
            echo
            echo '  ╔══════════════════════════════════════════════════════════════╗'
            echo '  ║                  EXAM LOCK — DISABLE PROMPT                  ║'
            echo '  ╚══════════════════════════════════════════════════════════════╝'
            echo
            echo '  Type the passphrase below EXACTLY (whitespace, line breaks, all of it).'
            echo '  When done, press Ctrl+D on a new line.'
            echo '  Press Ctrl+C to give up and stay locked in (recommended).'
            echo
            echo '  ── PASSPHRASE ────────────────────────────────────────────────────'
            cat '$PASSPHRASE_FILE'
            echo
            echo '  ──────────────────────────────────────────────────────────────────'
            echo
            echo '  Your input:'
            echo
            typed=\$(cat)
            expected=\$(cat '$PASSPHRASE_FILE')
            if [[ \"\$typed\" == \"\$expected\" ]]; then
                echo
                echo '  ✓ Match. Lock disabled.'
                echo 'OK' > '$result_file'
                sleep 2
            else
                echo
                echo '  ✗ Mismatch. Lock stays on.'
                echo 'FAIL' > '$result_file'
                sleep 3
            fi
        "

    local result
    result=$(cat "$result_file" 2>/dev/null)
    rm -f "$result_file"

    if [[ "$result" != "OK" ]]; then
        log "disable: challenge failed"
        notify-send -a "Exam Lock" -u critical "🔒 Stayed locked" "Passphrase mismatch (or canceled)."
        # Log failed attempt
        mkdir -p "$(dirname "$BREAK_LOG")"
        echo "- $(date '+%Y-%m-%d %H:%M') — failed disable attempt" >> "$BREAK_LOG"
        return 1
    fi

    # Kill monitor
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
        log "disable: killed monitor PID=$pid"
    fi

    # Unblock hosts
    "$HOSTS_BLOCK" unblock

    # Log the break to a journal so you can confront the pattern later
    mkdir -p "$(dirname "$BREAK_LOG")"
    echo "- $(date '+%Y-%m-%d %H:%M') — disabled exam-lock" >> "$BREAK_LOG"

    log "disable: complete"
    notify-send -a "Exam Lock" -u normal "🔓 Lock disabled" "You broke the seal. Logged to exam-lock-breaks.md"
}

status() {
    if is_running; then
        local pid
        pid=$(cat "$PID_FILE")
        echo "exam-lock: ACTIVE (monitor PID=$pid)"
    else
        echo "exam-lock: inactive"
    fi
    if grep -qF "# >>> focus-mode-block" /etc/hosts 2>/dev/null; then
        echo "hosts:     BLOCKED"
    else
        echo "hosts:     not blocked"
    fi
    echo
    echo "Blocklist (from $BLOCKLIST):"
    awk '/^## Blocked (Websites|Terms)/{p=1; print "  " $0; next} /^## /{p=0} p' "$BLOCKLIST"
}

case "$1" in
    enable|on|start)   enable_lock ;;
    disable|off|stop)  disable_lock ;;
    status)            status ;;
    edit)              ${EDITOR:-nvim} "$BLOCKLIST" ;;
    *)
        cat <<EOF
Usage: $0 [enable|disable|status|edit]

  enable   Start the title-killing daemon and block listed websites.
  disable  Passphrase challenge, then unblock everything.
  status   Show whether lock is active and what's blocked.
  edit     Edit the shared blocklist (focus-blocklist.md).
EOF
        ;;
esac
