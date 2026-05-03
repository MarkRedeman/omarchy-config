# Keybinding Visualizer

Utilities for exporting Hyprland keybindings and serving a local UI to inspect them.

## Requirements

- `uv`
- `python3`
- `hyprctl` (optional, used for runtime export)

## Commands

Run all commands from the repository root.

### Export keybindings JSON

```bash
uv run --project scripts/keybinding keybinding export
```

This generates:

- `scripts/keybinding/keybindings.json`

Export behavior:

1. Uses `hyprctl binds -j` when Hyprland is running.
2. Falls back to parsing `dotfiles/hypr/.config/hypr/bindings.conf`.

### Serve the visualizer

```bash
uv run --project scripts/keybinding keybinding serve --port 8000
```

This command automatically regenerates `keybindings.json` before serving.

Open:

- `http://localhost:8000`

### Export + serve (dev mode)

```bash
uv run --project scripts/keybinding keybinding dev --port 8000
```

This also regenerates `keybindings.json` first, then starts the server.
