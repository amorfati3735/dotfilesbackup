#!/bin/bash
# Auto-restart wrapper for Quickshell
# Respawns on crash after a 1-second cooldown
# NOTE: We cannot auto-close the crash reporter popup! Doing so causes an infinite spawn loop.
# It MUST be closed manually by clicking "Exit".

while true; do
    qs -c "$1"
    echo "[qs-wrapper] Quickshell exited, restarting in 1s..."
    sleep 1
done
