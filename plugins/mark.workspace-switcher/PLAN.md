# mark.workspace-switcher — implementation plan

Status: **drafted, awaiting machine upgrade**. Implementation starts only after
the quattro upgrade (see `QUATRO-MIGRATION.md` §4.8). Decisions below are
locked; `[V]` items are verified against the running shell during
implementation.

A single Omarchy shell plugin that replaces the walker-based workspace
selector, adds a window picker, takes over monitor-scoped workspace cycling,
and shows named workspaces in the bar.

## 1. Why a plugin (goals)

- **Speed**: current selector spawns bash → `hyprctl -j` → several `jq` forks →
  walker (GUI cold start) per keypress (~300–800 ms). QML binds live
  Quickshell state instead — zero process spawns, opens within a frame.
- **Named workspaces become first-class**: today they vanish from SUPER+N/P
  cycling (Hyprland destroys empty workspaces, so they drop out of the
  `hyprctl workspaces` list) and never appear in the bar (built-in widget
  hardcodes ids 1–10).
- **Window navigation**: jump straight to any window's workspace and focus it.
- Survives quattro updates by living in user plugin space; hot-reloads on save.

Non-goals: replacing the bar itself, autotiling features, session management.

## 2. Architecture & files

Final runtime home (stowed):

```
dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.workspace-switcher/
├── manifest.json
├── Panel.qml            # switcher surface, two modes
├── Widget.qml           # custom Workspaces bar widget
└── WorkspacesModel.js   # shared sort/filter/cycle logic (pure JS)
```

Install: stow → `omarchy-shell shell rescanPlugins` → `omarchy plugin enable
mark.workspace-switcher`.

## 3. Manifest (draft)

```json
{
  "schemaVersion": 1,
  "id": "mark.workspace-switcher",
  "name": "Workspace Switcher",
  "version": "0.1.0",
  "author": "Mark Redeman",
  "description": "Fast workspace/window switcher with monitor-scoped cycling",
  "kinds": ["panel", "bar-widget"],
  "entryPoints": { "panel": "Panel.qml", "barWidget": "Widget.qml" },
  "barWidget": { "defaultSection": "left" }
}
```

Panel entry point must expose `open(payloadJson)` / `close()`; host injects
`omarchyPath`, `shell`, `manifest`, registries.

## 4. Panel UX

Summon: `SUPER+S` → `omarchy-shell shell toggle mark.workspace-switcher`.
Payload may preset the mode: `{"mode":"windows"}`.

**Mode A — Workspaces** (default)

- Rows: `id/name · monitor badge · Nw window count`
- Live filter box (subsequence match on name/id)
- Enter/click activates: dispatch focus to that workspace
- Typing a non-matching string creates + switches to that *named* workspace
  (preserves old walker-selector behaviour)
- Esc closes

**Mode B — Windows**

- `Tab` toggles modes; rows: app class/icon · title · workspace · monitor
- Activating focuses the owning workspace and then the window
- Same filter box and close behaviour

## 5. Configuration (manifest schema)

| Key | Type | Default | Purpose |
| --- | ---- | ------- | ------- |
| `defaultMode` | string | `"workspaces"` | mode opened by plain summon |
| `scope` | string | `"all"` | `"all"` / `"cursor"` / `"focused"` monitor filtering |
| `showMonitorBadges` | boolean | `true` | badge per row in multi-monitor setups |
| `showWindowCounts` | boolean | `true` | `Nw` suffix like the old dmenu |
| `namedAfterNumbers` | boolean | `true` | sort named workspaces after numeric ones |
| `closeOnActivate` | boolean | `true` | dismiss panel after switching |

Exact schema type names beyond `multiselect`/`boolean` to be confirmed against
`shell/services/PluginRegistry.qml` at implementation.

## 6. Multi-monitor semantics

- Every row carries its owning monitor; activating a foreign-monitor workspace
  moves focus there (native Hyprland behaviour).
- `scope` config narrows the list for per-monitor pickers.
- Window mode always shows each window's monitor.

## 7. Monitor-scoped cycling (plugin-owned)

Rebind in `bindings.lua`:

```lua
o.bind("SUPER + N", "Next workspace on this monitor",
       "omarchy-shell shell call mark.workspace-switcher cycle next")
o.bind("SUPER + P", "Previous workspace on this monitor",
       "omarchy-shell shell call mark.workspace-switcher cycle prev")
```

Semantics (locked):

- Scope = focused monitor (shell runs in-session; no cursor/focused split
  needed anymore)
- Order: numeric ascending, then known named workspaces (respecting
  `namedAfterNumbers`)
- Universe = existing ∪ recently-remembered named workspaces; **wrap only —
  cycling never creates anything**
- `dotfiles/bin/omarchy-waybar-workspace-scroll` retires once the plugin cycle
  is verified

## 8. Bar widget (v1)

- Numbered chips 1–10 with upstream occupancy/focused styling
- Compact truncated-name chips for known named workspaces (same remembered set
  as cycling), appended per `namedAfterNumbers`
- Occupancy via `workspace.toplevels.values.length`, focused via
  `Hyprland.focusedWorkspace`
- Activated from `shell.json` by replacing `omarchy.workspaces` with
  `mark.workspace-switcher`

## 9. Implementation sequencing (post-upgrade)

1. Scaffold plugin dir + manifest; `rescanPlugins`; confirm registry loads it
2. Verify `[V]` unknowns below using the hot-reload loop
3. WorkspacesModel.js (sort/filter/cycle) → Panel Mode A → Mode B
4. IPC: `cycle next|prev` (+ optional own target if needed)
5. Widget.qml; swap into `shell.json`
6. Rebind `S/N/P` in `bindings.lua`; retire scroll script; update tracker

## 10. Known unknowns (`[V]` at implementation time)

- Exact `Toplevel` property names (title / appId / workspace ref / monitor)
- Dispatching from panel context: `Hyprland.dispatch()` availability vs the
  injected helper used by built-ins (`root.bar.run("hyprctl …")`)
- Full supported schema type list in PluginRegistry settings UI
- Panel positioning/sizing API and multi-monitor anchoring
- Whether `keepLoaded: true` is needed for instant re-summons
