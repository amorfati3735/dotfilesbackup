function fish_prompt -d "Write out the prompt"
    # This shows up as USER@HOST /home/user/ >, with the directory colored
    # $USER and $hostname are set by fish, so you can just use them
    # instead of using `whoami` and `hostname`
    printf '%s@%s %s%s%s > ' $USER $hostname \
        (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

if status is-interactive # Commands to run in interactive sessions can go here

    # No greeting
    set fish_greeting

    # Use starship
    starship init fish | source
    if test -f ~/.local/state/quickshell/user/generated/terminal/sequences.txt
        cat ~/.local/state/quickshell/user/generated/terminal/sequences.txt
    end

    # Aliases
    alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear properly
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    alias ls 'eza --icons'
    alias pamcan pacman
    alias q 'qs -c ii'

    function lap
        set state_file /tmp/.lap_mode
        set gpu_dev /sys/bus/pci/devices/0000:01:00.0
        if test -f $state_file
            # === OFF: back to normal ===
            rm $state_file
            echo 0 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null
            # Wake GPU — set power control back to "on"
            echo on | sudo tee $gpu_dev/power/control >/dev/null
            powerprofilesctl set balanced 2>/dev/null
            bongocat --config ~/.config/bongocat.conf &
            disown
            set gpu_state (cat $gpu_dev/power/runtime_status 2>/dev/null)
            echo "☀  Lap mode OFF — turbo on, GPU $gpu_state, bongocat back"
        else
            # === ON: chill mode ===
            touch $state_file
            echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null
            pkill -x bongocat 2>/dev/null
            pkill -x cava 2>/dev/null
            # Suspend GPU — enable runtime PM auto-suspend
            echo auto | sudo tee $gpu_dev/power/control >/dev/null
            powerprofilesctl set power-saver 2>/dev/null
            # Wait a moment for GPU to enter suspend
            sleep 1
            set gpu_state (cat $gpu_dev/power/runtime_status 2>/dev/null)
            echo "❄  Lap mode ON — turbo off, GPU $gpu_state, bongocat killed"
        end
    end

    function lid
        set current (grep -Po '(?<=^HandleLidSwitchExternalPower=)\S+' /etc/systemd/logind.conf 2>/dev/null)
        if test "$current" = "ignore"
            sudo sed -i 's/^HandleLidSwitchExternalPower=ignore/HandleLidSwitchExternalPower=suspend/' /etc/systemd/logind.conf
            sudo systemctl kill -s HUP systemd-logind
            echo "✓ Lid on AC → SUSPEND"
        else
            sudo sed -i '/^HandleLidSwitchExternalPower=/d' /etc/systemd/logind.conf
            echo "HandleLidSwitchExternalPower=ignore" | sudo tee -a /etc/systemd/logind.conf >/dev/null
            sudo systemctl kill -s HUP systemd-logind
            echo "✓ Lid on AC → STAY ON"
        end
    end
    
end

# Added by LM Studio CLI (lms)
set -gx PATH $PATH /home/pratik/.lmstudio/bin
# End of LM Studio CLI section


# Android SDK (stored on Windows mount for space)
set -gx ANDROID_HOME /mnt/windows/data/Android/Sdk
set -gx ANDROID_SDK_ROOT /mnt/windows/data/Android/Sdk
fish_add_path $ANDROID_HOME/platform-tools $ANDROID_HOME/tools/bin
fish_add_path ~/.local/bin
