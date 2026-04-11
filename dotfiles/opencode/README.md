# OpenCode

[OpenCode](https://opencode.ai/) AI coding tool configuration.

## Target

`~/.config/opencode/`

## Install

```bash
stow --target="$HOME" --dir=dotfiles opencode
```

## Key Files

| File | Description |
|---|---|
| `opencode.json` | Main configuration (model, providers, keymaps) |
| `tui.json` | TUI interface settings |

## Notes

The `node_modules/`, `package.json`, `bun.lock`, and lock files at the
package root are for OpenCode plugins and are excluded from stow via
`.stow-local-ignore`. They are not deployed to `~/.config/opencode/`.
