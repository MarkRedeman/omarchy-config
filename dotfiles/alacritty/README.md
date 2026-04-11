# Alacritty

Alacritty terminal emulator configuration (TOML format).

## Target

`~/.config/alacritty/alacritty.toml`

## Install

```bash
stow --target="$HOME" --dir=dotfiles alacritty
```

## Dependencies

- [Alacritty](https://alacritty.org/) (0.13+, ships with Omarchy)
- Intel One Mono font (installed via `hypr/setup-fonts.sh`)

## Notes

Colors are provided by the Omarchy theme via import. The shell is not
hardcoded - Alacritty uses the login shell set by `chsh`.
