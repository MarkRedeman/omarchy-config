# Handoff: reproducing the look'n'feel

This is everything needed to make a fresh Omarchy machine look and behave like
this one: theme, gaps, corner radius, window opacity, hy3 tab styling, and the
workspace bar widget.

> **Branch matters.** `quatro` is the Omarchy quattro (v4) setup described here.
> `main` is the legacy v3 layout (hyprlang + waybar) and has no `shell.json`,
> no `mark.*` plugins, and no Lua looknfeel. Deploying `main` on a fresh laptop
> is the most common way to "lose" this setup.

## What is (and isn't) in git

| Thing | Source of truth | Tracked? |
|---|---|---|
| Gaps + corner radius | `~/.local/state/omarchy/appearance.json` | **No** — seeded by `scripts/deploy.sh` from `scripts/appearance.default.json` |
| Active theme | `~/.local/state/omarchy/current/theme.name` | **No** — deploy applies `ethereal` on first run |
| Theme palette | `/usr/share/omarchy/themes/<name>/colors.toml` | Upstream package |
| Window opacity | `dotfiles/hypr/.config/hypr/hyprland.lua` | Yes |
| Hy3 tab styling | `dotfiles/hypr/.config/hypr/plugins.lua` | Yes |
| Shell bar layout | `dotfiles/omarchy/.config/omarchy/shell.json` | Yes |
| Plugins | `dotfiles/omarchy-plugins/.config/omarchy/plugins/` | Yes |
| Appearance panel | `dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.appearance/` | Yes |

The two state files are under `~/.local/state`, which stow does not manage.
That is why a fresh deploy used to come up with i3-style zeros and no theme.

## Fully automated reproduce

```bash
git clone git@github.com:MarkRedeman/omarchy-config.git ~/projects/omarchy-config
cd ~/projects/omarchy-config
git switch quatro

# Omarchy quattro must already be installed (Hyprland Lua config + shell).
~/projects/omarchy-config/scripts/deploy.sh
```

On a machine that has never had `appearance.json`, the deploy now:

1. copies `scripts/appearance.default.json` to
   `~/.local/state/omarchy/appearance.json` (gap `4`, rounding `8`), and
2. runs `omarchy-theme-set ethereal`.

It only does this once. Later deploys leave your current theme and appearance
values alone.

Restart Hyprland / the shell afterwards if the deploy did not already do it:

```bash
hyprctl reload
omarchy-restart-shell
```

## Manual reproduce (no deploy)

```bash
# Theme
omarchy-theme-set ethereal

# Gaps + corner radius (writes state and live-applies via hyprctl eval)
omarchy-appearance-set gap 4
omarchy-appearance-set rounding 8

# Verify
hyprctl -j getoption general:gaps_in
hyprctl -j getoption general:gaps_out
hyprctl -j getoption decoration:rounding
hyprctl configerrors
```

Equivalent state file:

```json
{
  "gap": 4,
  "rounding": 8
}
```

### How the values map to Hyprland

`dotfiles/hypr/.config/hypr/looknfeel.lua` is loaded last: package defaults →
active theme's `hyprland.lua` → our file. It reads `appearance.json` and sets:

- `general:gaps_in` = `gap`
- `general:gaps_out` = `2 * gap`
- `general:border_size` = `2` when `gap > 0`, else `0`
- `decoration:rounding` = `rounding`
- scratchpad: `gaps_in = 2 * gap`, `gaps_out = 40 + 4 * gap`

The panel and scripts step through powers of two: `0 1 2 4 8 16 32 64 128`.
Presets are **i3 = 0**, **Comfort = 4**, **Wide = 8**.

### Window opacity

Pinned in `dotfiles/hypr/.config/hypr/hyprland.lua`:

```lua
o.window({ tag = "default-opacity" }, { opacity = "0.985 0.96" })
```

The pair is **active opacity / inactive opacity**. Omarchy upstream applies
the same values from `/usr/share/omarchy/default/hypr/windows.lua`; keeping the
line in our repo means a future upstream change cannot silently alter the look.

- To change it, edit that one line and run `hyprctl reload`.
- Use the window rule rather than `decoration.active_opacity` /
  `decoration.inactive_opacity`: the upstream tag rule overrides those
  decoration defaults for every tagged window.
- Apps opt out by dropping the `default-opacity` tag rather than setting their
  own opacity. Emacs is kept fully opaque this way:

  ```lua
  o.window("^(emacs)$", { tag = "-default-opacity", opacity = "1 1" })
  ```

## Hy3 tab styling

`dotfiles/hypr/.config/hypr/plugins.lua` derives tabs from the active theme:

- **Radius:** `floor(rounding / 2)`, capped at `11` (half of the 22px tab bar).
- **Colors:** parsed from `~/.local/state/omarchy/current/theme/colors.toml`.
  Active tab = darker background + accent border; focused = selection/muted;
  inactive = muted at 55% alpha; urgent = red; locked = yellow.
- **Border width:** `2`, matching the window border.
- **Padding:** `6` (gap between tabs and between bar and window). Hy3 also
  insets the outer first/last tabs by `padding / 2`; that is not configurable.
