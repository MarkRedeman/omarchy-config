#!/usr/bin/env bash
# Connect to Intel GlobalProtect VPN via OpenConnect (gp-saml-gui for SAML).
# Mirror of /home/mark/connect-to-vpn.sh - keep both in sync.
#
# Tunnel hardening: --no-dtls forces the TLS data plane (GlobalProtect's
# default is UDP-encapsulated ESP, which fails with "Failed to send ESP
# packet: Network is unreachable" and silently dies under NAT). --force-dpd 30
# keeps dead-peer-detection keepalives flowing so firewalls/NAT don't drop the
# idle tunnel, and --reconnect-timeout 600 lets openconnect recover from short
# outages.
#
# Alpaca (PAC-aware local proxy) runs independently as a systemd user service
# and is NOT managed by this script. Proxy env vars are set globally in fish
# config, so no per-shell setup is needed.
set -euo pipefail

umask 0077

echo "=== VPN Connection Script Started ==="

# Configuration
USERNAME="msredema"
SERVER="vpngp-lx.intel.com"
CERT_FILE="$HOME/.cert/certificate.pem"
KEY_FILE="$HOME/.cert/vpn-priv-key.pem"

# Read the key decryption password from the environment, falling back to a
# prompt (do NOT hardcode it in this repo copy).
PASSWORD="${VPN_KEY_PASSWORD:-$(read -rsp 'VPN key password: ' pwd; echo "$pwd")}"
echo

if [ ! -f "$CERT_FILE" ]; then
    echo "ERROR: Certificate file not found at $CERT_FILE"
    exit 1
fi

if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Private key file not found at $KEY_FILE"
    exit 1
fi

# Stop Tailscale while the VPN is up (avoids routing/DNS conflicts),
# and restore it when the script exits (i.e. VPN disconnected).
TAILSCALE_WAS_UP=0
if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
    TAILSCALE_WAS_UP=1
    echo "Stopping Tailscale..."
    sudo tailscale down
fi

temp=$(mktemp)

cleanup() {
    rm -f "$temp"
    if [ "$TAILSCALE_WAS_UP" = "1" ]; then
        echo "Restarting Tailscale..."
        sudo tailscale up
    fi
}
trap cleanup EXIT

echo "Decrypting private key..."
echo "$PASSWORD" | openssl rsa -in "$KEY_FILE" -passin stdin -out "$temp" >/dev/null 2>&1
chmod 600 "$temp"

echo "Attempting OpenConnect VPN connection..."
sudo env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY -u NO_PROXY -u all_proxy -u http_proxy -u https_proxy -u no_proxy \
    /usr/bin/gp-saml-gui --allow-insecure-crypto --no-verify -g -c "$CERT_FILE" \
    --key "${temp}" -S "$SERVER" -- \
    --no-proxy \
    --servercert pin-sha256:9CHrTL9cusvmFF84plryQTT8LGGBlYf1P/DH09SYfzk= \
    --no-dtls --force-dpd 30 --reconnect-timeout 600 \
    -c "$CERT_FILE" -k "${temp}"

echo "=== VPN Connection Script Completed ==="
