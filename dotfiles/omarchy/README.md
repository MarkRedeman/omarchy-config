# Omarchy

Omarchy desktop framework configuration: branding, shell/bar settings, and hooks.

## Target

`~/.config/omarchy/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles omarchy
```

`shell.json` is tracked here but excluded by `.stow-local-ignore`. Stow it only
for the static files (`branding/`, `hooks/`); seed the live shell config
separately:

```bash
install -Dm600 \
  dotfiles/omarchy/.config/omarchy/shell.json \
  "$HOME/.config/omarchy/shell.json"
```

Only do that on a fresh install. Afterwards the live file is authoritative.

## Structure

| Directory | Description |
|---|---|
| `.stow-local-ignore` | Excludes `shell.json` and the package README from stow |
| `branding/` | Custom about text and screensaver text |
| `hooks/` | Omarchy lifecycle hooks (sample files) |
| `shell.json` | Quickshell bar layout and idle timings (tracked, not stowed) |

## Notes

- The custom Aether theme was discarded; stock quattro themes are used
  (`omarchy theme set <name>`).
- `~/.local/state/omarchy/current/` holds the generated theme state on
  quattro and is not part of this stow package.
- `omarchy-shell` rewrites `shell.json` with atomic writes, which replaces a
  stow symlink with a regular file. Sync it with `scripts/shell-config.sh`
  (`diff`, `pull`, `push`) instead of re-stowing.
