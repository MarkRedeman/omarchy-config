-- Change the default Omarchy look'n'feel.
-- See https://wiki.hyprland.org/Configuring/Basics/Variables/
--
-- Appearance is state-driven: gap size + corner rounding live in
-- ~/.local/state/omarchy/appearance.json, written by the mark.appearance
-- panel and the omarchy-appearance-* scripts. Missing file = i3-style zeros.
--
--   "gap"      - inner gap in px (outer gap = 2x). 0 = i3-style zeros.
--   "rounding" - corner radius in px (0-128).
-- The panel's sliders step through powers of two: 0 1 2 4 8 16 32 64 128.

local USE_HY3 = true

local gap, rounding = 0, 0
do
  local path = (os.getenv("HOME") or "") .. "/.local/state/omarchy/appearance.json"
  local file = io.open(path, "r")
  if file then
    local blob = file:read("*a")
    file:close()
    gap = math.min(tonumber(blob:match('"gap"%s*:%s*(%d+)') or 0), 128)
    rounding = math.min(tonumber(blob:match('"rounding"%s*:%s*(%d+)') or 0), 128)
  end
end

hl.config({
  general = {
    layout = USE_HY3 and "hy3" or "dwindle",

    gaps_in = gap,
    gaps_out = gap * 2,
    border_size = gap > 0 and 2 or 0,
  },

  decoration = {
    rounding = rounding,

    -- Dim unfocused windows instead of using inactive_opacity
    dim_inactive = true,
    dim_strength = 0.1,
  },

  binds = {
    -- Pressing SUPER+3 while already on workspace 3 goes back to the
    -- previous workspace
    workspace_back_and_forth = true,
  },
})
