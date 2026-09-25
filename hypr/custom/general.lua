-- Ported from custom/general.conf — 2026-09-20 (pre-Lua migration)
-- Returns nothing; overrides upstream general.lua's decoration/animations (later require wins).

-- macOS Tahoe-style curves
hl.curve("tahoeEaseOut", { type = "bezier", points = {{0.16, 1}, {0.3, 1}} })
hl.curve("tahoeSpring",  { type = "bezier", points = {{0.22, 1.1}, {0.36, 1}} })
hl.curve("tahoePopIn",   { type = "bezier", points = {{0.1, 0.9}, {0.2, 1.05}} })
hl.curve("tahoeDecel",   { type = "bezier", points = {{0.05, 0.85}, {0.1, 1}} })
hl.curve("tahoeAccel",   { type = "bezier", points = {{0.4, 0}, {1, 1}} })

-- windows
hl.animation({ leaf = "windowsIn",  enabled = true, speed = 4,   bezier = "tahoePopIn",   style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4,   bezier = "tahoeEaseOut", style = "popin 90%" })
hl.animation({ leaf = "windowsMove",enabled = true, speed = 4,   bezier = "tahoeSpring",  style = "slide" })
hl.animation({ leaf = "fadeIn",     enabled = true, speed = 3.5, bezier = "tahoeDecel" })
hl.animation({ leaf = "fadeOut",    enabled = true, speed = 3,   bezier = "tahoeDecel" })

-- layers
hl.animation({ leaf = "layersIn",     enabled = true, speed = 3,   bezier = "tahoePopIn", style = "popin 90%" })
hl.animation({ leaf = "layersOut",    enabled = true, speed = 2.5, bezier = "tahoeAccel", style = "popin 92%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2,   bezier = "tahoeDecel" })
hl.animation({ leaf = "fadeLayersOut",enabled = true, speed = 3,   bezier = "tahoeDecel" })

-- workspaces — smooth horizontal slide
hl.animation({ leaf = "workspaces",        enabled = true, speed = 5, bezier = "tahoeSpring", style = "slide" })
hl.animation({ leaf = "specialWorkspaceIn",enabled = true, speed = 4, bezier = "tahoeSpring", style = "slidevert" })
hl.animation({ leaf = "specialWorkspaceOut",enabled = true, speed = 3, bezier = "tahoeAccel",  style = "slidevert" })

-- border + zoom
hl.animation({ leaf = "border",      enabled = true, speed = 8, bezier = "tahoeDecel" })
hl.animation({ leaf = "zoomFactor",  enabled = true, speed = 4, bezier = "tahoeDecel" })

-- Tahoe-style decoration (overrides upstream decoration defaults)
hl.config({
    decoration = {
        rounding = 14,
        rounding_power = 2.8,
        blur = {
            enabled = true,
            size = 10,
            passes = 4,
            noise = 0.04,
            contrast = 0.85,
            brightness = 0.9,
            vibrancy = 0.3,
            vibrancy_darkness = 0.3,
            new_optimizations = true,
        },
        shadow = {
            enabled = true,
            range = 35,
            offset = {0, 3},
            render_power = 4,
            color = "rgba(00000035)",
        },
        dim_inactive = false,
        dim_strength = 0.08,
    },
})
