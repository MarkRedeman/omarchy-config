#!/usr/bin/env bash
set -euo pipefail

# Connect to Intel GlobalProtect VPN via OpenConnect.
# Disables Tailscale (IT policy + avoids routing conflicts).
#
# Alpaca (PAC-aware local proxy) runs independently as a systemd user service
# and is NOT managed by this script. Proxy env vars are set globally in fish
# config, so no per-shell setup is needed.
#
# Usage: scripts/vpn-connect.sh <vpn-gateway-hostname>
#
# The SAML authentication flow will open in your browser.
# After connecting, corporate traffic is automatically routed through
# the Intel proxy via alpaca (localhost:3128).

GATEWAY="${1:-}"

if [[ -z "$GATEWAY" ]]; then
    echo "Usage: $0 <vpn-gateway-hostname>"
    echo ""
    echo "Example: $0 vpn.intel.com"
    exit 1
fi

cleanup() {
    echo ""
    echo "VPN disconnected."
    echo "  - Run 'scripts/vpn-disconnect.sh' to restart Tailscale."
}
trap cleanup EXIT

# Stop Tailscale (IT policy + avoids routing conflicts)
if command -v tailscale &> /dev/null; then
    echo "Stopping Tailscale..."
    sudo tailscale down 2>/dev/null || true
fi

# Connect to GlobalProtect VPN (blocks in foreground)
echo ""
echo "Connecting to GlobalProtect VPN at $GATEWAY..."
echo "SAML authentication will open in your browser."
echo ""
sudo openconnect --protocol=gp "$GATEWAY"
