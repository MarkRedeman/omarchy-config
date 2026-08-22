-- i3-style keybindings on top of Omarchy quattro defaults.
--
-- Omarchy's defaults stay enabled; keys we take over are released first with
-- hl.unbind(). Each unbind notes what quattro had there, so nothing is lost
-- silently. Review the live binding list with:
--   omarchy menu keybindings --print

local hy3 = hl.plugin.hy3

-- =============================================================================
-- Window management (i3-style, via hy3)
-- =============================================================================

-- Close window (i3: $mod+Shift+q). quattro's close lived on SUPER + W.
o.bind("SUPER + SHIFT + Q", "Close window", hl.dsp.window.close())

-- Focus (i3: $mod+h/j/k/l).
-- Reclaimed from quattro: SUPER+J split toggle, SUPER+K keybindings menu,
-- SUPER+L workspace layout toggle (both still reachable via the Omarchy menu).
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
-- SUPER + SHIFT + N was quattro's Editor binding; arrows were window swaps.
hl.unbind("SUPER + SHIFT + N")
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
-- SUPER + CTRL + F by default.

-- Toggle floating: use quattro's default SUPER + T (was SUPER + Shift + Space).

-- =============================================================================
-- Workspaces (i3-style)
-- =============================================================================

-- Workspace numbers 1-10 (+ shift to move) come from Omarchy defaults.

-- Back and forth (i3: $mod+z; quattro keeps it on SUPER + CTRL + TAB too)
o.bind("SUPER + Z", "Former workspace", hl.dsp.focus({ workspace = "previous" }))
o.bind(
  "SUPER + SHIFT + Z",
  "Move to former workspace",
  hy3.move_to_workspace("previous", { follow = false })
)

-- Monitor-scoped next/prev workspace (SUPER + N/P) and the named-workspace
-- selector are deferred — see QUATRO-MIGRATION.md §4.4. Until then,
-- SUPER + mouse wheel cycles workspaces globally (default).

-- =============================================================================
-- Applications (personal launcher keys that don't clash with defaults)
-- =============================================================================

o.bind("SUPER + ALT + B", "Browser", { omarchy = "browser" })
o.bind("SUPER + ALT + SHIFT + B", "Browser (private)", { omarchy = "browser --private" })
o.bind("SUPER + ALT + E", "Editor", { omarchy = "editor" })
o.bind("SUPER + ALT + M", "Music", { omarchy = "spotify" })
o.bind("SUPER + ALT + D", "Docker", { tui = "lazydocker" })

-- Deferred (see QUATRO-MIGRATION.md §4.1):
--   resize submap (SUPER + R), universal copy/paste (covered by defaults),
--   Apple display brightness, monitor-scale cycling (built-in on SLASH).
