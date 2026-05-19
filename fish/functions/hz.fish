function hz --description "Switch eDP-1 refresh rate. Usage: hz [60|120|toggle]"
    set -l monitor eDP-1
    set -l target $argv[1]

    set -l current (wlr-randr --output $monitor 2>/dev/null | string match -r 'current.*' | string match -r '[0-9]+\.' | head -n1 | string trim -c .)
    if test -z "$current"
        set current (hyprctl -j monitors | jq -r ".[] | select(.name==\"$monitor\") | .refreshRate | floor")
    end

    if test -z "$target"; or test "$target" = toggle
        if test "$current" -ge 100
            set target 60
        else
            set target 120
        end
    end

    # Find the exact mode string wlr-randr expects (it requires the precise float)
    set -l mode (wlr-randr 2>/dev/null | awk -v m=$monitor -v t=$target '
        $0 ~ "^"m {found=1; next}
        found && /^[A-Za-z]/ {found=0}
        found && /1920x1080 px/ {
            for (i=1;i<=NF;i++) if ($i ~ /Hz/) {
                rate=$(i-1)
                if (int(rate) == int(t)) { print rate; exit }
            }
        }')

    switch $target
        case 60 120
            if test -n "$mode"
                wlr-randr --output $monitor --mode 1920x1080@{$mode}Hz >/dev/null 2>&1
            else
                hyprctl keyword monitor "$monitor,1920x1080@$target,0x0,1" >/dev/null
            end
            # Wait for SIGWINCH burst to settle, then wipe the prompt redraw noise.
            # Reprints the "→ N Hz" line so the user still sees feedback.
            fish -c "sleep 0.7; printf '\e[H\e[2J\e[3J$monitor → $target Hz\n'" >/dev/tty &
            disown
        case '*'
            echo "usage: hz [60|120|toggle]" >&2
            return 1
    end
end
