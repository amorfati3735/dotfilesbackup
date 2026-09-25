#!/usr/bin/env bash
# hypr-dispatch.sh — Hyprland dispatch helpers that work under BOTH config managers:
# the legacy hyprlang manager and the new Lua manager.
#
# Source it, then call the hd_* wrappers:
#     . "$HOME/.local/bin/hypr-dispatch.sh"
#     hd_focus_window "class:kitty"
#     hd_focus_workspace empty
#
# Why this exists (verified against the Hyprland 0.56.2 sources,
# src/debug/HyprCtl.cpp + src/config/lua/bindings/LuaBindingsDispatchers.cpp):
#   * hyprlang mode  : `hyprctl dispatch <legacy-name> <args>` is the only form that
#                      works; `hl.dsp.*` strings are rejected as unknown dispatchers.
#   * Lua mode       : `hyprctl dispatch <x>` is evaluated as `hl.dispatch(<x>)`, so
#                      legacy names (focuswindow, submap, resizeactive, ...) fail.
#                      `hyprctl keyword ...` answers "keyword can't work with
#                      non-legacy parsers. Use eval."
#   * `hyprctl eval` only exists when the Lua manager is loaded, so a successful
#     `hyprctl eval 'true'` (prints "ok") is a reliable, side-effect-free probe.
#
# Adding a new call: find the matching `hl.dsp.*` dispatcher and wire both branches
# in one wrapper, so the workflow keeps working across the migration (and after a
# rollback).

# ── probe ──────────────────────────────────────────────────────────────────────
# hd_lua_mode → true when the running compositor uses the Lua config manager
hd_lua_mode() {
    [ "$(hyprctl eval 'true' 2>/dev/null | head -n1)" = "ok" ]
}

# ── generic ────────────────────────────────────────────────────────────────────
# run a hyprctl call and surface anything that is not a plain "ok" on stderr
# (hyprctl returns rc=0 even for dispatch errors, so exit codes cannot be trusted)
hd_run() {
    local out
    out=$("$@" 2>&1)
    case "$out" in
        ok | ok$'\n' | "") : ;;
        *) printf 'hypr-dispatch: %s\n' "$out" >&2 ;;
    esac
}

# hd_dispatch <lua-expression> <legacy-dispatcher> [legacy-args...]
hd_dispatch() {
    if hd_lua_mode; then
        hd_run hyprctl dispatch "$1"
    else
        shift
        hd_run hyprctl dispatch "$@"
    fi
}

# ── windows / workspaces ───────────────────────────────────────────────────────
# hd_focus_window <window-selector>     e.g. "class:kitty" | "address:0x123abc"
hd_focus_window() {
    hd_dispatch "hl.dsp.focus({ window = \"$1\" })" focuswindow "$1"
}

# hd_focus_workspace <workspace-selector>   e.g. 3 | "previous" | "empty" | "name:foo"
hd_focus_workspace() {
    hd_dispatch "hl.dsp.focus({ workspace = \"$1\" })" workspace "$1"
}

# hd_close_window <window-selector>
hd_close_window() {
    hd_dispatch "hl.dsp.window.close({ window = \"$1\" })" closewindow "$1"
}

# hd_layoutmsg <layout message>          e.g. "swapwithmaster" | "orientationleft"
hd_layoutmsg() {
    hd_dispatch "hl.dsp.layout(\"$1\")" layoutmsg "$1"
}

# hd_resize_active <dx> <dy>             relative resize of the active window, px
hd_resize_active() {
    hd_dispatch "hl.dsp.window.resize({ x = $1, y = $2, relative = true })" \
        resizeactive -- "$1" "$2"
}

# hd_send_shortcut <mods> <key> <window-selector>
hd_send_shortcut() {
    hd_dispatch "hl.dsp.send_shortcut({ mods = \"$1\", key = \"$2\", window = \"$3\" })" \
        sendshortcut "$1, $2, $3"
}

# ── state / shell integration ─────────────────────────────────────────────────
# hd_submap <name>                       e.g. "pwapick" | "global" | "reset"
# hyprlang calls the default submap "global"; Lua has no such submap — the default is ""
# and Actions::setSubmap() *errors* on any name without registered binds, so entering
# "global" under Lua silently keeps the previous submap (a stuck picker). Map it.
hd_submap() {
    local name="$1"
    if hd_lua_mode; then
        if [ -z "$name" ] || [ "$name" = "global" ]; then
            name="reset"
        fi
        hd_dispatch "hl.dsp.submap(\"$name\")" submap "$1"
    else
        hd_run hyprctl dispatch submap "$name"
    fi
}

# hd_global <shell global>               e.g. "quickshell:lock"
hd_global() {
    hd_dispatch "hl.dsp.global(\"$1\")" global "$1"
}

# hd_monitor_set <output> <mode> [position] [scale]
#   e.g. hd_monitor_set HEADLESS-1 1600x1000@60 auto 1.0
hd_monitor_set() {
    local out="$1" mon_mode="$2" pos="${3:-auto}" scale="${4:-1}"
    if hd_lua_mode; then
        hd_run hyprctl eval "hl.monitor({ output = \"$out\", mode = \"$mon_mode\", position = \"$pos\", scale = $scale })"
    else
        hd_run hyprctl keyword monitor "$out,$mon_mode,$pos,$scale"
    fi
}

# hd_exec_cmd <command>                  `exec` without a rule prefix
# (window-rule prefixes like "[noinitialfocus]" are not needed post-migration —
#  put the rule in custom/rules.conf / custom/rules.lua instead)
hd_exec_cmd() {
    hd_dispatch "hl.dsp.exec_cmd(\"$1\")" exec "$1"
}

# ── dynamic binds (page-timer style) ──────────────────────────────────────────
# hd_bind <legacy-mods,key pair> <exec command>
#   e.g. hd_bind ",grave" "kill -USR1 1234"
#        hd_bind "SHIFT,grave" "kill -USR2 1234"
hd_bind() {
    local pair="$1" cmd="$2" mods key luakeys
    mods="${pair%%,*}"
    key="${pair#*,}"
    luakeys="$key"
    if [ -n "$mods" ]; then
        luakeys="$(printf '%s' "$mods" | tr -s ' ' '+') + $key"
    fi
    if hd_lua_mode; then
        hd_run hyprctl eval "hl.bind(\"$luakeys\", hl.dsp.exec_cmd(\"$cmd\"))"
    else
        hd_run hyprctl keyword bind "$pair,exec,$cmd"
    fi
}

# hd_unbind <legacy-mods,key pair>       e.g. hd_unbind ",grave"
hd_unbind() {
    local pair="$1" mods key luakeys
    mods="${pair%%,*}"
    key="${pair#*,}"
    luakeys="$key"
    if [ -n "$mods" ]; then
        luakeys="$(printf '%s' "$mods" | tr -s ' ' '+') + $key"
    fi
    if hd_lua_mode; then
        hd_run hyprctl eval "hl.unbind(\"$luakeys\")"
    else
        hd_run hyprctl keyword unbind "$pair"
    fi
}
