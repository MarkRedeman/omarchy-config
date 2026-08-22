# Quattro (Omarchy v4) Migration

Tracker for upgrading these dotfiles from Omarchy **v3 (3.8.x)** to Omarchy
**quattro (4.0.0.alpha)**. References live in `references/omarchy-v3/` and
`references/omarchy-quatro/`.

> ## TODO — open work item
>
> - **Build the `mark.workspace-switcher` shell plugin** after the machine
>   upgrade. Full spec: [`plugins/mark.workspace-switcher/PLAN.md`](plugins/mark.workspace-switcher/PLAN.md).
>   It replaces the walker-based `omarchy-workspace-select` (bound to
>   `SUPER + S`, fails silently on quattro), takes over SUPER+N/P cycling,
>   and adds named-workspace bar chips. Implementation starts only after the
>   quattro upgrade; everything else below is done, obsolete-and-removed, or
>   blocked on a live system ([V] items).

Status legend:

| Mark | Meaning |
| ---- | ------- |
| `[ ]` | Todo |
| `[~]` | In progress |
| `[x]` | Done |
| `[D]` | Deferred by choice — must be ported before go-live or accepted as lost |
| `[O]` | Obsolete in quattro — drop at cutover |
| `[V]` | Unknown — verify during/after the machine upgrade |

---

## 1. What makes these dotfiles special

