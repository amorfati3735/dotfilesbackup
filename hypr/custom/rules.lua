-- Ported from custom/rules.conf — 2026-09-20 (pre-Lua migration)
-- Effect values keep their hyprlang string/boolean shape (verified against wiki):

-- ######## Gmail account chooser ########
hl.window_rule({ match = { class = "^(com.pratik.gmailchooser)$" }, float = true })
hl.window_rule({ match = { class = "^(com.pratik.gmailchooser)$" }, center = true })
hl.window_rule({ match = { class = "^(com.pratik.gmailchooser)$" }, no_blur = true })

-- ######## Longshot recording overlay (class + title) ########
for _, field in ipairs({ "class", "title" }) do
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, float = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, border_size = 0 })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, rounding = 0 })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, no_blur = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, no_shadow = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, no_initial_focus = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, no_focus = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" }, pin = true })
    hl.window_rule({ match = { [field] = "^(longshot_overlay)$" },
        suppress_event = "activatefocus maximize fullscreen" })
end

-- ######## Kitty frosted acrylic ########
hl.window_rule({ match = { class = "^(kitty)$" }, no_blur = false })
hl.window_rule({ match = { class = "kitty" }, opacity = "0.95 override 0.90 override" })

-- ######## Zen Browser ########
hl.window_rule({ match = { class = "^(zen)$", title = "negative:YouTube" }, no_blur = false })
hl.window_rule({ match = { class = "^(zen)$", title = "YouTube" }, no_blur = true })

-- ######## Chrome PWAs (chrome-<host>__-Default / pwa-<name>) ########
hl.window_rule({ match = { class = "^(chrome-.+__-.+|pwa-.+)$" }, opacity = "0.65 override 0.80 override" })
hl.window_rule({ match = { class = "^(chrome-.+__-.+|pwa-.+)$" }, no_blur = false })

-- ######## ChatGPT scratchpad / Obsidian scratchpad — special silent ########
hl.window_rule({ match = { class = "^(chatgpt-zen)$" }, workspace = "special silent" })
hl.window_rule({ match = { class = "^(chatgpt-zen)$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^(chatgpt-zen)$" }, suppress_event = "activate" })
hl.window_rule({ match = { class = "^(chatgpt-zen)$" }, opacity = "0.85 override 0.80 override" })
hl.window_rule({ match = { class = "^(chatgpt-zen)$" }, no_blur = false })

hl.window_rule({ match = { class = "^(obsidian)$" }, workspace = "special silent" })
hl.window_rule({ match = { class = "^(obsidian)$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^(obsidian)$" }, suppress_event = "activate" })
hl.window_rule({ match = { class = "^(obsidian)$" }, opacity = "0.85 override 0.80 override" })
hl.window_rule({ match = { class = "^(obsidian)$" }, no_blur = false })

-- ######## Spotify — deep frosted glass ########
hl.window_rule({ match = { class = "^(Spotify)$" }, opacity = "0.65 override 0.60 override" })
hl.window_rule({ match = { class = "^(Spotify)$" }, no_blur = false })

-- ######## Antigravity (Gemini) / Foliate — frosted glass ########
hl.window_rule({ match = { class = "^(antigravity)$" }, opacity = "0.85 override 0.80 override" })
hl.window_rule({ match = { class = "^(antigravity)$" }, no_blur = false })
hl.window_rule({ match = { class = "^(com.github.johnfactotum.Foliate)$" }, opacity = "0.85 override 0.80 override" })
hl.window_rule({ match = { class = "^(com.github.johnfactotum.Foliate)$" }, no_blur = false })

-- ######## Rofi — frosted glass blur ########
hl.layer_rule({ match = { namespace = "rofi" }, blur = true })
hl.layer_rule({ match = { namespace = "rofi" }, ignore_alpha = 0.3 })

-- ######## VS Code — frosted glass ########
hl.window_rule({ match = { class = "^(code)$" }, opacity = "0.90 override 0.85 override" })
hl.window_rule({ match = { class = "^(code)$" }, no_blur = false })

-- ######## Android Studio / JetBrains ########
hl.window_rule({ match = { class = "^(jetbrains-studio)$", title = "^(win|Splash|Welcome to Android Studio).*$" }, float = true })
hl.window_rule({ match = { class = "^(jetbrains-studio)$", title = "^(Select SDKs|Settings|Preferences|Project Structure|New Project|Open Project|Run/Debug Configurations|SDK Manager|AVD Manager|Tip of the Day|Find|Replace|Search Everywhere)$" }, float = true })
hl.window_rule({ match = { class = "^(jetbrains-studio)$", title = "^(win|Splash).*$" }, no_initial_focus = true })
hl.window_rule({ match = { class = "^(jetbrains-studio)$", title = "^(win|Splash).*$" }, center = true })
hl.window_rule({ match = { class = "^(jetbrains-studio)$" }, suppress_event = "activate" })
hl.window_rule({ match = { class = "^(jetbrains-studio)$" }, suppress_event = "fullscreen" })
