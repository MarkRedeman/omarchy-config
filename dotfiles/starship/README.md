# Starship

[Starship](https://starship.rs/) cross-shell prompt configuration.

## Target

`~/.config/starship.toml`

## Install

```bash
stow --target="$HOME" --dir=dotfiles starship
```

## Dependencies

- [Starship](https://starship.rs/)

```bash
# Arch Linux
sudo pacman -S starship
```

Ensure your shell initializes Starship. For Fish, add to `config.fish`:

```fish
starship init fish | source
```
