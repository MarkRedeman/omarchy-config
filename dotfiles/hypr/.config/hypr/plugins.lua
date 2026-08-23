-- hy3 plugin configuration, themed from the active Omarchy theme.
--
-- Reads ~/.local/state/omarchy/current/theme/colors.toml so tab bars follow
-- omarchy-theme-set: theme switches run `hyprctl reload`
-- (omarchy-restart-hyprctl), which re-executes this file.
--
-- Also reads the corner radius from appearance.json (shared with
-- looknfeel.lua): tab radius = half the window rounding, capped at half the
-- tab height so huge radii stay sane on the 22px bar.

local function readFile(path)
  local file = io.open(path, "r")
  if not file then return nil end
  local blob = file:read("*a")
  file:close()
  return blob
end

local function readThemeColors()
  local colors = {}
  local blob = readFile((os.getenv("HOME") or "") .. "/.local/state/omarchy/current/theme/colors.toml")
  if blob then
    for key, value in blob:gmatch('([%w_]+)%s*=%s*"(#%x%x%x%x%x%x)"') do
      colors[key] = value
    end
  end
  return colors
end

local function readRounding()
  local blob = readFile((os.getenv("HOME") or "") .. "/.local/state/omarchy/appearance.json")
  if not blob then return 0 end
  return math.min(tonumber(blob:match('"rounding"%s*:%s*(%d+)') or 0), 128)
end

-- Tab borders mirror the theme's own chrome width (shell.toml
-- normal-border-width; 2 = our v3 fallback for themes without it).

local c = readThemeColors()

-- Palette fallbacks (ethereal-ish) for a missing/incomplete colors.toml.
local accent = c.accent or "#7d82d9"
local background = c.background or "#060B1E"
local darker = c.darker_background or c.dark_background or "#030610"
local foreground = c.foreground or "#ffcead"
local muted = c.muted or "#6d7db6"
local selection = c.selection or "#252e56"
local red = c.red or "#ED5B5A"
local yellow = c.yellow or "#E9BB4F"

local rounding = readRounding()
local tabRadius = math.min(math.floor(rounding / 2), 11)
-- Match the window border width (looknfeel sets general:border_size = 2
-- when gaps are on; the shell.toml chrome width of 1 renders thinner than
-- the window borders next to which the tabs sit).
local tabBorder = 2

-- Alpha variants: hy3 draws borders/text over its own bar background, so
-- soft borders read better than solid ones.
local function withAlpha(hex, alpha)
  return hex .. alpha -- "#rrggbb" .. "aa" -> "#rrggbbAA"
end

hl.config({
  plugin = {
    hy3 = {
      -- Keep nested groups only when the parent is a tab group (v3).
      node_collapse_policy = 2,
      group_inset = 10,

      tabs = {
        height = 22,
        -- Gap between tabs AND between the bar and its window. Note hy3
        -- also insets the first/last tab by padding/2 from the group edges
        -- (fixed in TabGroup.cpp, not configurable).
        padding = 6,
        from_top = false,
        radius = tabRadius,
        border_width = tabBorder,
        render_text = true,
        text_center = true,
        text_font = "JetBrainsMono Nerd Font",
        text_height = 8,
        text_padding = 3,
        blur = true,
        opacity = 1.0,

        colors = {
          -- Focused tab in the focused group: accent border on dark.
          active = darker,
          active_border = accent,
          active_text = foreground,

          -- Focused window's tab in an unfocused group.
          focused = selection,
          focused_border = muted,
          focused_text = foreground,

          -- Unfocused tabs.
          inactive = darker,
          inactive_border = withAlpha(muted, "55"),
          inactive_text = muted,

          -- Focused tab on a non-focused monitor.
          active_alt_monitor = darker,
          active_alt_monitor_border = withAlpha(muted, "88"),
          active_alt_monitor_text = muted,

          urgent = withAlpha(red, "40"),
          urgent_border = red,
          urgent_text = background,

          locked = withAlpha(yellow, "40"),
          locked_border = yellow,
          locked_text = background,
        },
      },
    },
  },
})