Personal [Omarchy](https://omarchy.org) config managed with **GNU Stow**
(`dotfiles/<pkg>/.config/<app>/…`, deployed via `scripts/deploy.sh` /
`scripts/stow.sh`). Everything below is layered on top of upstream Omarchy.

### 1.1 i3-style manual tiling via hy3 (the defining feature)

Hyprland runs with the [hy3](https://github.com/outfoxxed/hy3) plugin
(installed through `hyprpm`) instead of dwindle/master. `looknfeel.conf` sets
`layout = hy3`, zero gaps, zero borders, dimmed inactive windows.

`bindings.conf` recreates an i3 workflow:

- Vim keys `SUPER+H/J/K/L` (+ arrows) for focus and `SUPER+SHIFT+…` for moving
  windows (`hy3:movefocus` / `hy3:movewindow`)
- Tab groups: `SUPER+W` makegroup tab toggle, `SUPER+E` toggletab,
  `SUPER+TAB` / `SUPER+SHIFT+TAB` cycle tabs with wrap
- Focus parent/child: `SUPER+A` / `SUPER+SHIFT+A` (`hy3:changefocus raise/lower`)
- Split direction: `SUPER+SHIFT+V` (`hy3:makegroup opposite`)
- Resize **submap** on `SUPER+R` (hjkl/arrows, shift for big steps,
  Return/Esc exits) plus `-`/`=` quick-resize outside the submap
- Tiled fullscreen `SUPER+CTRL+F`, pop-out float&pin `SUPER+O`
- i3-style workspaces: numbers 1–0 (+shift moves), `SUPER+Z` back-and-forth,
  monitor-scoped next/prev via custom script, mouse-wheel scrolling

### 1.2 Inlined Omarchy defaults (v3 pattern)

`omarchy-defaults.conf` is a customized **copy** of upstream defaults
(autostart, envs, look-and-feel, window/app rules) so they can be edited
directly without fighting package updates. `hyprland.conf` sources it plus
per-topic files (`monitors/input/bindings/envs/looknfeel/autostart/plugins`).
This pattern is **obsolete in quattro** — see §2.

### 1.3 Custom Waybar with hand-rolled indicators

`dotfiles/waybar` replaces the stock bar: workspace scroll spacers, submap
indicator, and custom indicators (nightlight, tailscale toggle, touchpad,
notification silencing, idle, screen recording, voxtype dictation), tray
drawer group, volume scroll wired to swayosd.

### 1.4 Custom commands (`dotfiles/bin/.local/bin`)

- `omarchy-waybar-workspace-scroll <next|prev> [cursor|focused]` —
  monitor-scoped workspace cycling (used by keybindings *and* waybar scroll)
- `omarchy-workspace-select` — named-workspace selector fed into walker dmenu
- `omarchy-nightlight-toggle` — flips hyprsunset between 4000K/6000K and pokes
  the waybar indicator

### 1.5 Aether theme (discarded in the quattro migration)

Custom dark palette (background `#07070B`, foreground `#f0dbcf`,
accent-ish `color4 #9a9dbc`), sharp corners everywhere (`border-radius: 0`),
dark gradient active-border in Hyprland, matching configs for alacritty,
kitty, ghostty, btop, chromium, mako, walker, wofi, waybar, swayosd, vscode,
neovim, warp. Ships one wallpaper. Fonts: Intel One Mono (AUR, installed by
`setup-fonts.sh`). `~/.config/hypr/shaders` was managed outside stow via
absolute symlinks to `/usr/share/aether/shaders/`. **The whole theme was
removed on the `quatro` branch; stock themes are used now.**

### 1.6 Session, auth & shell stack

- uwsm-managed session; `uwsm/default` exports `TERMINAL`/`EDITOR`
- fish shell via the `omarchy-fish` AUR package (bash auto-launch approach),
  emacsclient as editor, custom starship prompt
- GnuPG as SSH agent (`SSH_AUTH_SOCK` → gpg-agent socket, TTL caching in
  `gpg-agent.conf`), `pass` for secrets
- Locking through `omarchy-system-lock` (also locks 1Password); idle chain:
  kbd-backlight off (14 min) → screensaver (15 min) → lock (16 min) → dpms off
  (16.5 min) in `hypridle.conf`; `hyprlock.conf` pulls theme colors
- Extras: universal copy/paste (`Insert`-key forwarding), Apple display
  brightness (DDC), monitor-scale cycling, cursor zoom, per-terminal
  scroll_touchpad rules, voxtype dictation binding

### 1.7 Package inventory

| Package | Contents | quattro impact |
| ------- | -------- | -------------- |
| `alacritty` | minor overrides | none expected |
| `bin` | 3 custom commands (§1.4) | nightlight obsolete; other two need IPC port |
| `fish` | config on top of omarchy-fish | low; verify env bootstrap |
| `git` | aliases/workflow | none |
| `gnupg` | gpg-agent as ssh-agent | low; watch `/etc/gnupg` ownership changes |
| `hypr` | everything in §1.1–1.2 | **major rewrite** |
| `mise` | dev toolchain | none expected |
| `omarchy` | Aether theme, branding, hook samples, menu extension? | theme conversion needed |
| `opencode` | minimal json | none expected |
| `ssh` | client config | none |
| `starship` | prompt | none expected |
| `uwsm` | env exports | move to `env.d/` |
| `waybar` | §1.3 | **obsolete — replaced by shell.json/plugins** |

---

## 2. What changes in quattro (summary)

Full analysis lives in git history / the plan discussion; condensed:

| Area | v3 | quattro | Consequence |
| ---- | -- | ------- | ----------- |
| Hyprland config | `.conf` sources; defaults inlined/copied into repo | Lua entry point `~/.config/hypr/hyprland.lua` loads package-owned defaults, then small user override files (`bindings/input/looknfeel/monitors/autostart.lua`); helpers `o.bind`, `hl.config`, `hl.unbind` | Rewrite `dotfiles/hypr`; stop shipping defaults |
| Bar / launcher / notifications / OSD | waybar + walker + mako + swayosd | Single Quickshell shell (`omarchy-shell`); bar layout in `~/.config/omarchy/shell.json`; plugins for menus, notifications, OSD, clipboard, lock | Delete `waybar` pkg; configure `shell.json` |
| Retired packages | — | waybar, walker(+elephant), mako, swayosd, hypridle, hyprlock, playerctl, polkit-gnome, swaybg … removed by `omarchy-upgrade-to-quattro` | Our configs/scripts depending on them die |
| Idle & lock | `hypridle.conf` + `hyprlock.conf` | `shell.json` → `idle.screensaver` / `idle.lock` (seconds); shell lock plugin; `omarchy-system-lock` still exists (keeps 1Password locking) | Port timings; kbd-backlight listener needs alternative |
| Themes | full file tree per theme, `current/` under `~/.config/omarchy` | `colors.toml` + `default/themed/*.tpl` rendered into `~/.local/state/omarchy/current/`; user themes overlay at `~/.config/omarchy/themes/<name>` | Convert Aether to `colors.toml`(+overrides); drop dead files |
| uwsm | `uwsm/default` + `uwsm/env` in `~/.config` | Package-owned; user overrides in `~/.config/uwsm/env.d/` | Move TERMINAL/EDITOR exports |
| CLI | flat `omarchy-*` binaries | Same binaries + `omarchy <group> <verb>` router | Cosmetic |
| Upgrade | — | One-way `omarchy-upgrade-to-quattro` (edge channel while alpha; snapshots first; writes Lua entry points; backs up legacy UI dirs to `*.omarchy-upgrade-to-quattro.<ts>.bak`) | See runbook §4.8 |

Built-ins that replace our customs: Night light, DnD, Stay awake, Dictation,
Screen recording indicators; `omarchy.tailscale` panel;
`omarchy-toggle-nightlight`; menu doubles as dmenu (`omarchy-menu-select`).

---

## 3. hy3 on quattro — approach

Chosen path: **keep hy3**. Feasibility confirmed: current hy3 master exposes
Lua dispatcher factories under `hl.plugin.hy3` and tags releases per Hyprland
version (`hl{version}`); `hyprpm` builds against the installed Hyprland.

Install (unchanged from v3): base-devel/git/cmake/pkgconf/cpio +
`hyprpm add https://github.com/outfoxxed/hy3` + `exec-once = hyprpm reload -n`.

Binding translation map (old → new):

```lua
local hy3 = hl.plugin.hy3
-- hy3:movefocus l            → hy3.move_focus("l")
-- hy3:movewindow l           → hy3.move_window("l", { once = true })
-- hy3:makegroup opposite     → hy3.make_group("opposite")
-- hy3:makegroup tab toggle   → hy3.make_group("tab", { toggle = true })
-- hy3:changegroup toggletab  → hy3.change_group("toggletab")
-- hy3:changefocus raise      → hy3.change_focus("raise")
-- hy3:focustab r wrap        → hy3.focus_tab({ direction = "r", wrap = true })
```

Open questions:

- [V] Which Hyprland build does the `[omarchy]` quattro repo ship (tagged vs
  git)? hyprpm resolves automatically for tagged builds; for `-git` builds it
  picks latest hy3 commit.
- [V] Plugin *config block* syntax under the Lua parser (tab colors/height
  styling from old `plugins.conf`). If unresolved: ship defaults, restyle later.
- Fallback: `looknfeel.lua` keeps a `USE_HY3` flag switching
  `general.layout` between `"hy3"` and `"dwindle"`; if the plugin fails to
  load, set the flag false before reloading (recovery notes in §4.9).

---

## 4. Migration tracker

### 4.0 Repo groundwork

- [x] Analyze v3 ↔ quattro deltas, decide approach (hy3 attempt, minimal port)
- [x] Create `quatro` branch so the live v3 machine keeps sourcing
      `mark/oma-dots` until cutover
- [x] Write this tracker

### 4.1 Hyprland config rewrite (`dotfiles/hypr`)

New quattro-style files (all minimal unless marked otherwise):

- [x] `hyprland.lua` — entry point requiring defaults + user modules
- [x] `bindings.lua` — core i3 set via `hl.plugin.hy3` (focus/move HJKL +
      arrows, close, fullscreen, tab groups, focus parent/child, workspaces
      1–0/Z) with `hl.unbind` on clashing defaults
- [x] `input.lua` — `kb_variant altgr-intl`, `caps:ctrl_modifier`,
      repeat 40/600 (touchpad `scroll_factor 0.4` and per-terminal
      scroll_touchpad rules are already quattro defaults — no override needed)
- [x] `looknfeel.lua` — gaps 0 / border 0 / dim_inactive 0.1,
      workspace_back_and_forth, guarded `layout = "hy3"` (dwindle fallback)
- [x] `monitors.lua` — `preferred,auto,1.25` + GDK_SCALE=2
- [x] `autostart.lua` — `hyprpm reload -n`
- [x] Emacs fully-opaque window rule carried into `hyprland.lua`
- [x] Keep `hyprsunset.conf` (identity profile) — unchanged in quattro
- [x] Keep `xdph.conf` — unchanged in quattro
- [x] Keep `setup-fonts.sh` (Intel One Mono)

Deletions at cutover — **done** (legacy files removed from the `quatro`
branch; the v3 layout lives on `mark/oma-dots`):

- [x] `hyprland.conf` (entry point replaced by `hyprland.lua`)
- [x] `omarchy-defaults.conf` (inlined-defaults pattern obsolete)
- [x] `plugins.conf` (hy3 tab styling → §3 open question)
- [x] `hypridle.conf` (timings → `shell.json`)
- [x] `hyprlock.conf` (lock UI now a shell plugin)
- [x] `envs.conf` (`SSH_AUTH_SOCK` → `uwsm/env.d/50-user.conf`)
- [x] per-topic v3 confs: `bindings/input/looknfeel/monitors/autostart.conf`
- [x] `lock-and-clear-gpg.sh` — verified unreferenced, removed
- [x] `dotfiles/waybar` package removed
- [x] `omarchy-nightlight-toggle` script removed

Deferred bindings/extras — resolved during the parity pass:

- [x] resize submap ported via `hl.dsp.submap` / `hl.define_submap`
- [x] `-`/`=` quick-resize keys — quattro defaults are identical
- [x] universal copy/paste — built-in and terminal-aware (supersedes the
      Insert-forwarding trick)
- [x] Apple display brightness (CTRL+F1/F2, SHIFT+CTRL+F2)
- [x] monitor-scale cycling — built-in on SLASH / ALT+SLASH
- [x] cursor zoom, tmux launcher, app-launcher cluster, notification COMMA
      cluster, share/info/control-panel clusters, media keys, ALT+TAB — all
      covered by quattro defaults

Still open after the parity pass ([V]/[D]):

- [V] hy3 `move_to_workspace` vs built-in `window.move`: we use the built-in
      for cross-workspace moves (matches v3 `movetoworkspace*` exactly);
      confirm behaviour under the hy3 layout at first boot
- [D] mako's "restore last notification" has no equivalent — history panel
      replaces it; revisit if missed
- [V] `SUPER+SPACE` kept as Omarchy menu (v3 had a tiling/floating focus
      toggle there); float toggle is on SUPER+T — revisit if missed

### 4.2 Bar & indicators (`waybar` → `shell.json`)

- [x] Add `dotfiles/omarchy/.config/omarchy/shell.json`: bar layout
      (left: menu + workspaces; center: indicators + clock; right: tray,
      bluetooth, tailscale, network, audio, power) + `idle.screensaver 900` /
      `idle.lock 960`
- [x] `dotfiles/waybar` package — removed (built-in equivalents:
      NightLight, Dnd, StayAwake, ScreenRecording, Dictation, tailscale panel)
- [V] Touchpad indicator/toggle — no known built-in widget; find equivalent
      or accept loss initially
- [V] Workspaces widget scroll behavior vs our monitor-scoped script
- [D] Voxtype click actions (model/config pickers) if missing in quattro

### 4.3 Theme (Aether)

**Discarded by decision** — the custom Aether theme (and its wallpaper) was
removed from the repo; stock quattro themes are used instead.

- [x] Remove `themes/aether/` entirely (incl. `colors.toml`, backgrounds,
      all hand-written app theme files)
- [x] Drop dead-in-quattro files with it: `mako.ini`, `walker.css`,
      `wofi.css`, `waybar.css`, `swayosd.css`, `hyprlock.conf`, `warp.yaml`
- [x] `deploy.sh` no longer activates Aether; pick a stock theme after
      upgrade (`omarchy theme set <name>`)
- [x] Branding (`about.txt`, `screensaver.txt`) kept

### 4.4 Scripts (`dotfiles/bin`)

- [x] `omarchy-nightlight-toggle` — removed; superseded by
      `omarchy-toggle-nightlight`
- [D] `omarchy-workspace-select` — superseded by the `mark.workspace-switcher`
      plugin (see top TODO + [`plugins/mark.workspace-switcher/PLAN.md`](plugins/mark.workspace-switcher/PLAN.md));
      script is deleted once the plugin's cycling and selector are verified
- [D] `omarchy-waybar-workspace-scroll` — will retire when the plugin takes
      over SUPER+N/P cycling

### 4.5 Idle / lock / security chain

- [ ] Port timings to `shell.json` (screensaver 900 s, lock 960 s)
- [V] Keyboard-backlight-off-on-idle listener (was hypridle) — find hook or
      accept loss
- [x] 1Password locking — preserved via `omarchy-system-lock`
- [ ] Verify suspend path: `before_sleep_cmd`/`after_sleep_cmd` behaviour
      (was `OMARCHY_LOCK_ONLY=true omarchy-system-lock` + wake script)
- [x] `SSH_AUTH_SOCK` → added `dotfiles/uwsm/.config/uwsm/env.d/50-user.conf`
      (also carries TERMINAL/EDITOR from the legacy `uwsm/default`; old file
      stays until cutover)

### 4.6 Other packages (verify-only)

- [V] fish + omarchy-fish against quattro bash/env bootstrap
- [V] starship prompt intact
- [V] gpg-agent SSH (TTLs) — quattro touches `/etc/gnupg/dirmngr.conf`; ours
      is `~/.gnupg/gpg-agent.conf`, should win
- [V] alacritty/mise/opencode/ssh/starship configs load cleanly
- [ ] Doom Emacs stays disabled (separate repo) — no action

### 4.7 Deploy tooling & docs

- [x] `deploy.sh`: version guard via `/usr/share/omarchy/version` — v4 uses
      `omarchy-install-service-tailscale` and skips the v3-only
      `omarchy-setup-fish`; hy3/hyprpm block kept (still required)
- [x] `scripts/stow.sh` unchanged (adopt flow is exactly what post-upgrade
      restow needs)
- [x] Update root `README.md` + `dotfiles/hypr/README.md` to quattro reality
- [ ] Add cutover section to `deploy.sh` docs (unstow legacy → upgrade → restow)

### 4.8 Machine go-live runbook (when ready)

1. Push `quatro` branch; pull it into the live clone (`~/projects/omarchy-config`)
2. Snapshot: `omarchy-snapshot create` (snapper) + commit any live drift
3. Unstow retiring/legacy packages: `waybar`, `uwsm` (old files), `hypr`
   (legacy conf tree)
4. Run `omarchy-upgrade-to-quattro` (alpha ⇒ edge/dev channel packages)
   — one-way; it writes fresh `~/.config/hypr/*.lua` entry points (our stowed
   copies are backed up as `.bak`), retires packages, migrates theme state
5. Reboot into Quickshell session
6. Re-run `deploy.sh` (stow `--adopt` flow restores our overrides over the
   freshly written defaults)
7. Work through §4.9, then close out [D]/[O] leftovers

### 4.9 Post-upgrade validation checklist

- [ ] `hyprctl reload && hyprctl configerrors` clean
- [ ] hy3 loaded (`hyprpm list`), tiling behaves (focus/tab/group keys);
      else flip `USE_HY3=false` fallback and continue
- [ ] `omarchy menu keybindings --print` — diff against old `bindings.conf`;
      port missed essentials
- [ ] Bar layout matches §4.2; indicators/tailscale panel present
- [ ] Notifications + OSD appear (shell-owned now)
- [ ] Aether theme active (`omarchy theme set Aether`), terminals/btop/browser
      retinted, GTK corners/accent sane
- [ ] Screensaver @15 min, lock @16 min, 1Password locks on lock
- [ ] Suspend/resume locks correctly
- [ ] Monitor scale 1.25 + `GDK_SCALE=2` rendering not blurry ([V] where
      GDK_SCALE belongs now)
- [ ] `ssh-add -l` lists keys via gpg-agent; pass works
- [ ] fish login shell + starship prompt fine
- [ ] Night light toggles (built-in command)
- [ ] mise tools resolve in fresh shells
