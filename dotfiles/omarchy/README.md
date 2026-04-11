# Omarchy

Omarchy desktop framework configuration: branding, custom themes, and hooks.

## Target

`~/.config/omarchy/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles omarchy
omarchy-theme-set Aether
```

## Structure

| Directory | Description |
|---|---|
| `branding/` | Custom about text and screensaver text |
| `hooks/` | Omarchy lifecycle hooks (sample files) |
| `themes/aether/` | Custom Aether theme with all component styles |

## Dependencies

- [Omarchy](https://omarchy.org/) installed at `~/.local/share/omarchy/`

## Notes

The `current/` directory (theme.name, active theme files, wallpaper) is **not**
in this stow package. It is runtime state managed by `omarchy-theme-set` and
would conflict with stow symlinks. Run `omarchy-theme-set Aether` after stowing
to activate the theme.
