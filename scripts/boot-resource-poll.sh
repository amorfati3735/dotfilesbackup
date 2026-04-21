#!/bin/bash
# Polls CPU, temp, and top processes for 60s after boot
# Logs to ~/log data/boot-polls/

LOG_DIR="$HOME/log data/boot-polls"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date '+%Y-%m-%d_%H-%M-%S').log"

DURATION=60
INTERVAL=3

echo "=== Boot Resource Poll ===" > "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"
echo "Uptime: $(uptime -p) ($(awk '{print $1}' /proc/uptime)s)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

END=$((SECONDS + DURATION))
while [ $SECONDS -lt $END ]; do
    echo "--- $(date '+%H:%M:%S') | uptime: $(awk '{print $1}' /proc/uptime)s ---" >> "$LOG_FILE"

    # CPU temps
    if command -v sensors &>/dev/null; then
        sensors 2>/dev/null | grep -E '(Core|Tctl|edge|temp)' >> "$LOG_FILE"
    fi

    # Top 10 CPU consumers
    ps aux --sort=-%cpu | head -11 | awk '{printf "%-6s %-5s %-5s %s\n", $1, $3, $4, $11}' >> "$LOG_FILE"

    # Load average
    echo "Load: $(cat /proc/loadavg)" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    sleep $INTERVAL
done

echo "=== Poll ended: $(date) ===" >> "$LOG_FILE"
