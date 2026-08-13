# Corporate VPN & Proxy (Intel)

Setup guide for connecting to Intel's corporate network from Omarchy, using OpenConnect (GlobalProtect) and the corporate HTTP proxy.

## Overview

Intel requires a VPN connection (GlobalProtect) plus an HTTP proxy for accessing internal resources. The goal is to keep the system behaving normally when off VPN, and only route corporate traffic through the proxy when connected.

### Architecture

[Alpaca](https://github.com/samuong/alpaca) runs permanently as a systemd user service on `localhost:3128`, evaluating Intel's PAC file to make per-request routing decisions. The PAC is read from a **local file** (`~/.config/alpaca/wpad.dat`) rather than fetched from `http://wpad.intel.com/wpad.dat` on every network change. This makes alpaca immune to `wpad.intel.com` DNS failures while on VPN, and lets it keep routing config available off VPN.

The local copy appends `; DIRECT` to the PAC's default rule. Intel's PAC otherwise defaults everything to `PROXY proxy-dmz.intel.com:912` with no fallback — if the corporate proxy is unreachable (off VPN), alpaca temporarily blocks it and then falls back to DIRECT instead of returning 502 for every request.

```
  Your apps (curl, git, browser, Teams)
          │
     HTTP_PROXY=http://localhost:3128
          │
          ▼
    alpaca (localhost:3128)
      systemd user service (always running)
          │
          ├── reads file://~/.config/alpaca/wpad.dat   (local PAC)
          ├── evaluates PAC rules per request
          │
          ├── [on VPN]  default → proxy-dmz.intel.com:912
          ├── [on VPN]  DIRECT rules → DIRECT
          ├── [off VPN] proxy unreachable → proxy blocked 5 min → DIRECT
          └── PAC refreshed every 15 min via alpaca-pac-refresh.timer (VPN-gated)
```

### Key principle

**Proxy env vars are set globally** in `config.fish`, always pointing to `localhost:3128`. This is safe because alpaca runs permanently and falls back to DIRECT when the corporate proxy is unreachable (off VPN). No per-shell toggling needed — new shells automatically have proxy set, and alpaca handles the routing transparently based on whether the corporate proxy is reachable.

### Proxy details

|               | URL                              |
|---------------|----------------------------------|
| HTTP proxy    | `http://proxy-dmz.intel.com:911` |
| HTTPS proxy   | `http://proxy-dmz.intel.com:912` |
| WPAD/PAC file | `http://wpad.intel.com/wpad.dat` |
| Auth required | No                               |
| Local proxy   | `http://localhost:3128` (alpaca) |

## Setup / Installation

These steps cover both a fresh system and an existing one. On a fresh Omarchy deploy, `scripts/deploy.sh` handles everything automatically (see [Fresh deploy](#fresh-deploy-via-deploysh) below).

### 1. Install alpaca

**Arch Linux (AUR):**

```bash
omarchy-pkg-aur-add alpaca-proxy
# or with your preferred AUR helper:
# yay -S alpaca-proxy
# paru -S alpaca-proxy
```

**Other distros:** alpaca is available on several platforms. See [repology.org/project/alpaca-proxy](https://repology.org/project/alpaca-proxy/versions) or download a binary from [GitHub releases](https://github.com/samuong/alpaca/releases).

### 2. Create the local PAC file and systemd user service

Create `~/.config/alpaca/wpad.dat` from a copy of Intel's PAC (e.g. downloaded
to `~/Downloads/wpad.dat`), appending `; DIRECT` to the default rule so
off-VPN traffic falls back to DIRECT instead of 502ing:

```bash
mkdir -p ~/.config/alpaca
sed 's/^return "PROXY proxy-dmz.intel.com:912";$/return "PROXY proxy-dmz.intel.com:912; DIRECT";/' \
    ~/Downloads/wpad.dat > ~/.config/alpaca/wpad.dat
chmod 600 ~/.config/alpaca/wpad.dat
```

Create `~/.config/systemd/user/alpaca.service`:

```bash
mkdir -p ~/.config/systemd/user
```

```ini
# ~/.config/systemd/user/alpaca.service
[Unit]
Description=Alpaca PAC-aware local HTTP proxy
Documentation=https://github.com/samuong/alpaca
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/alpaca -C file://%h/.config/alpaca/wpad.dat
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

### 3. Enable and start the service

```bash
systemctl --user daemon-reload
systemctl --user enable --now alpaca.service
```

Verify it's running:

```bash
systemctl --user status alpaca.service
```

### 3b. PAC refresh timer (optional but recommended)

The PAC is local, so it won't auto-refresh on its own. A systemd user timer
re-fetches it from `wpad.intel.com` every 15 minutes, but only when the VPN is
active (otherwise `wpad.intel.com` isn't resolvable). It keeps the last-good
PAC when off VPN and restarts alpaca only when the file actually changed.

```bash
# dotfiles/systemd/.config/systemd/user/alpaca-pac-refresh.service
[Unit]
Description=Refresh alpaca PAC file from Intel WPAD
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=%h/.local/bin/alpaca-pac-refresh.sh
```

```bash
# dotfiles/systemd/.config/systemd/user/alpaca-pac-refresh.timer
[Unit]
Description=Refresh alpaca PAC file from Intel WPAD periodically

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now alpaca-pac-refresh.timer
```

The script `dotfiles/bin/.local/bin/alpaca-pac-refresh.sh`:

```bash
#!/usr/bin/env bash
set -uo pipefail

PAC_DIR="$HOME/.config/alpaca"
PAC_FILE="$PAC_DIR/wpad.dat"
URL="http://wpad.intel.com/wpad.dat"
TMP="$(mktemp)"

trap 'rm -f "$TMP"' EXIT

# Only fetch while the VPN tunnel is up (wpad.intel.com resolves via tunnel DNS)
if ! pgrep -x openconnect >/dev/null 2>&1; then
    exit 0
fi

mkdir -p "$PAC_DIR"
if ! curl -fsS --noproxy '*' --connect-timeout 5 --max-time 20 -o "$TMP" "$URL" 2>/dev/null; then
    exit 0
fi

# Append "; DIRECT" to the default fallback rule (see Architecture above)
sed -i 's/^return "PROXY proxy-dmz.intel.com:912";$/return "PROXY proxy-dmz.intel.com:912; DIRECT";/' "$TMP"

if [[ ! -f "$PAC_FILE" ]] || ! cmp -s "$TMP" "$PAC_FILE"; then
    install -m 600 "$TMP" "$PAC_FILE"
    systemctl --user restart alpaca.service 2>/dev/null || true
fi
```

### 5. Set proxy environment variables

Add the following to your shell config. For **fish** (`~/.config/fish/config.fish`):

```fish
set -gx http_proxy http://localhost:3128
set -gx HTTP_PROXY http://localhost:3128
set -gx https_proxy http://localhost:3128
set -gx HTTPS_PROXY http://localhost:3128
set -gx no_proxy localhost,127.0.0.0/8,::1
set -gx NO_PROXY localhost,127.0.0.0/8,::1
```

For **bash/zsh** (`~/.bashrc`, `~/.zshrc`):

```bash
export http_proxy=http://localhost:3128
export HTTP_PROXY=http://localhost:3128
export https_proxy=http://localhost:3128
export HTTPS_PROXY=http://localhost:3128
export no_proxy=localhost,127.0.0.0/8,::1
export NO_PROXY=localhost,127.0.0.0/8,::1
```

Open a new shell or source your config to apply.

### 6. (Optional) Scoped git proxy for Intel repos

If you use Intel's internal GitLab (e.g. `github.intel.com`), scope the proxy in `~/.config/git/config` so alpaca is only used for those URLs:

```gitconfig
[http "https://github.intel.com/"]
    proxy = http://localhost:3128
```

Regular `github.com` clones go direct — no `http_proxy` interference.

### 7. Verify

```bash
# Check alpaca is running
systemctl --user status alpaca.service

# Check proxy env vars are set
echo "$http_proxy"

# Test through alpaca (works both on and off VPN — off VPN routes DIRECT)
curl -x http://localhost:3128 https://httpbin.org/ip
```

### Fresh deploy (via deploy.sh)

On a new Omarchy system, `scripts/deploy.sh` handles all of the above:

```bash
~/projects/omarchy-config/scripts/deploy.sh
```

This stows the systemd units from `dotfiles/systemd/`, installs `openconnect` and `alpaca-proxy`, runs `systemctl --user daemon-reload` and enables `alpaca.service` + `alpaca-pac-refresh.timer`, and stows the fish config with global proxy env vars. The initial PAC file (`~/.config/alpaca/wpad.dat`) must be created manually (or copied from a download) — see step 2.

## Workflow

```bash
# 1. Connect to VPN (stops Tailscale, gp-saml-gui SAML login, connects OpenConnect)
~/connect-to-vpn.sh            # live script (mirrored in scripts/vpn-connect.sh)

# 2. Work — proxy env vars are already set, alpaca handles routing
curl https://internal.intel.com/api/...
git clone https://github.intel.com/org/repo

# 3. Disconnect VPN (Ctrl+C the connect script, or from another terminal:)
scripts/vpn-disconnect.sh
```

No per-shell proxy toggling needed. Proxy env vars are set globally in `config.fish` and alpaca runs permanently as a systemd user service.

> **After (re)connecting the VPN**, if intranet requests still get routed DIRECT (e.g. right after a reconnect, alpaca may still hold the corporate proxy in its 5-minute blocklist), run `vpn-proxy restart` — see [Forcing a proxy-block refresh](#forcing-a-proxy-block-refresh).

## How it works

### alpaca systemd user service

Alpaca runs permanently as a systemd user service, started at login and managed independently of VPN state:

```ini
[Unit]
Description=Alpaca PAC-aware local HTTP proxy
After=network-online.target

[Service]
ExecStart=/usr/bin/alpaca -C file://%h/.config/alpaca/wpad.dat
Restart=on-failure

[Install]
WantedBy=default.target
```

The service is defined in `dotfiles/systemd/.config/systemd/user/alpaca.service` and deployed via stow + `systemctl --user enable --now`. It reads the **local PAC file** (`~/.config/alpaca/wpad.dat`), so no DNS lookup for `wpad.intel.com` is needed at runtime.

### PAC refresh (alpaca-pac-refresh.timer)

Because the PAC is a local file, it needs periodic re-fetching. `alpaca-pac-refresh.timer` runs `alpaca-pac-refresh.sh` every 15 minutes. The script:

1. Checks that the VPN is up (`pgrep -x openconnect`) — `wpad.intel.com` only resolves through the tunnel, so it exits silently when off VPN.
2. Fetches `http://wpad.intel.com/wpad.dat` directly (`--noproxy '*'`, bypassing alpaca).
3. Appends `; DIRECT` to the default `PROXY proxy-dmz.intel.com:912` rule.
4. Restarts `alpaca.service` only if the content actually changed.

### Forcing a proxy-block refresh

Alpaca keeps an in-memory **blocklist** of proxies that failed to connect, and won't route via them for **5 minutes** (Chrome's behavior). This is what makes the off-VPN DIRECT fallback work — the unreachable `proxy-dmz.intel.com` gets blocked, and the `; DIRECT` suffix in the PAC routes everything DIRECT instead of 502ing.

The side effect: **right after (re)connecting the VPN**, alpaca may still hold the corporate proxy in its blocklist for up to 5 minutes, so intranet requests get sent DIRECT (and fail). To clear the blocklist and reload the PAC immediately:

```bash
vpn-proxy restart
# equivalent:
systemctl --user restart alpaca.service
```

You can confirm this is happening by watching the logs for `Temporarily blocking proxy`:

```bash
journalctl --user -u alpaca.service -f
```

### Proxy env vars (config.fish)

Proxy environment variables are set globally in `config.fish`, always pointing to `localhost:3128`:

```fish
set -gx http_proxy http://localhost:3128
set -gx HTTP_PROXY http://localhost:3128
set -gx https_proxy http://localhost:3128
set -gx HTTPS_PROXY http://localhost:3128
set -gx no_proxy localhost,127.0.0.0/8,::1
set -gx NO_PROXY localhost,127.0.0.0/8,::1
```

| Variable                      | Value                       |
|-------------------------------|-----------------------------|
| `http_proxy` / `HTTP_PROXY`   | `http://localhost:3128`     |
| `https_proxy` / `HTTPS_PROXY` | `http://localhost:3128`     |
| `no_proxy` / `NO_PROXY`       | `localhost,127.0.0.0/8,::1` |

The `NO_PROXY` list is minimal because alpaca handles all the routing decisions via the PAC file. Only localhost/loopback is excluded to prevent a loop.

### vpn-proxy (fish function)

Shows proxy state + alpaca status, and can force-refresh alpaca:

```bash
vpn-proxy            # show proxy state + alpaca status
vpn-proxy status     # same
vpn-proxy restart    # clear alpaca's 5-min proxy blocklist + reload local PAC
```

### vpn-connect.sh / connect-to-vpn.sh

1. Stops Tailscale (IT policy + avoids routing conflicts), restores it on exit
2. Decrypts the client key, then connects to GlobalProtect via `gp-saml-gui` (SAML login in a WebKit window) which spawns `sudo openconnect`

The openconnect invocation is hardened to fix the flaky tunnel:

- `--no-dtls` — GlobalProtect's default data plane is **UDP-encapsulated ESP**, which produces `Failed to send ESP packet: Network is unreachable` and silently dies under NAT/firewalls ("all traffic stops, even ping 8.8.8.8"). This forces a TLS data tunnel, which is stable through corporate NAT.
- `--force-dpd 30` — sends dead-peer-detection keepalives every 30 s so stateful firewalls/NAT don't drop the idle TLS tunnel (this replaces `--tcp-keepalive`, which is unavailable in openconnect v9.21).
- `--reconnect-timeout 600` — keeps trying to reconnect for 10 minutes after a blip.
- `--servercert pin-sha256:...` — pins the gateway certificate (the SAML webview still uses `--no-verify` because Intel's gateway cert is from an internal CA the WebKit view can't trust).
- `env -u ...proxy...` + `--no-proxy` — prevents openconnect itself from being routed through alpaca (which would loop, since the proxy needs the VPN to be up).

The live script is `/home/mark/connect-to-vpn.sh`; the repo mirror is `scripts/vpn-connect.sh`. Keep them in sync.

### vpn-disconnect.sh

1. Kills OpenConnect (if running in background)
2. Restarts Tailscale

Alpaca is **not** managed by this script — it keeps running and auto-falls back to DIRECT off VPN.

If OpenConnect is running in the foreground (the default), just Ctrl+C it, then run:

```bash
scripts/vpn-disconnect.sh
```

### Git: scoped proxy for Intel repos

Instead of relying on env vars for git, scope the proxy to Intel URLs only in `~/.config/git/config`:

```gitconfig
[http "https://github.intel.com/"]
    proxy = http://localhost:3128
```

This means `git clone https://github.intel.com/...` uses alpaca (which routes through the Intel proxy via PAC), while `git clone https://github.com/...` goes direct. Adjust the URL to match your internal git hosting.

## Alpaca details

Alpaca is a Go binary that acts as a local HTTP proxy. Key features:

- **PAC file support**: Reads the **local PAC** at `~/.config/alpaca/wpad.dat` (via `-C file://...`) and evaluates it per-request
- **Proxy blocking + DIRECT fallback**: When a proxy fails to connect, alpaca blocks it for 5 minutes and (thanks to the `; DIRECT` suffix added to the PAC's default rule) routes traffic DIRECT instead of returning 502 — so off VPN everything works without toggling
- **No auth needed**: Intel's proxy doesn't require authentication, so no NTLM/credential setup

The `-C` flag sets the PAC URL explicitly. A local `file://` URL is used so no DNS lookup for `wpad.intel.com` is needed at runtime (the remote URL would cause alpaca to lose its PAC whenever corporate DNS hiccups on the VPN).

### Kerberos (future consideration)

Although the proxy doesn't require auth, Intel supports Kerberos. If internal web services or SSO portals require negotiate/SPNEGO auth, consider [px-proxy](https://github.com/genotrance/px) (`pip install px-proxy`) which has built-in Kerberos ticket management.

## OpenConnect + SAML authentication

Intel's GlobalProtect requires SAML authentication via Azure AD with 2FA. The working flow uses [gp-saml-gui](https://github.com/dlenski/gp-saml-gui), which opens a GTK WebKit window for the interactive SAML login and then spawns `sudo openconnect` with the acquired cookie (see `~/connect-to-vpn.sh` / `scripts/vpn-connect.sh`). It's installed via `pip`:

```bash
pip install https://github.com/dlenski/gp-saml-gui/archive/master.zip
# Arch runtime deps: gtk3 gobject-introspection webkit2gtk
```

### Known tunnel issue: "Failed to send ESP packet: Network is unreachable"

GlobalProtect's default data plane is **UDP-encapsulated ESP**. Over NAT/Wi-Fi this can fail at connect time (`Failed to send ESP packet: Network is unreachable`) or die silently later — after which the full-tunnel default route and corporate DNS keep pointing into the dead tunnel, so **all** traffic stops (even `ping 8.8.8.8`, and alpaca can no longer resolve `wpad.intel.com` / the proxy).

**Fix (already applied):** pass `--no-dtls` to openconnect to force the TLS data plane, plus `--force-dpd 30` (keepalives so NAT doesn't drop the idle tunnel) and `--reconnect-timeout 600`. This removes ESP entirely and keeps the tunnel stable through firewalls/NAT.

## Files in this repo

| File                                                   | Purpose                                                             |
|--------------------------------------------------------|---------------------------------------------------------------------|
| `dotfiles/systemd/.config/systemd/user/alpaca.service` | Systemd user service for always-on alpaca (local PAC)               |
| `dotfiles/systemd/.../alpaca-pac-refresh.service`      | Oneshot: refresh local PAC (runs on timer, VPN-gated)               |
| `dotfiles/systemd/.../alpaca-pac-refresh.timer`        | Runs the PAC refresh every 15 min                                   |
| `dotfiles/bin/.local/bin/alpaca-pac-refresh.sh`        | Fetches wpad.intel.com while on VPN, appends "; DIRECT", restarts   |
| `dotfiles/fish/.config/fish/config.fish`               | Sets proxy env vars globally                                        |
| `dotfiles/fish/.config/fish/functions/vpn-proxy.fish`  | Proxy + alpaca status, `vpn-proxy restart`                          |
| `scripts/vpn-connect.sh`                               | Mirror of `~/connect-to-vpn.sh` (gp-saml-gui + `--no-dtls`)         |
| `scripts/vpn-disconnect.sh`                            | Disconnect VPN, restart Tailscale                                   |
| `scripts/deploy.sh`                                    | Installs deps, stows units, enables alpaca + refresh timer          |

## Troubleshooting

### Proxy set but connections fail

Check if VPN is actually connected:

```bash
ip route | grep -i tun    # should show tun0 or similar
```

Check if alpaca is running:

```bash
vpn-proxy                  # shows proxy state + alpaca status
systemctl --user status alpaca.service
```

### Intranet fails right after reconnecting the VPN

Alpaca blocks a proxy that recently failed to connect for **5 minutes**. After (re)connecting the VPN, the corporate proxy may still be blocked, so intranet requests are routed DIRECT and fail. Force-clear it:

```bash
vpn-proxy restart
```

### "All traffic stopped, even ping 8.8.8.8" while on VPN

This is the ESP tunnel dying (see [Known tunnel issue](#known-tunnel-issue-failed-to-send-esp-packet-network-is-unreachable)), not alpaca. The fix (`--no-dtls`) is already in `connect-to-vpn.sh`. After reconnecting, `vpn-proxy restart` clears any stale proxy block.

### Alpaca not routing correctly

Test a corporate URL directly through alpaca:

```bash
curl -x http://localhost:3128 https://some-internal.intel.com/
```

If this fails but direct proxy works, the PAC file may not cover this URL:

```bash
curl -x http://proxy-dmz.intel.com:912 https://some-internal.intel.com/
```

### DNS not resolving internal hosts

OpenConnect should push DNS settings via the `vpnc-script`. Check:

```bash
resolvectl status    # should show Intel DNS servers on the tun interface
```

### Git clone from GitHub failing through proxy

Alpaca should route GitHub DIRECT via the PAC file. If not, check that you're not using the scoped git proxy for GitHub URLs. The `[http "https://github.intel.com/"]` config should only match the internal git host.
