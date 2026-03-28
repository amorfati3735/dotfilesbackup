#!/bin/bash
# Restore custom MIME associations after kbuildsycoca6 nukes them
cp ~/.config/mimeapps.list.bak ~/.config/mimeapps.list
kbuildsycoca6 --noincremental
echo "✓ MIME associations restored"
