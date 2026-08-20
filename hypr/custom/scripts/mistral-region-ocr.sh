#!/usr/bin/env bash

set -u

if pgrep -x slurp >/dev/null; then
    exit 0
fi

region=$(slurp ${SLURP_ARGS:-} 2>/dev/null) || exit 0
[[ -n "$region" ]] || exit 0

workdir=$(mktemp -d /tmp/mistral-region-ocr.XXXXXX)
trap 'rm -rf -- "$workdir"' EXIT

if ! grim -g "$region" "$workdir/capture.png"; then
    notify-send -a "Mistral OCR" -u critical "Capture failed"
    exit 1
fi

if [[ -z ${MISTRAL_API_KEY:-} && -f $HOME/.env_secrets ]]; then
    # qocr expects MISTRAL_API_KEY in its environment.
    source "$HOME/.env_secrets"
fi

notify-send -a "Mistral OCR" -t 2000 "Reading selection…"

if ! "$HOME/bin/qocr" "$workdir/capture.png" -o "$workdir/result.md" >"$workdir/qocr.log" 2>&1; then
    notify-send -a "Mistral OCR" -u critical "OCR failed" "Run qocr in a terminal to inspect the error."
    exit 1
fi

# A region capture is always one page, so omit qocr's page marker from the clipboard.
sed -e '/^<!-- page [0-9][0-9]* -->$/d' -e '/./,$!d' "$workdir/result.md" | wl-copy
notify-send -a "Mistral OCR" -t 2500 "Copied to clipboard"
