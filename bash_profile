#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc



# Amp CLI
export PATH="/home/pratik/.amp/bin:$PATH"

if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  # Match startup refresh rate to power profile to avoid mode-switch blackout
  if [ "$(powerprofilesctl get 2>/dev/null)" = "power-saver" ]; then
    sed -i '/eDP-1/s/@[0-9.]*,/@60,/' ~/.config/hypr/monitors.conf
  else
    sed -i '/eDP-1/s/@[0-9.]*,/@120.03,/' ~/.config/hypr/monitors.conf
  fi
  unset AQ_DRM_DEVICES WLR_DRM_DEVICES
  exec start-hyprland
fi

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/pratik/.lmstudio/bin"
# End of LM Studio CLI section

