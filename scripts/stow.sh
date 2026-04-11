#!/usr/bin/env bash
set -euo pipefail

# Re-stow all dotfile packages to $HOME.
# Use this after pulling changes or editing config files in the repo.
# For first-time setup (installing packages, plugins, etc.), use deploy.sh instead.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"

for package in "$DOTFILES_DIR"/*/; do
    package_name=$(basename "$package")
    if [[ -d "$package" ]]; then
        echo "Stowing $package_name..."
        stow --adopt --restow --target="$HOME" --dir="$DOTFILES_DIR" "$package_name"
    fi
done

# --adopt may have pulled live files into the repo; restore our versions
git -C "$REPO_DIR" checkout -- "$DOTFILES_DIR"

echo "Done. Run 'hyprctl reload' to apply Hyprland changes."
