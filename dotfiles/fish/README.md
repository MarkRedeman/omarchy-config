# Fish

Personal fish shell configuration, layered on top of
[omarchy-fish](https://github.com/omacom-io/omarchy-fish).

## What omarchy-fish provides

- 40+ convenience functions (`ls`=eza, `cd`=zoxide, `g`=git, fzf search, etc.)
- Starship prompt, zoxide, mise auto-activation
- fzf.fish keybindings (`Ctrl+R` history, `Ctrl+Alt+F` directory, etc.)
- Environment setup (BAT_THEME, FZF_DEFAULT_OPTS, fish_greeting)

## What this config adds

- Emacs-style keybindings (overrides omarchy-fish's vi mode)
- `~/.cargo/bin` in PATH
- Emacs ansi-term support
- `gl` alias for git log graph

## Target

`~/.config/fish/`

## Install

Handled by `scripts/deploy.sh`, which:

1. Installs fish + dependencies (`fzf`, `fd`, `bat`, `eza`, `zoxide`, `starship`)
2. Installs `omarchy-fish` from AUR
3. Runs `omarchy-setup-fish` (auto-launches fish from bash - do NOT use `chsh`)
4. Stows this config to `~/.config/fish/`

Manual install:

```bash
omarchy-pkg-add fish fzf fd bat eza zoxide starship
omarchy-pkg-aur-add omarchy-fish
omarchy-setup-fish
stow --target="$HOME" --dir=dotfiles fish
```

**Important:** Do not use `chsh -s /usr/bin/fish` as it causes a black screen on
boot. The `omarchy-setup-fish` command configures bash to auto-launch fish for
interactive sessions instead.
See [basecamp/omarchy#2487](https://github.com/basecamp/omarchy/issues/2487).
