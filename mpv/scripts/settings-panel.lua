local opts = {
  key_toggle = "F2",
  key_up = "UP",
  key_down = "DOWN",
  key_left = "LEFT",
  key_right = "RIGHT",
  key_prev_cat = "PGUP",
  key_next_cat = "PGDWN",
  key_close = "ESC",
}

local categories = {
  {
    name = "Video",
    icon = "V",
    items = {
      {label = "Hardware Decoding",     cmd = "cycle-values hwdec \"no\" \"auto\" \"auto-copy\"",         fmt = function() return mp.get_property("hwdec") end},
      {label = "Interpolation",         cmd = "cycle interpolation",                                     fmt = function() return bool(mp.get_property("interpolation")) end},
      {label = "Video Sync",            cmd = "cycle-values video-sync \"audio\" \"display-resample\" \"display-adrop\"", fmt = function() return mp.get_property("video-sync") end},
      {label = "Deinterlace",           cmd = "cycle deinterlace",                                       fmt = function() return bool(mp.get_property("deinterlace")) end},
      {label = "Brightness",            cmd = "add brightness %d",             prop = "brightness",  min = -100, max = 100, step = 1},
      {label = "Contrast",              cmd = "add contrast %d",               prop = "contrast",    min = -100, max = 100, step = 1},
      {label = "Saturation",            cmd = "add saturation %d",             prop = "saturation",  min = -100, max = 100, step = 1},
      {label = "Gamma",                 cmd = "add gamma %d",                  prop = "gamma",       min = -100, max = 100, step = 1},
      {label = "Aspect Ratio",          cmd = "cycle-values video-aspect-override \"no\" \"16:9\" \"4:3\" \"2.35:1\"", fmt = function() local v = mp.get_property("video-aspect-override"); if v == "" or v == "no" then return "Default"; end; return v end},
    }
  },
  {
    name = "Audio",
    icon = "A",
    items = {
      {label = "Volume",                cmd = "no-osd add volume %d",                    prop = "volume",      min = 0,   max = 200, step = 5},
      {label = "Mute",                  cmd = "cycle mute",                                                                 fmt = function() return bool(mp.get_property("mute")) end},
      {label = "Audio Delay",           cmd = "add audio-delay %0.1f",                   prop = "audio-delay", min = -10, max = 10,  step = 0.1},
      {label = "Audio Track",           cmd = "cycle audio",                                                               fmt = function() return mp.get_property("aid") or "0" end},
    }
  },
  {
    name = "Subtitles",
    icon = "S",
    items = {
      {label = "Subtitle Delay",        cmd = "add sub-delay %0.1f",                 prop = "sub-delay",     min = -60,  max = 60, step = 0.5},
      {label = "Subtitle Scale",        cmd = "add sub-scale %0.1f",                 prop = "sub-scale",     min = 0.1,  max = 3,  step = 0.1},
      {label = "Subtitle Position",     cmd = "add sub-pos %d",                      prop = "sub-pos",       min = 0,    max = 150, step = 1},
      {label = "Sub Visibility",        cmd = "cycle sub-visibility",                                                   fmt = function() return bool(mp.get_property("sub-visibility")) end},
      {label = "Sub Scale by Window",   cmd = "cycle sub-scale-by-window",                                              fmt = function() return bool(mp.get_property("sub-scale-by-window")) end},
    }
  },
  {
    name = "Playback",
    icon = "P",
    items = {
      {label = "Speed",                 cmd = "multiply speed %0.2f",                prop = "speed",         min = 0.25, max = 4,   step = 0.05},
      {label = "Keep Open",             cmd = "cycle keep-open",                                                        fmt = function() return bool(mp.get_property("keep-open")) end},
      {label = "Loop File",             cmd = "cycle-values loop \"no\" \"inf\"",                                       fmt = function() local v = mp.get_property("loop"); if v == "no" or v == "" then return "Off"; end; return "On" end},
      {label = "Loop Playlist",         cmd = "cycle-values loop-playlist \"no\" \"inf\"",                              fmt = function() local v = mp.get_property("loop-playlist"); if v == "no" or v == "" then return "Off"; end; return "On" end},
    }
  },
  {
    name = "Interface",
    icon = "I",
    items = {
      {label = "Always on Top",         cmd = "cycle ontop",                                                             fmt = function() return bool(mp.get_property("ontop")) end},
      {label = "Window Border",         cmd = "cycle border",                                                            fmt = function() return bool(mp.get_property("border")) end},
      {label = "Fullscreen",            cmd = "cycle fullscreen",                                                        fmt = function() return bool(mp.get_property("fullscreen")) end},
      {label = "OSD Level",             cmd = "cycle-values osd-level \"0\" \"1\" \"2\" \"3\"",                         fmt = function() return mp.get_property("osd-level") or "1" end},
    }
  },
}

