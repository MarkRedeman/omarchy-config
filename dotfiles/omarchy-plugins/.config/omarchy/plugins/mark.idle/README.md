# mark.idle

Local clone of Omarchy's `omarchy.idle` service, with home-network-aware
screensaver and lock timeouts.

Cloned with:

```bash
omarchy plugin clone omarchy.idle
```

## Local change

The built-in idle service uses the `idle.screensaver` and `idle.lock` values
from `shell.json` everywhere. This clone adds a second profile:

- **home** — the normal `idle.screensaver` / `idle.lock` values.
- **away** — `idle.away.screensaver` / `idle.away.lock`, with hardcoded secure
  fallbacks of 5 minutes screen-off and 15 minutes lock.

Network identifiers are deliberately kept out of this repository. The service
reads:

`~/.config/omarchy/local/idle-network.json`

```json
{
  "ssids": ["Mijn wifi netwerk"],
  "addressPrefixes": ["192.168.2."]
}
```

Supported keys:

- `ssids` — connected Wi-Fi SSIDs.
- `connectionNames` — NetworkManager connection names, useful for wired
  connections.
- `addressPrefixes` — prefixes of local interface addresses, so a wired
  connection on the home subnet still counts as home.

Only one rule needs to match. The file is read and watched at runtime, so it
can be edited without restarting the shell.

If the file is missing, unreadable, or no rule matches, the service uses the
secure away profile. That is intentional: deploying the repo on another
machine without creating the local file must not restore the longer at-home
timeouts.

See `idle-network.example.json` for a template.

## Updating

When Omarchy updates the built-in idle service, diff it against this clone:

```bash
diff -ru /usr/share/omarchy/shell/plugins/services/idle \
  ~/.config/omarchy/plugins/mark.idle
```

The local delta is confined to:

- the `Quickshell.Networking` import,
- `networkSnapshot()` and the local config `FileView`,
- the effective-timeout properties near the top of `Service.qml`,
- the extra fields in `statusJson()`,
- `NetworkIdleModel.js` and its tests.

If upstream changes substantially, re-clone and port those pieces instead of
merging by hand.
