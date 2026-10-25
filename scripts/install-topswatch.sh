#!/usr/bin/env bash
#
# Convenience wrapper for the omarchy-config checkout. The real installer
# lives inside the plugin so a published copy of the plugin stays
# self-contained.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$REPO_DIR/dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.hardware-monitor/install/install-topswatch.sh" "$@"
