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

    -- Dimming only kicks in while a special workspace is open, so the
    -- scratchpad gets its overlay separation without costing anything the
    -- rest of the time.
    dim_special = 0.6,
  },

  binds = {
    -- Pressing SUPER+3 while already on workspace 3 goes back to the
    -- previous workspace
    workspace_back_and_forth = true,
  },
})

-- Give the scratchpad a Quake-console feel: a large outer gap floats it over
-- the dimmed workspace, and it slides down into view and retracts back up.
-- The inner gap and rounding are inherited from the appearance settings above,
-- so the scratchpad otherwise matches every other window. Shadow and blur
-- stay off globally (they cost GPU on every frame for almost no visual gain).
hl.workspace_rule({
  workspace = "special:scratchpad",
  gaps_out = 40 + 4 * gap,
  gaps_in = 2 * gap,
})

-- The base defaults set the combined specialWorkspace leaf to slidevert; turn
-- it off so the directional In/Out slides below take over.
hl.animation({ leaf = "specialWorkspace", enabled = false })
-- The direction names the edge the offset is measured from, not where the
-- workspace goes: "slide top" drops it down into view, and "slide bottom"
-- retracts it back up the way a Quake console does.
hl.animation({ leaf = "specialWorkspaceIn", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide top" })
hl.animation({ leaf = "specialWorkspaceOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "slide bottom" })
