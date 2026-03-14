#!/bin/bash
# Shared Material You 3 rofi theme for focus mode
# Sources live colors from matugen-generated SCSS

COLORS_FILE="$HOME/.local/state/quickshell/user/generated/material_colors.scss"

get_color() {
    grep "^\$$1:" "$COLORS_FILE" 2>/dev/null | sed 's/.*: *//;s/;.*//'
}

generate_focus_rofi_theme() {
    local bg=$(get_color "surfaceContainerLow")
    local bg_input=$(get_color "surfaceContainerHigh")
    local bg_hover=$(get_color "surfaceContainerHighest")
    local fg=$(get_color "onSurface")
    local fg_dim=$(get_color "onSurfaceVariant")
    local accent=$(get_color "primary")
    local border=$(get_color "outlineVariant")
    local on_accent=$(get_color "onPrimary")
    local surface_tint=$(get_color "surfaceTint")

    # Fallbacks
    [[ -z "$bg" ]] && bg="#1D1B19"
    [[ -z "$bg_input" ]] && bg_input="#2C2A27"
    [[ -z "$bg_hover" ]] && bg_hover="#373431"
    [[ -z "$fg" ]] && fg="#E7E1DD"
    [[ -z "$fg_dim" ]] && fg_dim="#CAC6C1"
    [[ -z "$accent" ]] && accent="#D3C5AA"
    [[ -z "$border" ]] && border="#494643"
    [[ -z "$on_accent" ]] && on_accent="#37301D"
    [[ -z "$surface_tint" ]] && surface_tint="#D3C5AA"

    cat <<THEME
configuration {
    font: "Google Sans Flex 13";
    show-icons: false;
    display-dmenu: "";
    disable-history: true;
}

* {
    bg:               ${bg};
    bg-input:         ${bg_input};
    bg-hover:         ${bg_hover};
    fg:               ${fg};
    fg-dim:           ${fg_dim};
    accent:           ${accent};
    border-clr:       ${border};
    on-accent:        ${on_accent};
    tint:             ${surface_tint};
    transparent:      transparent;
}

window {
    transparency:     "real";
    location:         center;
    anchor:           center;
    width:            440px;
    border:           2px solid;
    border-color:     @border-clr;
    border-radius:    20px;
    background-color: @bg;
    cursor:           "default";
}

mainbox {
    background-color: @transparent;
    spacing:          0;
    children:         [ inputbar, message, listview ];
}

inputbar {
    padding:          16px 20px;
    spacing:          14px;
    background-color: @bg-input;
    border-radius:    20px 20px 0 0;
    border:           0 0 1px 0;
    border-color:     @border-clr;
    children:         [ prompt, entry ];
}

prompt {
    font:             "Space Grotesk Medium 12";
    background-color: @transparent;
    text-color:       @accent;
    vertical-align:   0.5;
}

entry {
    font:             "Google Sans Flex 14";
    placeholder-color: @fg-dim;
    background-color: @transparent;
    text-color:       @fg;
    cursor:           text;
    vertical-align:   0.5;
}

listview {
    columns:          1;
    lines:            5;
    padding:          6px 0;
    spacing:          2px;
    background-color: @transparent;
    scrollbar:        false;
    fixed-height:     false;
}

element {
    padding:          12px 20px;
    background-color: @transparent;
    text-color:       @fg;
    cursor:           pointer;
    border-radius:    0;
}

element selected.normal {
    background-color: @accent;
    text-color:       @on-accent;
}

element alternate.normal {
    background-color: @transparent;
    text-color:       @fg;
}

element normal.active,
element alternate.active {
    text-color:       @accent;
}

element-text {
    font:             "Google Sans Flex 13";
    background-color: inherit;
    text-color:       inherit;
    vertical-align:   0.5;
    cursor:           inherit;
}

message {
    padding:          12px 20px;
    background-color: @transparent;
    border:           0 0 1px 0;
    border-color:     @border-clr;
}

textbox {
    font:             "Google Sans Flex 12";
    text-color:       @fg-dim;
    background-color: @transparent;
}
THEME
}

# Helper: run rofi with focus theme
focus_rofi() {
    local prompt_text="$1"
    local placeholder="$2"
    local input_mode="$3"  # "input" or "list"
    shift 3

    local theme_file
    theme_file=$(mktemp /tmp/focus-rofi-XXXX.rasi)
    generate_focus_rofi_theme > "$theme_file"

    local result
    if [[ "$input_mode" == "input" ]]; then
        result=$(echo "" | rofi -dmenu -p "$prompt_text" \
            -theme "$theme_file" \
            -theme-str 'listview { enabled: false; }' \
            -theme-str "entry { placeholder: \"$placeholder\"; }" \
            "$@" 2>/dev/null)
    else
        result=$(rofi -dmenu -p "$prompt_text" \
            -theme "$theme_file" \
            "$@" 2>/dev/null)
    fi
    local ret=$?
    rm -f "$theme_file"
    echo "$result"
    return $ret
}
