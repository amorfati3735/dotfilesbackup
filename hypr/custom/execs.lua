-- Ported from custom/execs.conf — 2026-09-20 (pre-Lua migration)
hl.on("hyprland.start", function ()
    -- Night dimmer daemon (software brightness control)
    hl.exec_cmd("wl-gammarelay-rs")

    -- Deferred apps — load behind lock screen, staggered to reduce resource contention
    hl.exec_cmd("sleep 3 && vicinae")
    -- hl.exec_cmd("sleep 4 && ~/.config/hypr/custom/scripts/chatgpt-scratchpad.sh")
    -- custom/rules.lua already applies no_initial_focus to Obsidian
    hl.exec_cmd("sleep 10 && obsidian")

    -- Set power-saver mode on startup
    hl.exec_cmd("powerprofilesctl set power-saver")

    -- Exam Lock — persistent distraction blocker (disabled — exams done)
    -- hl.exec_cmd("sleep 8 && ~/.config/hypr/custom/scripts/exam-lock.sh enable")
end)
