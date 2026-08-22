-- Change the default Omarchy look'n'feel.
-- See https://wiki.hyprland.org/Configuring/Basics/Variables/

-- hy3 provides the i3/sway-style manual tiling layout. If the plugin is not
-- loaded (build failure after a Hyprland update, etc.) flip this to false so
-- the session falls back to the built-in dwindle layout.
local USE_HY3 = true

hl.config({
  general = {
    -- No gaps between windows or borders
    gaps_in = 0,
    gaps_out = 0,
    border_size = 0,

    layout = USE_HY3 and "hy3" or "dwindle",
  },

  decoration = {
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
