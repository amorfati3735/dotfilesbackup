#!/bin/bash
hyprctl dispatch -- exec "[noinitialfocus]" env MOZ_APP_REMOTINGNAME=chatgpt-zen zen-browser --no-remote -P chatgpt-scratchpad https://chatgpt.com https://keep.google.com/u/0/ &
