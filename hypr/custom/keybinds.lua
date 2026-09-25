-- Ported from custom/keybinds.conf — 2026-09-20 (pre-Lua migration)
-- This file loads after hyprland.keybinds. Duplicate binds do NOT override, so remove every upstream
-- combo that is intentionally replaced or disabled before adding custom behavior.

for _, key in ipairs({
    "SUPER + W",
    "SUPER + L",
    "SUPER + D",
    "SUPER + C",
    "SUPER + SHIFT + C",
    "CTRL + SUPER + R",
    "ALT + F4",
    "SUPER + P",
    "SUPER + SHIFT + P",
    "SUPER + T",
    "SUPER + Return",
    "SUPER + X",
}) do
    hl.unbind(key)
end

-- ##! User
hl.bind("CTRL + SUPER + Slash",
    hl.dsp.exec_cmd("xdg-open ~/.config/illogical-impulse/config.json"),
    { description = "User: Edit shell config" })
hl.bind("CTRL + SUPER + ALT + Slash",
    hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"),
    { description = "User: Edit extra keybinds" })

-- SUPER+W intentionally remains unbound. User replacements follow.
hl.bind("SUPER + L", hl.dsp.global("quickshell:idleInhibitToggle"), { description = "User: Toggle keep-awake" })
hl.bind("SUPER + D", hl.dsp.exec_cmd("~/.local/bin/show-desktop-toggle.sh"), { description = "User: Toggle show desktop" })
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty -1"), { description = "User: Kitty terminal" })
hl.bind("ALT + F4", hl.dsp.global("quickshell:sessionToggle"), { description = "Shell: Toggle power/session menu" })
hl.bind("CTRL + SUPER + R",
    hl.dsp.exec_cmd("killall ags agsv1 gjs ydotool qs quickshell; qs -c $qsConfig &"),
    { description = "User: Restart widgets" })

-- ##! Web (LAlt)
hl.bind("ALT + C", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/launch-calc.sh"), { description = "Web (LAlt): Calculator (tiled left)" })
hl.bind("ALT + Q", hl.dsp.exec_cmd("xdg-open \"https://drive.google.com/drive/folders/1SBXoFGg_N8mLaUFk19SGC0jBHj1vj_SO\""), { description = "Web (LAlt): Google Drive" })
hl.bind("ALT + V", hl.dsp.exec_cmd("xdg-open \"https://vtop.vit.ac.in/vtop/login\""), { description = "Web (LAlt): VTOP" })
hl.bind("ALT + E", hl.dsp.exec_cmd("xdg-open \"https://chat.deepseek.com\""), { description = "Web (LAlt): DeepSeek" })
hl.bind("ALT + W", hl.dsp.exec_cmd("xdg-open \"https://web.whatsapp.com/\""), { description = "Web (LAlt): WhatsApp Web" })
hl.bind("ALT + G", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/gmail-chooser.py"), { description = "Web (LAlt): Gmail account chooser" })
hl.bind("ALT + 3", hl.dsp.exec_cmd("xdg-open \"https://aistudio.google.com\""), { description = "Web (LAlt): Google AI Studio" })
hl.bind("ALT + 4", hl.dsp.exec_cmd("xdg-open \"https://monkeytype.com/\""), { description = "Web (LAlt): Monkeytype" })
hl.bind("SUPER + C", hl.dsp.exec_cmd("xdg-open \"https://chatgpt.com/\""), { description = "Web (LAlt): ChatGPT" })
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("~/bin/pwa launch chatgpt"), { description = "Web (LAlt): ChatGPT PWA" })
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd("~/bin/pwa pick"), { description = "PWA: quick picker (type letter)" })

