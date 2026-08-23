# mark.workspace-switcher

Status: **v0.1 implemented** (2026-08-23) — bar chips, monitor-scoped cycling,
and the workspace switcher panel are live. The window picker (Mode B) is
deferred; see §8.

A single Omarchy shell plugin that shows occupied-only workspaces in the bar,
owns SUPER+N/P monitor-scoped cycling, and replaces the retired walker-based
selector on SUPER+S.

## 1. Why a plugin (goals)

- **Correctness**: quattro's Lua config broke the old tooling outright —
  `hyprctl dispatch <string>` never resolves under the Lua config
  (`hl.dispatch: expected a dispatcher`), killing both
  `omarchy-waybar-workspace-scroll` (N/P) and walker-based
  `omarchy-workspace-select` (S). The plugin computes targets in QML and only
  ever dispatches through the Lua form (`hyprctl dispatch 'hl.dsp.focus({ … })'`),
  which does resolve.
- **Named workspaces become first-class**: they survive in cycling order and
  appear in the bar (the built-in widget hardcodes ids 1–10).
- **Speed**: QML state instead of bash → hyprctl → jq → walker per keypress.
- Survives quattro updates by living in user plugin space; hot-reloads on save.

Non-goals: replacing the bar itself, autotiling features, session management.

## 2. Architecture & files

Runtime home (stowed from the repo):

```
dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.workspace-switcher/
├── manifest.json        # kinds: panel + bar-widget, keepLoaded: true
├── Panel.qml            # switcher surface (workspaces mode) + cycle() IPC
├── Widget.qml           # occupied-only name chips for the bar
└── WorkspacesModel.js   # shared list/sort/cycle logic (.pragma library)
```

Install: `scripts/deploy.sh` stows it like any package; then
`omarchy-shell shell rescanPlugins`. Enabling happens through `shell.json`
(the widget sits in `bar.layout.left`, the panel needs no entry because
third-party panels in `plugins[]` are only required when there is no other
enabled kind — this plugin is enabled via its bar-widget placement).

## 3. Hyprland facts the design relies on (verified 0.56.2)

- Numeric workspaces have positive ids; anything above 10 can exist via
  e+1-style moves. Id 10 renders as "0".
- **All named workspaces share one negative id** (-1337 during testing), so
  ids identify neither order nor even uniqueness among them. Named spaces are
  addressed by `name:<x>` and tracked by name everywhere.
- Special workspaces are negative-id entries named `special:*`; excluded by
  name prefix, not id sign.
- Empty workspaces are destroyed the moment focus leaves them, so the bar and
  the cycling universe are "existing" only — cycling wraps and never creates.
- Plugin string dispatchers are unreachable from Lua binds and from
  `hyprctl dispatch <name>` (upstream gap, hyprwm/Hyprland discussion #14451);
  the parenthesized Lua-eval form works, which is all we need.

## 4. Ordering & cycling semantics (locked)

- Bar chips and panel rows: numeric workspaces ascending (1..10, then any
  higher numbers), followed by named workspaces in first-seen creation order.
- Creation order lives in a shared registry inside WorkspacesModel.js
  (single instance per engine thanks to `.pragma library`), fed by
  `createworkspace` raw events; re-created names keep their original slot for
  the life of the shell session.
- SUPER+N/P scope = focused monitor, wrap-around, existing workspaces only,
  never create/destroy.
- SUPER+S lists all monitors (rows carry a monitor badge once multi-monitor);
  activating a foreign-monitor row moves focus there (native behaviour).

## 5. Wiring

```lua
-- bindings.lua
o.bind("SUPER + S", "Workspace selector",
       "omarchy-shell shell toggle mark.workspace-switcher")
o.bind("SUPER + N", "Next workspace on this monitor",
       "omarchy-shell shell call mark.workspace-switcher cycle next")
o.bind("SUPER + P", "Previous workspace on this monitor",
       "omarchy-shell shell call mark.workspace-switcher cycle prev")
```

Retired with this change: `dotfiles/bin/.local/bin/omarchy-workspace-select`
and `omarchy-waybar-workspace-scroll` (both dead under quattro's config
parser).

## 6. Panel UX (Mode A — shipped)

- Filter box over all existing workspaces (substring on display/name/id)
- Rows: `name · monitor · Nw`; focused workspace bolded; Enter/click activates
- Typing a query that matches no *name* appends a `+ Create “…”` row:
  activating it focuses `name:<query>`, creating the workspace
- Esc clears the filter, then closes; Up/Down/Home-style selection via keys or
  hover

## 7. Bar widget (v1 — shipped)

Occupied-or-focused workspaces of the focused monitor as plain name chips,
v3-waybar styling: unfocused at 0.5 opacity, focused bold at full opacity.
Click focuses; wheel up/down cycles prev/next. Logic adapted from
murdialthaf/omarchy-named-workspaces (MIT).

## 8. Phase 2 (not started)

- **Mode B — window picker**: Tab toggles rows of
  `app class/icon · title · workspace · monitor`; activation focuses the
  owning workspace then the window. Panel skeleton already hosts the mode
  switch point.
- Persist the named-workspace ordering across shell restarts
  (~/.local/state/omarchy JSON, FileView pattern).
- Per-instance settings schema (PluginRegistry settings UI) if knobs are
  wanted: `maxChars`, `showMonitorBadges`, `closeOnActivate`.
