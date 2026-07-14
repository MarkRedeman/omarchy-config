#!/usr/bin/env bash
set -euo pipefail

# Disconnect from Intel GlobalProtect VPN and restart Tailscale.
#
# Alpaca is NOT managed by this script — it runs independently as a
# systemd user service and handles both on-VPN and off-VPN states
# transparently via its PAC auto-fallback to DIRECT.
#
# Usage: scripts/vpn-disconnect.sh

# Kill OpenConnect if running in background
if pgrep -x openconnect &> /dev/null; then
    echo "Stopping OpenConnect..."
    sudo killall openconnect
    sleep 1
else
    echo "OpenConnect is not running."
fi

# Restart Tailscale
if command -v tailscale &> /dev/null; then
    echo "Starting Tailscale..."
    sudo tailscale up
else
    echo "Tailscale not installed, skipping."
fi

echo ""
echo "VPN disconnected. Proxy env vars remain set (alpaca routes everything DIRECT off VPN)."
