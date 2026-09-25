-- Ported from custom/env.conf — 2026-09-20 (pre-Lua migration)
-- ######## GPU - use Intel iGPU, let NVIDIA suspend #########
hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")
hl.env("WLR_DRM_DEVICES", "/dev/dri/card1")

-- ######## Wayland #########
hl.env("MOZ_ENABLE_WAYLAND", "0")

-- ######## Android Studio / JetBrains (Swing on XWayland) #########
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