local state = {
  open = false,
  cat = 1,
  sel = 1,
  hover_progress = false,
  drag_offset = nil,
}

local overlay = nil
local screen_w, screen_h = 0, 0
local font_size = 0

local function bool(v)
  if v == "yes" then return "On" end
  return "Off"
end

local function clamp(v, min, max)
  return math.max(min, math.min(max, v))
end

local function refresh_props()
  screen_w, screen_h = mp.get_osd_size()
  font_size = math.floor(screen_h / 45)
end

local function get_value(item)
  if item.fmt then
    local ok, v = pcall(item.fmt)
    if ok then return v else return "?" end
  end
  if item.prop then
    local ok, v = pcall(mp.get_property, item.prop)
    if ok then return v end
  end
  return ""
end

local function get_slider_pct(item)
  local v = tonumber(get_value(item))
  if not v or not item.min or not item.max then return nil end
  return (v - item.min) / (item.max - item.min)
end

local function build_ass()
  refresh_props()
  local w, h = screen_w, screen_h
  local panel_w = math.floor(w * 0.48)
  local panel_x = math.floor((w - panel_w) / 2)
  local panel_y = math.floor(h * 0.22)
  local line_h = math.floor(font_size * 1.8)
  local pad_x = math.floor(font_size * 1.2)
  local pad_y = math.floor(font_size * 0.8)
  local tab_h = math.floor(font_size * 2.2)
  local item_h = line_h
  local cats = categories
  local cat_count = #cats
  local items = cats[state.cat].items
  local item_count = #items
  local panel_h = tab_h + pad_y * 2 + item_count * item_h + pad_y

  local cx = panel_x
  local cy = panel_y
  local cw = panel_w
  local ch = panel_h

  state.sel = clamp(state.sel, 1, item_count)

  local ass = "[Script Info]\nScriptType: v4.00+\nPlayResX: " .. w .. "\nPlayResY: " .. h .. "\n"

  -- background
  ass = ass .. string.format("{\\blur0\\bord0\\1c&H202020\\alpha&H20\\pos(%d,%d)}", cx, cy)
  ass = ass .. string.format("{\\p1}m 0 0 l %d 0 l %d %d l 0 %d l 0 0{\\p0}", cw, cw, ch, ch) .. "\n"

  -- border
  ass = ass .. string.format("{\\blur0\\bord1\\1c&HFFFFFF\\alpha&H99\\pos(%d,%d)}", cx, cy)
  ass = ass .. string.format("{\\p1}m 0 0 l %d 0 l %d %d l 0 %d l 0 0{\\p0}", cw, cw, ch, ch) .. "\n"

  -- category tabs
  for i, cat in ipairs(cats) do
    local tx = cx + (i - 1) * (cw / cat_count)
    local tw = cw / cat_count
    local ty = cy

    if i == state.cat then
      ass = ass .. string.format("{\\blur0\\bord0\\1c&H444444\\alpha&H40\\pos(%d,%d)}", tx, ty)
      ass = ass .. string.format("{\\p1}m 0 0 l %d 0 l %d %d l 0 %d l 0 0{\\p0}", tw, tw, tab_h, tab_h) .. "\n"
    end

    ass = ass .. string.format("{\\blur0\\bord0\\fs%d\\fnCantarell\\b1\\1c&HFFFFFF\\3c&H000000\\alpha&H00\\pos(%d,%d)}", math.floor(font_size * 0.9), tx + tw / 2, ty + tab_h / 2)
    ass = ass .. string.format("{\\an5}%s", cat.icon and cat.icon .. "  " .. cat.name or cat.name) .. "\n"

    if i < cat_count then
      ass = ass .. string.format("{\\blur0\\bord0\\1c&HFFFFFF\\alpha&H66\\pos(%d,%d)}", tx + tw, ty)
      ass = ass .. string.format("{\\p1}m 0 %d l 0 %d{\\p0}", 4, tab_h - 4) .. "\n"
    end
  end

  -- items
  for idx, item in ipairs(items) do
    local iy = cy + tab_h + pad_y + (idx - 1) * item_h
    local val = get_value(item)
    local pct = get_slider_pct(item)

    if idx == state.sel then
      ass = ass .. string.format("{\\blur0\\bord0\\1c&H6699FF\\alpha&H55\\pos(%d,%d)}", cx + pad_x, iy)
      ass = ass .. string.format("{\\p1}m 0 0 l %d 0 l %d %d l 0 %d l 0 0{\\p0}", cw - pad_x * 2, cw - pad_x * 2, item_h - 4, item_h - 4) .. "\n"
    end

    ass = ass .. string.format("{\\blur0\\bord0\\fs%d\\fnCantarell\\b0\\1c&HFFFFFF\\3c&H000000\\alpha&H00\\pos(%d,%d)}", font_size, cx + pad_x * 2, iy + (item_h - 4) / 2)

    if pct then
      -- slider
      local sw = math.floor(cw * 0.35)
      local sx = cx + cw - pad_x * 2 - sw
      local sy = iy + (item_h - 4 - math.floor(font_size * 0.35)) / 2
      local sh = math.floor(font_size * 0.35)

      -- slider bg
      ass = ass .. string.format("{\\p1}m %d %d l %d %d l %d %d l %d %d l %d %d{\\p0}", sx, sy, sx + sw, sy, sx + sw, sy + sh, sx, sy + sh, sx, sy) .. "\n"
      -- slider fill
      local fill_w = math.floor(sw * clamp(pct, 0, 1))
      if fill_w > 0 then
        ass = ass .. string.format("{\\1c&H66BBFF\\p1}m %d %d l %d %d l %d %d l %d %d l %d %d{\\p0}", sx, sy, sx + fill_w, sy, sx + fill_w, sy + sh, sx, sy + sh, sx, sy) .. "\n"
      end
      -- slider handle
      local hx = sx + math.floor(sw * clamp(pct, 0, 1))
      ass = ass .. string.format("{\\bord0.5\\1c&HFFFFFF\\p1}m %d %d l %d %d l %d %d l %d %d l %d %d{\\p0}", hx - 3, sy - 2, hx + 3, sy - 2, hx + 3, sy + sh + 2, hx - 3, sy + sh + 2, hx - 3, sy - 2) .. "\n"

      -- label and value
      ass = ass .. string.format("{\\blur0\\bord0\\fs%d\\fnCantarell\\b0\\1c&HFFFFFF\\alpha&H00\\pos(%d,%d)}", font_size, cx + pad_x * 2, iy + (item_h - 4) / 2)
      ass = ass .. string.format("{\\an4}%s", item.label) .. "\n"

      local val_str = string.format("%.1f", tonumber(val) or 0)
      if item.step and item.step >= 0.5 then val_str = string.format("%.0f", tonumber(val) or 0) end

      ass = ass .. string.format("{\\fnCantarell\\b0\\fs%d\\1c&HBBBBBB\\alpha&H00\\pos(%d,%d)}", math.floor(font_size * 0.8), sx - pad_x, iy + (item_h - 4) / 2)
      ass = ass .. string.format("{\\an6}%s", val_str) .. "\n"
    else
      -- toggle / value display
      ass = ass .. string.format("{\\an4}%s", item.label) .. "\n"

      local vw = string.len(val) * font_size * 0.45
      ass = ass .. string.format("{\\b1\\fs%d\\1c&H66BBFF\\pos(%d,%d)}", font_size, cx + cw - pad_x * 2 - math.floor(vw), iy + (item_h - 4) / 2)
      ass = ass .. string.format("{\\an6}%s", val) .. "\n"
    end
  end

  -- help footer
  local footer_y = cy + ch + math.floor(font_size * 0.3)
  ass = ass .. string.format("{\\fs%d\\fnCantarell\\b0\\1c&H888888\\alpha&H00\\pos(%d,%d)}", math.floor(font_size * 0.6), cx + pad_x, footer_y)
  ass = ass .. "← → adjust  ·  ↑ ↓ navigate  ·  PgUp/PgDn categories  ·  ESC close" .. "\n"

  return ass