- Theme switches run `hyprctl reload`, which re-reads `colors.toml`.

## Bar widget: `mark.workspace-switcher`

This is the occupied-workspace name chips widget in the bar. It is both a
`bar-widget` and a `panel`:

- Bar entry: `shell.json` → `bar.layout.left` → `{ "id": "mark.workspace-switcher" }`
- Plugin: `dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.workspace-switcher/`
- Panel: `SUPER + S`
- Cycle: `SUPER + N` / `SUPER + P` (monitor-scoped)

### Why it can disappear

1. **Deployed from `main` (v3).** v3 uses waybar, not the quattro shell. Check
   `git branch --show-current` is `quatro`.
2. **Plugin directory is not linked.** On a quattro machine:
   ```bash
   ls -l ~/.config/omarchy/plugins/
   ```
   It should show a `mark.workspace-switcher` symlink into this repo.
3. **`shell.json` lost the layout entry.** The running shell rewrites
   `shell.json` atomically; an Omarchy upgrade/migration can also rewrite it.
   Check:
   ```bash
   omarchy-shell shell listShellConfig | jq '.bar.layout.left'
   ```
4. **The shell has not rescanned plugins** after the files appeared.

### Re-enable it

```bash
# 1. Make sure the plugin files are linked (re-stow the package)
cd ~/projects/omarchy-config
stow --restow --target="$HOME" --dir=dotfiles omarchy-plugins

# 2. Make the shell discover them
omarchy-shell shell rescanPlugins

# 3. Put the widget back on the left of the bar, next to the menu
omarchy-shell shell putBarWidget mark.workspace-switcher \
  '{"section":"left","after":"omarchy.menu"}'

# 4. Verify
omarchy-shell shell listPlugins | jq '.[] | select(.id=="mark.workspace-switcher")'
omarchy-shell shell debugBarGeometry | jq '.[] | select(.id=="mark.workspace-switcher")'
```

`putBarWidget` is idempotent: it leaves an already-placed widget where it is.
If the shell is not running, restart it first with `omarchy-restart-shell`.

### `shell.json` is a symlink until the shell rewrites it

`ls -l ~/.config/omarchy/shell.json` normally shows a symlink into this repo.
After a settings change or upgrade the shell may replace it with a regular file
(same content, different inode), which means later edits in the repo do not
reach the live config. Re-link it with:

```bash
cd ~/projects/omarchy-config
mv ~/.config/omarchy/shell.json /tmp/shell.json.bak
stow --restow --target="$HOME" --dir=dotfiles omarchy
omarchy-restart-shell
```

Then restart the shell so it reads the tracked copy.

## Appearance panel (`mark.appearance`)

This is the panel that changes gaps, corner radius, and the theme. It is a
**summoned panel, not a bar widget** — it does not appear in the bar and is
enabled by `plugins[]` in `shell.json`, not by `bar.layout`:

```json
"plugins": [
  {
    "id": "mark.appearance"
  }
]
```

- `SUPER + ALT + A` opens it (again to close; `q` also closes it).
- `SUPER + CTRL + G` cycles gaps through i3 → Comfort → Wide without opening
  the panel.
- Sections: Gaps (presets + slider), Corner radius (slider), Theme
  (searchable picker with preview + Apply/Revert).
- Both sliders step `0 1 2 4 8 16 32 64 128`.
- Every change writes `~/.local/state/omarchy/appearance.json` and applies
  live via `omarchy-appearance-set`.
- Changing the radius also updates `Style.cornerRadius` (panels and
  notifications), not just Hyprland windows.

### Re-enable the panel

```bash
# 1. Plugin files must be linked
cd ~/projects/omarchy-config
stow --restow --target="$HOME" --dir=dotfiles omarchy-plugins

# 2. Shell must rescan and know the plugin is enabled
omarchy-shell shell rescanPlugins
omarchy-shell shell listPlugins | jq '.[] | select(.id=="mark.appearance")'
# enabled should be true; if not:
omarchy-shell shell enablePlugin mark.appearance '{}'
omarchy-shell shell toggle mark.appearance

# 3. Verify it can read/write the state
omarchy-shell shell call mark.appearance status ''
```

Expected status looks like:

```json
{"opened":false,"gap":4,"rounding":8,"shellRadius":8,"theme":"ethereal",...}
```

If `listPlugins` does not show `mark.appearance` at all, the plugin directory
is not linked or the shell has not rescanned. If it shows `enabled: false`,
the `plugins[]` entry is missing from `shell.json` — re-stow `omarchy` (or run
the `enablePlugin` command above).

## Quick sanity check

```bash
hyprctl -j getoption general:gaps_in          # {"css":"4 4 4 4"}
hyprctl -j getoption decoration:rounding      # 8
hyprctl -j getoption plugin:hy3:tabs:radius   # 4
hyprctl -j getoption plugin:hy3:tabs:border_width  # 2
cat ~/.local/state/omarchy/current/theme.name # ethereal
omarchy-shell shell debugBarGeometry | jq -r '.[].id' | grep workspace-switcher
```
