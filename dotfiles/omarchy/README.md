# Omarchy

Omarchy desktop framework configuration: branding, shell/bar settings, and hooks.

## Target

`~/.config/omarchy/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles omarchy
```

## Structure

| Directory | Description |
|---|---|
| `branding/` | Custom about text and screensaver text |
| `hooks/` | Omarchy lifecycle hooks (sample files) |
| `shell.json` | Quickshell bar layout and idle timings (quattro) |

## Notes

- The custom Aether theme was discarded; stock quattro themes are used
  (`omarchy theme set <name>`).
- `~/.local/state/omarchy/current/` holds the generated theme state on
  quattro and is not part of this stow package.