end

function render()
  if not state.open then
    if overlay then
      overlay:remove()
      overlay = nil
    end
    return
  end

  if not overlay then
    overlay = mp.create_osd_overlay("ass-events")
  end

  overlay.data = build_ass()
  overlay:update()
end

function toggle()
  state.open = not state.open
  if state.open then
    state.sel = 1
    mp.set_osd_ass(0, 0, "")
  end
  render()
end

function close()
  state.open = false
  render()
end

function is_open()
  return state.open
end

local function modify(offset)
  if not state.open then return end
  local items = categories[state.cat].items
  local item = items[state.sel]
  if not item then return end

  local val
  if item.fmt then
    local ok, v = pcall(item.fmt)
    if ok then val = v else val = nil end
  end
  if val == nil and item.prop then
    local ok, v = pcall(mp.get_property, item.prop)
    if ok then val = v end
  end

  if item.min and item.max then
    local num = tonumber(val)
    if num then
      local new = clamp(num + offset, item.min, item.max)
      if item.cmd then
        local cmd_str = string.format(item.cmd, new - num)
        mp.command(cmd_str)
      end
    end
  elseif item.cmd then
    mp.command(item.cmd)
  end
  render()
end

function navigate(direction)
  if not state.open then return end
  local items = categories[state.cat].items
  local n = #items
  state.sel = clamp(state.sel + direction, 1, n)
  render()
