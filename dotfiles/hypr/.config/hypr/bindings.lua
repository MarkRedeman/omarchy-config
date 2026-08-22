-- i3-style keybindings on top of Omarchy quattro defaults.
--
-- Omarchy's defaults stay enabled; keys we take over are released first with
-- hl.unbind(). Each unbind notes what quattro had there, so nothing is lost
-- silently. Review the live binding list with:
--   omarchy menu keybindings --print
--
-- Conventions carried over from our v3 setup:
--   * window/workspace management lives on plain SUPER (+ modifiers)
--   * application launchers always carry an ALT modifier; terminals are the
--     exception at SUPER + RETURN

local hy3 = hl.plugin.hy3

-- =============================================================================
-- Window management (i3-style, via hy3)
-- =============================================================================

-- Close window (i3: $mod+Shift+q). Reclaimed from quattro: SUPER + W.
hl.unbind("SUPER + W")
o.bind("SUPER + SHIFT + Q", "Close window", hl.dsp.window.close())

-- Focus (i3: $mod+h/j/k/l).
-- Reclaimed from quattro: SUPER+J split toggle, SUPER+K keybindings menu,
-- SUPER+L workspace layout toggle (all still reachable via the Omarchy menu).
hl.unbind("SUPER + J")
hl.unbind("SUPER + K")
hl.unbind("SUPER + L")
o.bind("SUPER + H", "Move focus left", hy3.move_focus("l"))
o.bind("SUPER + J", "Move focus down", hy3.move_focus("d"))
o.bind("SUPER + K", "Move focus up", hy3.move_focus("u"))
o.bind("SUPER + L", "Move focus right", hy3.move_focus("r"))

-- Focus with arrow keys (quattro binds these to its built-in focus dispatcher;
-- hy3 needs its own for correct behaviour in nested/tabbed groups)
hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
o.bind("SUPER + LEFT", "Move focus left", hy3.move_focus("l"))
o.bind("SUPER + RIGHT", "Move focus right", hy3.move_focus("r"))
o.bind("SUPER + UP", "Move focus up", hy3.move_focus("u"))
o.bind("SUPER + DOWN", "Move focus down", hy3.move_focus("d"))

-- Move windows (i3: $mod+Shift+h/j/k/l).
-- Reclaimed from quattro: arrow swaps and SUPER+SHIFT+N editor binding.
hl.unbind("SUPER + SHIFT + LEFT")
hl.unbind("SUPER + SHIFT + RIGHT")
hl.unbind("SUPER + SHIFT + UP")
hl.unbind("SUPER + SHIFT + DOWN")
o.bind("SUPER + SHIFT + H", "Move window left", hy3.move_window("l"))
o.bind("SUPER + SHIFT + J", "Move window down", hy3.move_window("d"))
o.bind("SUPER + SHIFT + K", "Move window up", hy3.move_window("u"))
o.bind("SUPER + SHIFT + L", "Move window right", hy3.move_window("r"))
o.bind("SUPER + SHIFT + LEFT", "Move window left", hy3.move_window("l"))
o.bind("SUPER + SHIFT + RIGHT", "Move window right", hy3.move_window("r"))
o.bind("SUPER + SHIFT + UP", "Move window up", hy3.move_window("u"))
o.bind("SUPER + SHIFT + DOWN", "Move window down", hy3.move_window("d"))

-- Split orientation and tab groups (i3: $mod+v / $mod+e / $mod+w)
o.bind("SUPER + SHIFT + V", "Toggle split direction", hy3.make_group("opposite"))
o.bind("SUPER + E", "Toggle split layout", hy3.change_group("toggletab"))
o.bind("SUPER + W", "Toggle tab group", hy3.make_group("tab", { toggle = true }))

-- Focus parent / child (i3: $mod+a). SUPER + SHIFT + A was ChatGPT webapp.
hl.unbind("SUPER + SHIFT + A")
o.bind("SUPER + A", "Focus parent", hy3.change_focus("raise"))
o.bind("SUPER + SHIFT + A", "Focus child", hy3.change_focus("lower"))

