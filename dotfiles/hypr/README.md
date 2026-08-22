# Hyprland

Hyprland window manager configuration with hy3 plugin for i3-style tiling,
targeting Omarchy quattro (v4) Lua configuration.

## Target

`~/.config/hypr/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles hypr
```

## Key files

| File | Description |
|---|---|
| `hyprland.lua` | Entry point: loads Omarchy defaults, then personal modules |
| `bindings.lua` | i3-style keybindings via `hl.plugin.hy3` |
| `input.lua` | Keyboard layout/variant, repeat rate |
| `looknfeel.lua` | Gaps, borders, dimming; guarded hy3/dwindle layout flag |
| `monitors.lua` | Monitor scaling, GDK_SCALE |
| `autostart.lua` | hyprpm plugin loading |
| `hyprsunset.conf` | Night light / color temperature (identity profile) |
| `xdph.conf` | XDG Desktop Portal screen sharing |
| `setup-fonts.sh` | Intel One Mono font installer |

## Dependencies

- [Hyprland](https://hyprland.org/) with Lua config support (quattro)
- [hy3 plugin](https://github.com/outfoxxed/hy3) for i3/sway-like tiling
  (installed via `hyprpm`; bindings use the `hl.plugin.hy3` Lua API)
- [Omarchy quattro](https://omarchy.dev/) utilities