end

function switch_cat(direction)
  if not state.open then return end
  local n = #categories
  state.cat = ((state.cat - 1 + direction + n) % n) + 1
  state.sel = 1
  render()
end

-- keybindings
mp.add_forced_key_binding(opts.key_toggle, "settings-toggle", toggle)
mp.add_forced_key_binding(opts.key_close, "settings-close", close)

mp.add_forced_key_binding(opts.key_up, "settings-up", function() navigate(-1) end)
mp.add_forced_key_binding(opts.key_down, "settings-down", function() navigate(1) end)
mp.add_forced_key_binding(opts.key_left, "settings-left", function() modify(-1) end)
mp.add_forced_key_binding(opts.key_right, "settings-right", function() modify(1) end)
mp.add_forced_key_binding(opts.key_prev_cat, "settings-prev-cat", function() switch_cat(-1) end)
mp.add_forced_key_binding(opts.key_next_cat, "settings-next-cat", function() switch_cat(1) end)

-- handle mouse click on categories
local function on_click()
  if not state.open then return end
  local x, y = mp.get_mouse_pos()
  refresh_props()
  local w, h = screen_w, screen_h
  local panel_w = math.floor(w * 0.48)
  local panel_x = math.floor((w - panel_w) / 2)
  local panel_y = math.floor(h * 0.22)
  local tab_h = math.floor(font_size * 2.2)

  -- check category clicks
  local cat_count = #categories
  local tw = panel_w / cat_count
  if y >= panel_y and y <= panel_y + tab_h then
    for i = 1, cat_count do
      local tx = panel_x + (i - 1) * tw
      if x >= tx and x <= tx + tw then
        state.cat = i
        state.sel = 1
        render()
        return
      end
    end
  end
end

mp.register_script_message("settings-click", on_click)

-- render on ov
mp.observe_property("osd-dimensions", "native", function()
  if state.open then render() end
end)

mp.observe_property("mouse-pos", "native", function()
  if state.open then render() end
end)

-- flash OSD helper on any property change while panel is open
local props_to_watch = {"hwdec", "interpolation", "video-sync", "deinterlace", "brightness", "contrast", "saturation", "gamma", "video-aspect-override", "volume", "mute", "audio-delay", "sub-delay", "sub-scale", "sub-pos", "sub-visibility", "speed", "keep-open", "loop", "ontop", "border", "fullscreen"}
for _, p in ipairs(props_to_watch) do
  mp.observe_property(p, "native", function()
    if state.open then render() end
  end)
end

-- handle resize
mp.register_event("playback-restart", function()
  if state.open then render() end
end)
