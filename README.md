# Omarchy Config

Personal [Omarchy](https://omarchy.org) (Hyprland) dotfiles with [hy3](https://github.com/outfoxxed/hy3) for i3-style tiling, managed with [GNU Stow](https://www.gnu.org/software/stow/).

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
