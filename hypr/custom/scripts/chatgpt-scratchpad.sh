#!/bin/bash
# shellcheck source=/dev/null
. "$HOME/.local/bin/hypr-dispatch.sh"

hd_exec_cmd "env MOZ_APP_REMOTINGNAME=chatgpt-zen zen-browser --no-remote -P chatgpt-scratchpad https://chatgpt.com https://keep.google.com/u/0/" &
