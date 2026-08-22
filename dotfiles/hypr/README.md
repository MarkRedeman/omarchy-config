# Hyprland

Hyprland window manager configuration with hy3 plugin for i3-style tiling.

## Target

`~/.config/hypr/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles hypr
```

## Two layouts in this package (transition period)

This package carries **both** the legacy Omarchy v3 `.conf` tree and the new
Omarchy quattro (v4) Lua overrides:

- **v3** loads `hyprland.conf` → sources `omarchy-defaults.conf` (inlined
  upstream defaults) plus `bindings/input/looknfeel/monitors/envs/autostart/plugins.conf`
- **quattro** loads `hyprland.lua` → requires package-owned defaults, then
  the `*.lua` override modules below. The legacy `.conf` files are ignored by
  quattro and will be deleted at cutover.

See `/QUATRO-MIGRATION.md` for status and the cutover plan.

### quattro key files

| File | Description |
|---|---|
| `hyprland.lua` | Entry point: loads Omarchy defaults, then personal modules |
| `bindings.lua` | i3-style keybindings via `hl.plugin.hy3` |
| `input.lua` | Keyboard layout/variant, repeat rate |
| `looknfeel.lua` | Gaps, borders, dimming; guarded hy3/dwindle layout flag |
| `monitors.lua` | Monitor scaling, GDK_SCALE |
| `autostart.lua` | hyprpm plugin loading |

### Legacy v3 key files (removed at cutover)

`hyprland.conf`, `omarchy-defaults.conf`, `bindings.conf`, `looknfeel.conf`,
`input.conf`, `monitors.conf`, `autostart.conf`, `envs.conf`,
`hypridle.conf`, `hyprlock.conf`, `plugins.conf`

### Shared files

| File | Description |
|---|---|
| `hyprsunset.conf` | Night light / color temperature (identity profile) |
| `xdph.conf` | XDG Desktop Portal screen sharing |
| `setup-fonts.sh` | Intel One Mono font installer |

## Dependencies

- [Hyprland](https://hyprland.org/)
- [hy3 plugin](https://github.com/outfoxxed/hy3) for i3/sway-like tiling
  (installed via `hyprpm`; on quattro bindings use the `hl.plugin.hy3` Lua API)
- [Omarchy](https://omarchy.dev/) utilities
