# Omarchy Config

Personal [Omarchy](https://omarchy.org) (Hyprland) dotfiles with [hy3](https://github.com/outfoxxed/hy3) for i3-style tiling, managed with [GNU Stow](https://www.gnu.org/software/stow/).

> **quattro (v4) migration** — see [QUATRO-MIGRATION.md](QUATRO-MIGRATION.md).
> This branch (`quatro`) targets Omarchy quattro only: Hyprland Lua config,
> Quickshell shell, no custom theme. The legacy v3 layout lives on the
> `mark/oma-dots` branch.
>
> Reproducing theme, gaps, corner radius, opacity, and the bar widget:
> see [handoff-looknfeel.md](handoff-looknfeel.md).

## Install

Assumes a working [Omarchy](https://omarchy.org) installation.

### 1. Clone

```bash
git clone git@github.com:MarkRedeman/omarchy-config.git ~/projects/omarchy-config
```

### 2. Install GNU Stow

```bash
omarchy-pkg-add stow
```

### 3. Deploy everything

```bash
~/projects/omarchy-config/scripts/deploy.sh
```

This will:
- Install hy3 plugin via hyprpm (if not present)
- Stow all dotfile packages to `~/.config/`
- Clone [Doom Emacs config](https://github.com/MarkRedeman/doom-config) to `~/.config/doom/`
- Install the Doom Emacs framework to `~/.config/emacs/` (if not present)
- Run `doom sync`
- Install fonts

### 4. Restart Hyprland

Log out and back in, or run `hyprctl reload` for config-only changes.

## Stow a single package

Each package under `dotfiles/` uses the `.config/<app>/` directory structure so plain `stow --target=$HOME` works:

```bash
stow --restow --target=$HOME --dir=dotfiles hypr
```

See the `README.md` inside each package for details.

## Omarchy shell config

`~/.config/omarchy/shell.json` is tracked at
`dotfiles/omarchy/.config/omarchy/shell.json` but deliberately **not** stowed.
`omarchy-shell` rewrites it with atomic writes (temp file + rename), which
replaces a stow symlink with a regular file. `scripts/deploy.sh` seeds it on a
fresh install only if it is missing.

Capture or apply it explicitly:

```bash
./scripts/shell-config.sh diff   # compare live and repo
./scripts/shell-config.sh pull   # live -> repo, then commit
./scripts/shell-config.sh push   # repo -> live (backs up the live file)
```

Use `pull` after changing the bar or idle settings with `omarchy bar ...`,
`omarchy plugin ...`, or a bar gesture.

## Hardware Monitor plugin

The `mark.hardware-monitor` bar widget shows CPU, GPU, and NPU utilization,
with a native panel for Panther Lake-specific detail (GPU engines, media
clock, NPU PMT metrics, power domains). It reads telemetry from a local
[TopsWatch](https://github.com/scottmbaker/topswatch) daemon.

Install the daemon once:

```bash
./scripts/install-topswatch.sh
```

Then stow/rescan/enable the plugin as described in
[its README](dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.hardware-monitor/README.md).

## Bar drawer

The right side of the bar uses `mark.bar-drawer` to fold secondary widgets —
webcam, hardware monitor, Bluetooth, Tailscale, audio, and display — behind a
chevron that expands on hover. See
[its README](dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.bar-drawer/README.md).
The webcam entry expects the `io.github.kristoferlund.webcam` plugin
(`omarchy plugin add https://github.com/kristoferlund/omarchy-webcam.git`).

## Updating

Edit files under `dotfiles/`, then re-stow:

```bash
# Re-deploy everything
~/projects/omarchy-config/scripts/deploy.sh

# Or a single package
stow --restow --target=$HOME --dir=~/projects/omarchy-config/dotfiles <package>
```

## Troubleshooting

**Stow conflicts**: If stow reports a conflict, there's an existing (non-symlink) file at the target path. Back it up and remove it, then re-stow.

**hy3 not loading**: Check `hyprpm list`. If hy3 isn't listed, run `hyprpm add https://github.com/outfoxxed/hy3 && hyprpm update`.

**Doom Emacs**: Run `~/.config/emacs/bin/doom doctor` to diagnose issues, or `doom sync` after config changes.
