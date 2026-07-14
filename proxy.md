# Corporate VPN & Proxy (Intel)

Setup guide for connecting to Intel's corporate network from Omarchy, using OpenConnect (GlobalProtect) and the corporate HTTP proxy.

## Overview

Intel requires a VPN connection (GlobalProtect) plus an HTTP proxy for accessing internal resources. The goal is to keep the system behaving normally when off VPN, and only route corporate traffic through the proxy when connected.

### Architecture

[Alpaca](https://github.com/samuong/alpaca) runs permanently as a systemd user service on `localhost:3128`, reading Intel's PAC file to make per-request routing decisions. Corporate traffic goes through the Intel proxy; everything else goes DIRECT. When off VPN, the corporate proxy is unreachable so alpaca auto-falls back to DIRECT for all requests.

```
  Your apps (curl, git, browser, Teams)
          │
     HTTP_PROXY=http://localhost:3128
          │
          ▼
    alpaca (localhost:3128)
      systemd user service (always running)
          │
          ├── reads http://wpad.intel.com/wpad.dat
          ├── evaluates PAC rules per request
          │
          ├── [on VPN]  corporate URLs → proxy-dmz.intel.com:911/912
          ├── [on VPN]  everything else → DIRECT
          └── [off VPN] proxy unreachable → ALL → DIRECT
```

### Key principle

**Proxy env vars are set globally** in `config.fish`, always pointing to `localhost:3128`. This is safe because alpaca runs permanently and auto-falls back to DIRECT when off VPN. No per-shell toggling needed — new shells automatically have proxy set, and alpaca handles the routing transparently based on whether the corporate proxy is reachable.

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

### 2. Create the systemd user service

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
ExecStart=/usr/bin/alpaca -C http://wpad.intel.com/wpad.dat
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

### 4. Set proxy environment variables

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

### 5. (Optional) Scoped git proxy for Intel repos

If you use Intel's internal GitLab (e.g. `github.intel.com`), scope the proxy in `~/.config/git/config` so alpaca is only used for those URLs:

```gitconfig
[http "https://github.intel.com/"]
    proxy = http://localhost:3128
```

Regular `github.com` clones go direct — no `http_proxy` interference.

### 6. Verify

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

This stows the systemd unit from `dotfiles/systemd/`, installs `openconnect` and `alpaca-proxy`, runs `systemctl --user daemon-reload && enable --now alpaca.service`, and stows the fish config with global proxy env vars.

## Workflow

```bash
# 1. Connect to VPN (stops Tailscale, connects OpenConnect)
scripts/vpn-connect.sh <vpn-gateway-hostname>

# 2. Work — proxy env vars are already set, alpaca handles routing
curl https://internal.intel.com/api/...
git clone https://github.intel.com/org/repo

# 3. Disconnect VPN (Ctrl+C the connect script, or from another terminal:)
scripts/vpn-disconnect.sh
```

No per-shell proxy toggling needed. Proxy env vars are set globally in `config.fish` and alpaca runs permanently as a systemd user service.

## How it works

### alpaca systemd user service

Alpaca runs permanently as a systemd user service, started at login and managed independently of VPN state:

```ini
[Unit]
Description=Alpaca PAC-aware local HTTP proxy
After=network-online.target

[Service]
ExecStart=%h/.local/bin/alpaca -C http://wpad.intel.com/wpad.dat
Restart=on-failure

[Install]
WantedBy=default.target
```

The service is defined in `dotfiles/systemd/.config/systemd/user/alpaca.service` and deployed via stow + `systemctl --user enable --now`.

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

Now a status-only command since proxy env vars are always set:

```bash
vpn-proxy         # show proxy state + alpaca status
vpn-proxy status  # same
```

### vpn-connect.sh

1. Stops Tailscale (IT policy + avoids routing conflicts)
2. Connects to GlobalProtect VPN via OpenConnect (foreground, SAML auth in browser)

Alpaca is **not** managed by this script — it's already running via systemd.

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

- **PAC file support**: Reads `http://wpad.intel.com/wpad.dat` and evaluates it per-request
- **Auto-fallback**: When the corporate proxy becomes unreachable (e.g. off VPN), automatically routes everything DIRECT — no need to toggle proxy off
- **No auth needed**: Intel's proxy doesn't require authentication, so no NTLM/credential setup

The `-C` flag sets the PAC URL explicitly. On GNOME systems alpaca can auto-detect it, but we pass it explicitly for reliability.

### Kerberos (future consideration)

Although the proxy doesn't require auth, Intel supports Kerberos. If internal web services or SSO portals require negotiate/SPNEGO auth, consider [px-proxy](https://github.com/genotrance/px) (`pip install px-proxy`) which has built-in Kerberos ticket management.

## OpenConnect + SAML authentication

Intel's GlobalProtect requires SAML authentication via Azure AD with 2FA. OpenConnect supports this but needs a browser helper for the SAML flow.

**TODO**: Document the specific SAML authentication flow for Intel's VPN. Resources to investigate:
- [gp-saml-gui](https://github.com/dlenski/gp-saml-gui) -- GTK WebKit-based SAML login helper
- OpenConnect's `--useragent=PAN` flag for GlobalProtect compatibility
- `openconnect --authenticate --protocol=gp` to extract SAML token

This section will be completed once the SAML flow is tested and working.

## Files in this repo

| File                                                   | Purpose                                                             |
|--------------------------------------------------------|---------------------------------------------------------------------|
| `dotfiles/systemd/.config/systemd/user/alpaca.service` | Systemd user service for always-on alpaca                           |
| `dotfiles/fish/.config/fish/config.fish`               | Sets proxy env vars globally                                        |
| `dotfiles/fish/.config/fish/functions/vpn-proxy.fish`  | Fish function to check proxy + alpaca status                        |
| `scripts/vpn-connect.sh`                               | Stop Tailscale, connect VPN                                         |
| `scripts/vpn-disconnect.sh`                            | Disconnect VPN, restart Tailscale                                   |
| `scripts/deploy.sh`                                    | Installs `openconnect`, `alpaca-proxy`, and enables systemd service |

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