-- ##! Web (RAlt = MOD5)
hl.bind("MOD5 + R", hl.dsp.exec_cmd("xdg-open \"https://www.youtube.com/playlist?list=PLdo5W4Nhv31bbKJzrsKfMpo_grxuLl8LU\""), { description = "Web (RAlt): YouTube playlist" })
hl.bind("MOD5 + K", hl.dsp.exec_cmd("xdg-open \"https://keep.google.com/u/1/\""), { description = "Web (RAlt): Google Keep" })
hl.bind("MOD5 + E", hl.dsp.exec_cmd("bash -c 'echo -n \"pratik.ambastha2025@vitstudent.ac.in\" | wl-copy; echo -n \"pratik.ambastha2025@vitstudent.ac.in\" | wl-copy -p; xdg-open \"https://vitvellore312.examly.io/\""), { description = "Web (RAlt): Examly + VIT Email" })
hl.bind("MOD5 + Comma", hl.dsp.exec_cmd("bash -c 'xdotool key F5'"), { description = "Web (RAlt): Reload website" })
hl.bind("MOD5 + V", hl.dsp.exec_cmd("bash -c 'echo -n \"pratik.ambastha2025@vitstudent.ac.in\" | wl-copy; echo -n \"pratik.ambastha2025@vitstudent.ac.in\" | wl-copy -p; xdg-open \"https://vitvellore312.examly.io/login\""), { description = "Web (RAlt): Examly login" })
hl.bind("MOD5 + Y", hl.dsp.exec_cmd("xdg-open \"https://calendar.google.com/calendar/u/2/r/tasks\""), { description = "Web (RAlt): Google Tasks" })
hl.bind("MOD5 + P", hl.dsp.exec_cmd("xdg-open \"https://www.papers.codechefvit.com/\""), { description = "Web (RAlt): Papers" })
hl.bind("MOD5 + 0", hl.dsp.exec_cmd("xdg-open \"https://fast.com\""), { description = "Web (RAlt): Speed Test" })
hl.bind("MOD5 + N", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/toggle-buds.sh"), { description = "Web (RAlt): Toggle Nord Buds 3" })
hl.bind("MOD5 + Space", hl.dsp.exec_cmd("kitty -e micro \"/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala/「日常」/$(date +%d-%b-%y).md\""), { description = "Web (RAlt): Daily note" })

-- ##! Region screenshot → vault note
hl.bind("CTRL + Slash", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/region-shot.sh"), { description = "Region: Region-shot capture" })
hl.bind("CTRL + SHIFT + Slash", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/region-shot.sh --reselect"), { description = "Region: Region-shot re-select" })

-- ##! Longshot (scrolling screenshot) — toggle start/stop
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("~/bin/longshot toggle"), { description = "Capture: Longshot toggle" })

-- ##! Navigation
hl.bind("ALT + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "Navigation: Previous workspace" })

-- ##! Quick Send
hl.bind("ALT + T", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/telegram-send.sh"), { description = "Quick Send: Telegram quick send" })

-- ##! Apps
hl.bind("ALT + F", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/focus-mode.sh"), { description = "Apps: Focus Mode toggle" })
hl.bind("SUPER + SHIFT + D", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/daylog.sh"), { description = "Apps: Daylog ritual" })
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/mistral-region-ocr.sh"), { description = "Utilities: Mistral region OCR >> clipboard" })
hl.bind("SUPER + Z", hl.dsp.exec_cmd("zen-browser"), { description = "Apps: Zen Browser" })
hl.bind("ALT + 5", hl.dsp.exec_cmd("code"), { description = "Apps: VS Code" })
hl.bind("ALT + D", hl.dsp.exec_cmd("gtk-launch obsidian"), { description = "Apps: Obsidian" })
hl.bind("ALT + Z", hl.dsp.global("quickshell:quickCapture"), { description = "Apps: Quick Capture" })
hl.bind("ALT + Space", hl.dsp.exec_cmd("fsearch"), { description = "Apps: FSearch" })

-- ##! Launchers
hl.bind("SUPER + R", hl.dsp.exec_cmd("pkill rofi || rofi -show drun"), { description = "Launchers: App Browser" })
hl.bind("SUPER + X", hl.dsp.exec_cmd("dolphin --new-window ~/scripts/quick-access"), { description = "Launchers: Script Launcher" })
hl.bind("SUPER + P", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/cycle-power-profile.sh"), { description = "Launchers: Cycle power profile" })

-- ##! Folders
hl.bind("MOD5 + O", hl.dsp.exec_cmd("dolphin --new-window ~/Documents"), { description = "Folders: Documents" })
hl.bind("ALT + X", hl.dsp.exec_cmd("dolphin --new-window ~/Downloads"), { description = "Folders: Downloads" })
hl.bind("ALT + Grave", hl.dsp.exec_cmd("dolphin --new-window \"/mnt/windows/Users/DELL/Dropbox/DropsyncFiles/lesser amygdala\""), { description = "Folders: Obsidian vault" })
hl.bind("ALT + A", hl.dsp.exec_cmd("xdg-open \"/mnt/windows/Users/DELL/Downloads/Binder1.pdf\""), { description = "Folders: Schedule PDF" })
hl.bind("ALT + S", hl.dsp.exec_cmd("dolphin --new-window \"/mnt/windows/Users/DELL/Pictures/Screenshots\""), { description = "Folders: Screenshots" })
hl.bind("MOD5 + I", hl.dsp.exec_cmd("dolphin --new-window ~/Captures"), { description = "Folders: Captures" })
hl.bind("MOD5 + M", hl.dsp.exec_cmd("~/.local/bin/wifi-login.sh"), { description = "Folders: N-VIT WiFi login" })
hl.bind("SUPER + Space", hl.dsp.global("quickshell:stickyNotes"), { description = "Folders: Sticky Notes" })
hl.bind("MOD5 + L", hl.dsp.exec_cmd("~/.config/hypr/custom/scripts/launch-clocks.sh"), { description = "Folders: Left tiled clocks" })

-- ##! Dolphin contextual
hl.bind("CTRL + SHIFT + X", hl.dsp.exec_cmd("~/scripts/dolphin-new-md.sh"), { description = "Dolphin: New markdown file" })

-- ##! Materialgram
hl.bind("SUPER + T", hl.dsp.exec_cmd("materialgram"), { description = "Apps: Materialgram" })

-- ##! Tablet extended screen
hl.bind("SUPER + SHIFT + W", hl.dsp.exec_cmd("~/bin/tabscreen toggle"), { description = "Tablet screen over USB" })

-- ##! Media (LAlt + numbers)
hl.bind("ALT + 1", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("ALT + 2", hl.dsp.exec_cmd("playerctl next"))

-- PWA quick picker submap (generated by ~/bin/pwa regen) — loaded if present
if is_file_exists(HOME .. "/.config/hypr/custom/pwa-submap.lua") then
    require("custom.pwa-submap")
end
