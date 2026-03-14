#!/bin/bash
# Emergency GPU recovery - run from TTY if stuck
# Switch back to integrated mode and reboot
echo "Switching back to integrated GPU mode..."
sudo envycontrol -s integrated
echo "Done. Rebooting in 5 seconds... (Ctrl+C to cancel)"
sleep 5
sudo reboot