-- Cycle through tabs in a group with wrap. TAB cycled workspaces in quattro;
-- workspace cycling remains on SUPER + mouse wheel.
hl.unbind("SUPER + TAB")
hl.unbind("SUPER + SHIFT + TAB")
o.bind("SUPER + TAB", "Next tab", hy3.focus_tab({ direction = "r", wrap = true }))
o.bind("SUPER + SHIFT + TAB", "Previous tab", hy3.focus_tab({ direction = "l", wrap = true }))

-- Fullscreen: SUPER + F (default) matches i3; tiled fullscreen is on
-- SUPER + CTRL + F by default. Floating toggle stays on quattro's SUPER + T
-- (our old SUPER + Shift + Space toggles the top bar there — kept as-is).

-- =============================================================================
-- Workspaces (i3-style)
-- =============================================================================

-- Workspace switching on SUPER + 1..0 comes from Omarchy defaults.
-- Moving windows to workspaces is rebound below: quattro follows the moved
-- window to its target; our i3-style map keeps focus where it was (silent).
for workspace = 1, 10 do
  local key = "SUPER + SHIFT + code:" .. tostring(workspace + 9)
  hl.unbind(key)
  o.bind(
    key,
    "Move window silently to workspace " .. workspace,
    hl.dsp.window.move({ workspace = tostring(workspace), follow = false })
  )
end

-- Back and forth (i3: $mod+z; quattro also keeps former-workspace on CTRL+TAB)
o.bind("SUPER + Z", "Former workspace", hl.dsp.focus({ workspace = "previous" }))
o.bind(
  "SUPER + SHIFT + Z",
  "Move to former workspace",
  hl.dsp.window.move({ workspace = "previous", follow = false })
)

-- Next/prev *existing* workspace scoped to the current monitor
-- (multi-monitor safe). Script name kept for continuity; it is pure
-- hyprctl/jq so it works on quattro unchanged.
-- Reclaimed from quattro: SUPER + S scratchpad (still on SUPER + grave),
-- SUPER + P pseudo window.
hl.unbind("SUPER + S")
hl.unbind("SUPER + P")
o.bind("SUPER + S", "Workspace selector", "omarchy-workspace-select")
o.bind("SUPER + N", "Next workspace on this monitor", "omarchy-waybar-workspace-scroll next focused")
o.bind("SUPER + P", "Previous workspace on this monitor", "omarchy-waybar-workspace-scroll prev focused")

-- Move window to next/prev workspace, following it (i3: $mod+Shift+n/p).
-- SUPER + SHIFT + N was quattro's Editor binding.
hl.unbind("SUPER + SHIFT + N")
o.bind("SUPER + SHIFT + N", "Move window to next workspace", hl.dsp.window.move({ workspace = "e+1" }))
o.bind("SUPER + SHIFT + P", "Move window to previous workspace", hl.dsp.window.move({ workspace = "e-1" }))

-- Move whole workspace to another monitor. Arrows are quattro defaults;
-- these add the vim-key equivalents (i3: $mod+Shift+Ctrl+h/j/k/l).
o.bind("SUPER + SHIFT + CTRL + H", "Move workspace to left monitor", hl.dsp.workspace.move({ monitor = "l" }))
o.bind("SUPER + SHIFT + CTRL + J", "Move workspace to down monitor", hl.dsp.workspace.move({ monitor = "d" }))
o.bind("SUPER + SHIFT + CTRL + K", "Move workspace to up monitor", hl.dsp.workspace.move({ monitor = "u" }))
o.bind("SUPER + SHIFT + CTRL + L", "Move workspace to right monitor", hl.dsp.workspace.move({ monitor = "r" }))

-- Scroll through workspaces on SUPER + mouse wheel comes from defaults.

-- =============================================================================
-- Resize mode (i3: $mod+r enters a resize submap)
-- =============================================================================

