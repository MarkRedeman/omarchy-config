#!/usr/bin/env bash
set -euo pipefail

echo "Deploying omarchy configuration with hy3 and GNU Stow..."

# Prompt for sudo once upfront so subsequent commands don't re-ask
sudo -v

# Define paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"

# Check if stow is installed, install via omarchy-pkg-add if missing
if ! command -v stow &> /dev/null; then
    echo "Installing GNU Stow..."
    omarchy-pkg-add stow
fi

# Install fonts from repo path (before stow, so fonts are available for configs)
FONT_SCRIPT="$REPO_DIR/dotfiles/hypr/.config/hypr/setup-fonts.sh"
if [[ -f "$FONT_SCRIPT" ]]; then
    chmod +x "$FONT_SCRIPT"
    echo "Running font setup script..."
    "$FONT_SCRIPT"
fi

# Doom Emacs disabled - config lives in separate repo (MarkRedeman/doom-config)
# Uncomment below to re-enable:
# omarchy-pkg-add emacs git ripgrep fd

# Install hy3 build dependencies
echo "Checking for hy3 dependencies..."
omarchy-pkg-add base-devel git cmake pkgconf cpio

# Install hy3 plugin via hyprpm
echo "Setting up hy3 plugin..."
if command -v hyprpm &> /dev/null; then
    hyprpm update
    hyprpm add https://github.com/outfoxxed/hy3 2>/dev/null || true
    hyprpm enable hy3
else
    echo "Error: hyprpm is not available. See https://wiki.hyprland.org/Plugins/Using-Plugins/"
    exit 1
fi

# Stow each dotfile package to ~/.config/
# Each package uses the .config/<app>/ directory structure, so stow --target=$HOME
# correctly deploys to ~/.config/<app>/. No --dotfiles flag needed.
# --adopt moves existing files into the repo so symlinks can be created,
# then git checkout restores our versions (the symlinks point into the repo).
for package in "$DOTFILES_DIR"/*/; do
    package_name=$(basename "$package")
    if [[ -d "$package" ]]; then
        echo "Stowing $package_name..."
        stow --adopt --restow --target="$HOME" --dir="$DOTFILES_DIR" "$package_name"
    fi
done
git -C "$REPO_DIR" checkout -- "$DOTFILES_DIR"

# Activate the Aether theme (populates ~/.config/omarchy/current/ which is
# runtime state managed by omarchy-theme-set, not tracked in the repo)
echo "Activating Aether theme..."
omarchy-theme-set Aether

# Install fish shell with omarchy-fish (provides functions, fzf.fish, starship init)
# Uses bash auto-launch approach instead of chsh to avoid black screen on boot
# (see https://github.com/basecamp/omarchy/issues/2487)
echo "Setting up fish shell..."
omarchy-pkg-add fish fzf fd bat eza zoxide starship
omarchy-pkg-aur-add omarchy-fish
omarchy-setup-fish

# Install tailscale VPN
echo "Installing Tailscale..."
omarchy-install-tailscale

# Install pass (password store): GPG key import and store clone are manual
# See pass.md for setup instructions
echo "Installing pass..."
omarchy-pkg-add pass

# Doom Emacs clone/install/sync disabled: managed separately
# To re-enable, uncomment below and restore DOOM_CONFIG_REPO_SSH/HTTPS variables
#
# echo "Checking for Doom Emacs config..."
# if [[ ! -d "$HOME/.config/doom" ]]; then
#     if ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
#         echo "Cloning Doom Emacs config via SSH..."
#         git clone "$DOOM_CONFIG_REPO_SSH" "$HOME/.config/doom"
#     else
#         echo "SSH keys not available, cloning Doom Emacs config via HTTPS..."
#         echo "(Run 'git remote set-url origin $DOOM_CONFIG_REPO_SSH' later to enable push)"
#         git clone "$DOOM_CONFIG_REPO_HTTPS" "$HOME/.config/doom"
#     fi
# else
#     echo "Doom Emacs config already present at ~/.config/doom"
# fi
#
# echo "Checking for Doom Emacs framework..."
# if [[ ! -d "$HOME/.config/emacs" ]]; then
#     echo "Installing Doom Emacs framework..."
#     git clone --depth 1 https://github.com/doomemacs/doomemacs "$HOME/.config/emacs"
#     "$HOME/.config/emacs/bin/doom" install
# else
#     echo "Doom Emacs framework already installed."
# fi
#
# echo "Syncing Doom Emacs configuration..."
# "$HOME/.config/emacs/bin/doom" sync

echo "Deployment complete! Please restart Hyprland to apply changes."
