# Git

Git configuration using the XDG-compliant config path.

## Target

`~/.config/git/config`

## Install

```bash
stow --target="$HOME" --dir=dotfiles git
```

## Notes

This uses `~/.config/git/config` (XDG path) rather than `~/.gitconfig`.
Git reads from this location automatically.