-- If ever stuck inside a submap: hyprctl dispatch 'hl.dsp.submap("reset")'
o.bind("SUPER + R", "Resize mode", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
  -- h/j/k/l + arrows resize by 50px; hold shift (or capital letters) for 150px
  local steps = {
    { key = "h",             x = -50,  y = 0 },
    { key = "l",             x = 50,   y = 0 },
    { key = "k",             x = 0,    y = -50 },
    { key = "j",             x = 0,    y = 50 },
    { key = "left",          x = -50,  y = 0 },
    { key = "right",         x = 50,   y = 0 },
    { key = "up",            x = 0,    y = -50 },
    { key = "down",          x = 0,    y = 50 },
    { key = "H",             x = -150, y = 0, desc = "large" },
    { key = "L",             x = 150,  y = 0, desc = "large" },
    { key = "K",             x = 0,    y = -150, desc = "large" },
    { key = "J",             x = 0,    y = 150, desc = "large" },
    { key = "SHIFT + left",  x = -150, y = 0, desc = "large" },
    { key = "SHIFT + right", x = 150,  y = 0, desc = "large" },
    { key = "SHIFT + up",    x = 0,    y = -150, desc = "large" },
    { key = "SHIFT + down",  x = 0,    y = 150, desc = "large" },
  }
  for _, step in ipairs(steps) do
    hl.bind(step.key, hl.dsp.window.resize({ x = step.x, y = step.y, relative = true }), {
      repeating = true,
      description = step.desc and ("Resize window (" .. step.desc .. ")") or "Resize window",
    })
  end

  -- Return/Esc exit (unbound keys pass through to windows, like i3)
  hl.bind("return", hl.dsp.submap("reset"), { description = "Exit resize mode" })
  hl.bind("escape", hl.dsp.submap("reset"), { description = "Exit resize mode" })
end)

-- =============================================================================
-- Applications (launchers carry an ALT modifier; terminals on RETURN)
-- =============================================================================

-- Terminal opens in the working directory of the active terminal.
-- (quattro's defaults on these keys launch without cwd.)
hl.unbind("SUPER + RETURN")
hl.unbind("SUPER + ALT + RETURN")
o.bind(
  "SUPER + RETURN",
  "Terminal",
  'uwsm-app -- xdg-terminal-exec --working-directory="$(omarchy-cmd-terminal-cwd)"'
)

-- App launcher (i3: $mod+d via rofi/dmenu). SUPER + SPACE keeps the menu.
o.bind("SUPER + D", "Launch apps", "omarchy-menu toggle apps")

-- Browser
o.bind("SUPER + ALT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + ALT + SHIFT + B", "Browser (private)", { omarchy = "browser --private" })

-- File manager (quattro's own variants live on SUPER + SHIFT + F ± ALT)
o.bind("SUPER + ALT + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + ALT + SHIFT + F", "File manager (cwd)", { omarchy = "nautilus-cwd" })

-- Editor / Music / Docker
o.bind("SUPER + ALT + E", "Editor", { omarchy = "editor" })
o.bind("SUPER + ALT + M", "Music", { omarchy = "spotify" })
o.bind("SUPER + ALT + D", "Docker", { tui = "lazydocker" })

-- Clipboard manager (quattro's default panel toggle stays on SUPER+CTRL+V)
o.bind("SUPER + ALT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")

-- =============================================================================
-- Menus & system
-- =============================================================================

-- Root Omarchy menu. Reclaimed from quattro's Apps menu (apps remain on
-- SUPER + SPACE via the launcher above).
hl.unbind("SUPER + ALT + SPACE")
o.bind("SUPER + ALT + SPACE", "Omarchy menu", "omarchy-menu")

-- Reload config (i3: $mod+Shift+c)
o.bind("SUPER + SHIFT + C", "Reload config", "hyprctl reload")

-- Apple display brightness over DDC
o.bind("CTRL + F1", "Apple Display brightness down", "omarchy-brightness-display-apple -5000")
o.bind("CTRL + F2", "Apple Display brightness up", "omarchy-brightness-display-apple +5000")
o.bind("SHIFT + CTRL + F2", "Apple Display full brightness", "omarchy-brightness-display-apple +60000")

-- =============================================================================
-- Notes (defaults kept intentionally)
-- =============================================================================
-- * SUPER + SPACE        Omarchy menu (was tiling/floating focus toggle in v3;
--                        float toggle lives on SUPER + T)
-- * SUPER + SHIFT + C    reload (above); lock/menu/capture/notification/
--                        screenshot/zoom/media clusters match v3 already
-- * SUPER + SLASH        scaling is built-in now (up / ALT+SLASH down), which
--                        replaces the v3 cycle script
-- * notification history replaced mako's "restore last notification"
-- * universal copy/paste (SUPER+C/V/X) is built-in, terminal-aware
