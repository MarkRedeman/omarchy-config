#!/usr/bin/env bash
# Refresh alpaca's local PAC file from Intel's WPAD server.
#
# Only fetches while the VPN tunnel is up, because wpad.intel.com only
# resolves through the corporate DNS pushed by the VPN. When off VPN it
# silently exits 0 and keeps the last-good PAC file.
#
# The fetched PAC defaults every request to "PROXY proxy-dmz.intel.com:912"
# with no DIRECT fallback. We append "; DIRECT" to that default rule so that
# when the corporate proxy is unreachable (e.g. off VPN) alpaca falls back to
# DIRECT after temporarily blocking the proxy, instead of returning 502 for
# everything.
#
# Only restarts alpaca when the PAC content actually changed.

set -uo pipefail

PAC_DIR="$HOME/.config/alpaca"
PAC_FILE="$PAC_DIR/wpad.dat"
URL="http://wpad.intel.com/wpad.dat"
TMP="$(mktemp)"

trap 'rm -f "$TMP"' EXIT

# VPN must be active (openconnect / gp-saml-gui process running)
if ! pgrep -x openconnect >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$PAC_DIR"

if ! curl -fsS --noproxy '*' --connect-timeout 5 --max-time 20 -o "$TMP" "$URL" 2>/dev/null; then
    exit 0
fi

# Append "; DIRECT" to the default fallback rule (a line starting with "return").
sed -i 's/^return "PROXY proxy-dmz.intel.com:912";$/return "PROXY proxy-dmz.intel.com:912; DIRECT";/' "$TMP"

if [[ ! -f "$PAC_FILE" ]] || ! cmp -s "$TMP" "$PAC_FILE"; then
    install -m 600 "$TMP" "$PAC_FILE"
    systemctl --user restart alpaca.service 2>/dev/null || true
fi
