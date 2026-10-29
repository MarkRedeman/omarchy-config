#!/usr/bin/env bash
set -euo pipefail

echo "Deploying omarchy configuration with hy3 and GNU Stow..."

# Prompt for sudo once upfront so subsequent commands don't re-ask
sudo -v

# Define paths
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="$REPO_DIR/dotfiles"

# Detect Omarchy major version (quattro ships /usr/share/omarchy/version as 4.x)
if [[ -r /usr/share/omarchy/version ]]; then
    OMARCHY_MAJOR="$(cut -d. -f1 < /usr/share/omarchy/version)"
else
    OMARCHY_MAJOR="3"
fi
echo "Detected Omarchy major version: $OMARCHY_MAJOR"

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

# Install hy3 plugin via hyprpm.
# HY3_REV is pinned because hy3's manifest has no commit pin for the installed
# Hyprland release yet: unpinned builds use master, which targets Hyprland
# git-master headers and fails to compile (see https://github.com/outfoxxed/hy3/issues/324).
# Bump/remove once upstream pins or tags a hy3 for the running Hyprland version.
HY3_REV="0f32517"
echo "Setting up hy3 plugin..."
if command -v hyprpm &> /dev/null; then
    # Best-effort refresh. A failing build here (typically an unpinned master
    # that does not match the installed headers) is redone at HY3_REV below.
    hyprpm update || true
    if ! hyprpm add "https://github.com/outfoxxed/hy3" "$HY3_REV"; then
        # Repository already present (wrong rev, or left in a failed state):
        # reinstall at the pinned rev so the build is reproducible.
        hyprpm remove hy3
        hyprpm add "https://github.com/outfoxxed/hy3" "$HY3_REV"
    fi
    hyprpm enable hy3
    # Register the (re)built plugin with the Lua config. Until hyprpm has
    # written its load state after the enable, hl.plugin.hy3 is nil and every
    # hy3 binding fails to parse. reload is best-effort so an over-SSH run
    # still completes.
    hyprpm update
    hyprpm reload -n || true
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
# Restore the repo versions of any adopted files, but keep uncommitted pulled
# changes to shell.json: it is not stowed.
git -C "$REPO_DIR" checkout -- "$DOTFILES_DIR" \
    ":(exclude)dotfiles/omarchy/.config/omarchy/shell.json"

# shell.json is tracked but intentionally not stowed: omarchy-shell rewrites it
# with atomic writes, which replaces a symlink with a regular file. Seed it on
# a fresh install. Afterwards the live file is authoritative; capture changes
# with scripts/shell-config.sh pull.
SHELL_CONFIG="$HOME/.config/omarchy/shell.json"
if [[ -L "$SHELL_CONFIG" ]]; then
    echo "Replacing stowed shell.json symlink with a regular file..."
    resolved="$(readlink -f "$SHELL_CONFIG" || true)"
    if [[ -n "$resolved" && -f "$resolved" ]]; then
        install -m 600 "$resolved" "$SHELL_CONFIG.tmp"
        mv -f "$SHELL_CONFIG.tmp" "$SHELL_CONFIG"
    else
        rm -f "$SHELL_CONFIG"
    fi
fi
if [[ ! -e "$SHELL_CONFIG" ]]; then
    echo "Seeding Omarchy shell config..."
    mkdir -p "$(dirname "$SHELL_CONFIG")"
    install -m 600 "$DOTFILES_DIR/omarchy/.config/omarchy/shell.json" "$SHELL_CONFIG"
fi

# Appearance state: gaps and corner radius live under ~/.local/state, so stow
# cannot manage them. looknfeel.lua reads this file on every config load and
# falls back to i3-style zeros when it is missing; seed it on a fresh machine
# so a deploy reproduces this setup instead of silently losing it.
APPEARANCE_STATE="$HOME/.local/state/omarchy/appearance.json"
if [[ ! -f "$APPEARANCE_STATE" ]]; then
    echo "Seeding appearance state (gap 4, rounding 8)..."
    mkdir -p "$(dirname "$APPEARANCE_STATE")"
    cp "$REPO_DIR/scripts/appearance.default.json" "$APPEARANCE_STATE"

    # Fresh machine: start from the stock theme these dotfiles are tuned for
    # (ethereal). Only on first deploy, so a later theme choice is not reset.
    # Best effort: a deploy may run outside a graphical session.
    if command -v omarchy-theme-set >/dev/null 2>&1; then
        echo "Applying default theme: ethereal"
        omarchy-theme-set ethereal || echo "Warning: could not apply theme ethereal; run 'omarchy-theme-set ethereal' after logging in."
    fi
fi

# Install fish shell with omarchy-fish (provides functions, fzf.fish, starship init)
# Uses bash auto-launch approach instead of chsh to avoid black screen on boot
# (see https://github.com/basecamp/omarchy/issues/2487)
echo "Setting up fish shell..."
omarchy-pkg-add fish fzf fd bat eza zoxide starship
omarchy-pkg-aur-add omarchy-fish
if [[ "$OMARCHY_MAJOR" == "3" ]]; then
    omarchy-setup-fish
else
    echo "Skipping omarchy-setup-fish (quattro has no setup command; see QUATRO-MIGRATION.md §4.6)"
fi

# Install tailscale VPN
echo "Installing Tailscale..."
if [[ "$OMARCHY_MAJOR" == "3" ]]; then
    omarchy-install-tailscale
else
    omarchy-install-service-tailscale
fi

# Install pass (password store): GPG key import and store clone are manual
# See pass.md for setup instructions
echo "Installing pass..."
omarchy-pkg-add pass

# Install OpenConnect for corporate VPN (GlobalProtect protocol)
# See proxy.md for setup and usage instructions
echo "Installing OpenConnect..."
omarchy-pkg-add openconnect

# Install alpaca: local PAC-aware HTTP proxy for corporate proxy routing
# Reads Intel's WPAD/PAC file and routes per-request (corporate → proxy, else → DIRECT)
# Auto-falls back to DIRECT when proxy is unreachable (off VPN)
echo "Installing alpaca proxy..."
omarchy-pkg-aur-add alpaca-proxy

# Enable and start alpaca systemd user service
# Requires the unit file stowed from dotfiles/systemd/
echo "Enabling alpaca systemd user service..."
mkdir -p "$HOME/.config/alpaca"
systemctl --user daemon-reload
systemctl --user enable --now alpaca.service

# Enable the PAC refresh timer (re-fetches wpad.intel.com while on VPN)
echo "Enabling alpaca PAC refresh timer..."
systemctl --user enable --now alpaca-pac-refresh.timer

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
