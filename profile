if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  export WLR_NO_HARDWARE_CURSORS=1
  exec Hyprland
fi

