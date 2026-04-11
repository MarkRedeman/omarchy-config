# Hyprland

Hyprland window manager configuration with hy3 plugin for i3-style tiling.

## Target

`~/.config/hypr/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles hypr
```

## Key Files

| File | Description |
|---|---|
| `hyprland.conf` | Main entry point, sources all other configs |
| `omarchy-defaults.conf` | Inlined Omarchy upstream defaults (customizable) |
| `bindings.conf` | Custom i3-style keybindings using hy3 |
| `looknfeel.conf` | Appearance (gaps, borders, opacity) |
| `input.conf` | Keyboard layout, repeat rate, touchpad |
| `monitors.conf` | Monitor resolution and scaling |
| `autostart.conf` | Extra autostart processes |
| `envs.conf` | Extra environment variables |
| `hypridle.conf` | Idle timeout and lock screen behavior |
| `hyprlock.conf` | Lock screen appearance |
| `hyprsunset.conf` | Night light / color temperature |
| `xdph.conf` | XDG Desktop Portal configuration |
| `setup-fonts.sh` | Intel One Mono font installer |

## Dependencies

- [Hyprland](https://hyprland.org/)
- [hy3 plugin](https://github.com/outfoxxed/hy3) for i3/sway-like tiling
- [Omarchy](https://omarchy.dev/) utilities (omarchy-launch-walker, omarchy-lock-screen, etc.)
