# Updating Hyprland and hy3

Notes for keeping the [hy3](https://github.com/outfoxxed/hy3) plugin working
across Hyprland updates on this machine (Omarchy quattro, Hyprland from the
Arch repos, hy3 built by `hyprpm`).

hy3 is not a package here — it is a plugin compiled locally by `hyprpm` against
the exact Hyprland headers installed on the system. Every Hyprland update
invalidates that build, and `hyprpm` has to rebuild it.

- [TL;DR](#tldr)
- [How it fits together](#how-it-fits-together)
- [Routine update](#routine-update)
- [The stale-DSO trap](#the-stale-dso-trap-most-important)
- [Choosing the hy3 revision](#choosing-the-hy3-revision)
- [Troubleshooting](#troubleshooting)
- [Command cheat sheet](#command-cheat-sheet)
- [Health check](#health-check)
- [Case study: 2026-10-23](#case-study-2026-10-23)
- [References](#references)

## TL;DR

After a Hyprland update:

```bash
# 1. Update the system as usual, then rebuild the plugin for the new version
hyprpm update

# 2. Log out and back in (or reboot). A `hyprctl reload` is NOT enough.
omarchy-system-logout

# 3. After logging back in, verify
hyprctl plugin list          # should list hy3
hyprpm list                  # should show enabled: true
```

If you ever see **"hy3 was compiled for a different version of hyprland"**,
the first thing to try is a **full Hyprland restart** — see
[the stale-DSO trap](#the-stale-dso-trap-most-important). Rebuilding alone
does not fix it if an old copy of the plugin is still mapped in the running
compositor.

## How it fits together

### Version / ABI check

Hyprland and plugins compare an ABI string that is baked into both:

```
<git commit>_aq_<aquamarine major.minor>_hu_<hyprutils>_hg_<hyprgraphics>_hc_<hyprcursor>_hlg_<hyprlang>
```

The patch component of each library version is stripped, e.g. aquamarine
`0.15.1` becomes `0.15`. Current value on this machine:

```
efb50993780079460b0cbed1363e2166a2de1d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6
```

- Hyprland computes it in `__hyprland_api_get_hash()`.
- Plugins compute it in the inline `__hyprland_api_get_client_hash()` from the
  Hyprland headers they were compiled against.
- hy3 refuses to initialise when the two differ:

  ```
  [hy3] hy3 was compiled for a different version of hyprland; refusing to load.
  [hy3] target hyprland version mismatch
  ```

  (thrown from `PLUGIN_INIT`; the notification text comes from hy3 itself)

Check the current values with:

```bash
hyprctl -j version | jq -r '.commit, .abiHash'
```

`hyprpm` stores the ABI it built headers for in
`/var/cache/hyprpm/$USER/state.toml`.

### Where hyprpm keeps things (Arch packaging)

On Arch, `hyprpm` works in a system cache directory, not `~/.local/share`:

| Path | Contents |
|---|---|
| `/var/cache/hyprpm/$USER/state.toml` | Global state: ABI hash the headers were built for, `dont_warn_install` |
| `/var/cache/hyprpm/$USER/<repo>/state.toml` | Per-plugin: `enabled`, `failed`, `filename`, repo URL/author/rev/hash |
| `/var/cache/hyprpm/$USER/<repo>/<plugin>.so` | The built plugin loaded by Hyprland |
| `/var/cache/hyprpm/$USER/headersRoot/` | Hyprland headers + `hyprland.pc` installed from the matching Hyprland commit |
| `/var/cache/hyprpm/$USER/headersRoot/include/hyprland/src/version.h` | The commit and library versions the headers correspond to |
| `$XDG_RUNTIME_DIR/hyprpm/` | Temporary clone/build directory (removed after a build) |

The cache files are **owned by root** because `hyprpm` installs them with
`sudo`. That is normal:

- Run `hyprpm` from a real terminal so it can prompt for the sudo password.
- `hyprpm` caches sudo credentials at the start of an operation and drops them
  at the end.
- Running it non-interactively (script, agent, no TTY) fails with
  `Failed to write plugin state` — that is a sudo/TTY problem, not a plugin
  problem.
- Never run `hyprpm` with `sudo`/as root; it refuses ("Don't run hyprpm as a
  superuser.").

Useful headers facts:

- `headersRoot/include/hyprland/src/version.h` must contain the **running**
  Hyprland's `GIT_COMMIT_HASH`.
- `headersRoot/share/pkgconfig/hyprland.pc` points the build at these headers
  (`PKG_CONFIG_PATH` is set by hyprpm).
- `/usr/include/hyprland` also exists (shipped by the Arch `hyprland` package).
  hyprpm prefers its own `headersRoot` copy.

### What loads hy3

`~/.config/hypr/autostart.lua` (symlink to this repo) runs at every login:

```lua
o.exec_on_start("hyprpm reload -n && sleep 1 && hyprctl reload")
```

- `hyprpm reload` loads all enabled plugins from the hyprpm cache into the
  **running** compositor.
- `sleep 1 && hyprctl reload` then re-parses the Lua config, so
  `plugins.lua`'s `plugin:hy3:*` values are applied after hy3 has registered
  them. Without the second reload the hy3 config section can be rejected.
- `hyprctl reload` alone only reloads config; it does **not** load or unload
  plugins.
- `hyprpm enable/disable/reload` all call `ensurePluginsLoadState()`, which
  loads/unloads through the Hyprland socket.

### Config files

| File | Role |
|---|---|
| `~/.config/hypr/hyprland.lua` | Entry point; `require("hypr.plugins")` etc. |
| `~/.config/hypr/plugins.lua` | hy3 settings via `hl.config({ plugin = { hy3 = { ... } } })`; colours come from the active Omarchy theme, tab radius from `appearance.json` |
| `~/.config/hypr/bindings.lua` | i3-style bindings using `hl.plugin.hy3` dispatcher factories (`move_focus`, `make_group`, `focus_tab`, …) |
| `~/.config/hypr/looknfeel.lua` | Sets `general:layout = hy3` (and related look) |
| `~/.config/hypr/autostart.lua` | `hyprpm reload -n` at login |

All of these are symlinks into `~/projects/omarchy-config/dotfiles/hypr/.config/hypr/`.

## Routine update

Recommended order:

```bash
# 1. Update packages (Hyprland, hyprpm, libraries)
omarchy-update            # or: sudo pacman -Syu

# 2. Rebuild hy3 against the new headers
hyprpm update             # add -f if it claims headers are up to date but builds fail

# 3. Restart the compositor (NOT just `hyprctl reload`)
omarchy-system-logout     # or the power menu → Log out
```

Why this order: after the package update, `hyprpm update` reads the
**installed** Hyprland version (`Hyprland --version-json`) and installs matching
headers, so it can build the plugin for the version you are about to log into.
It will then refuse to load the new plugin into the still-running old
compositor and print:

```
Running Hyprland version (<old hash>) differs from plugin state (<new ABI>), please restart Hyprland.
```

That message is expected and is your cue to log out.

If you log out first and update later:

```bash
# after logging into the new Hyprland
hyprpm update
hyprpm reload -n
```

That works too, as long as the plugin was not already loaded in the new session
(it will not have been, because the headers were stale at login and
`hyprpm reload` refuses with "headers are not up-to-date").

`hyprpm update` needs network access (it clones the Hyprland repo at the
matching commit) and build deps (`base-devel`, `cmake`, `pkgconf`, `cpio`,
`git`; `scripts/deploy.sh` installs them).

## The stale-DSO trap (most important)

This is the failure mode that wasted the most time. **Rebuilding the plugin
does not replace it in a running Hyprland.**

### Mechanism

1. `hy3.so` exports GNU-unique symbols (`nm -D hy3.so | awk '$2 == "u"'` shows
   `g_pHyprland…`, `g_hy3Instances`, etc.).
2. glibc marks such a shared object `NODELETE`. When Hyprland unloads a plugin
   (`dlclose`) — for example because `PLUGIN_INIT` threw the version-mismatch
   exception — the object **stays mapped** in the process.
3. A later `dlopen()` of the same path matches the already-loaded object by
   name and returns the **old code**, even though the file on disk was rebuilt
   or replaced. The old inode is shown as `(deleted)`.
4. So every subsequent `hyprpm enable hy3` / `hyprpm reload` re-runs the
   *old* plugin's init, which fails the hash check again. The file on disk may
   be perfectly correct.

### Symptoms

- Running `hyprpm enable hy3` (or `hyprpm reload`) keeps popping hy3's desktop
  notification "hy3 was compiled for a different version of hyprland", even
  right after a successful rebuild. The terminal still prints
  `✔ Loaded hy3`.
- `hyprctl plugin list` prints `no plugins loaded`.
- `hyprpm list` shows `enabled: true`.
- The running Hyprland maps a **deleted** copy of the plugin.

### Diagnosis

```bash
# Is the loaded copy stale?
grep -i hy3 /proc/$(pgrep -x Hyprland)/maps
# → ... /var/cache/hyprpm/renamed/hy3/hy3.so (deleted)

# Does the file on disk actually match the running Hyprland?
stat -c '%i %y' /var/cache/hyprpm/renamed/hy3/hy3.so
hyprctl -j version | jq -r '.commit, .abiHash'

# The commit the .so was built against is embedded in it
COMMIT=$(hyprctl -j version | jq -r .commit)
grep -a -o "$COMMIT" /var/cache/hyprpm/renamed/hy3/hy3.so | head -1
```

If the inode in `/proc/<pid>/maps` is `(deleted)` and differs from the current
file's inode, the running compositor is executing old code.

### Fix

**Restart Hyprland.** There is no way to force-unload a `NODELETE` DSO from a
live process, and `hyprctl plugin unload` cannot help because the failed plugin
is not registered.

```bash
omarchy-system-logout    # or power menu → Log out / Restart
```

After logging back in, the autostart line loads the current file.

### Without restarting (stopgap only)

Loading the new build under a **different filename** bypasses the dlopen
name-match:

```bash
sudo cp /var/cache/hyprpm/renamed/hy3/hy3.so \
        /var/cache/hyprpm/renamed/hy3/hy3-current.so
hyprctl plugin load /var/cache/hyprpm/renamed/hy3/hy3-current.so
```

hyprpm's state still points at `hy3.so`, so this is not persisted and the next
`hyprpm reload` may try the stale path again. Prefer the restart.

### Prevention

- After any `hyprpm update`/`hyprpm add` that rebuilds a plugin, **restart
  Hyprland** instead of relying on `hyprpm reload`.
- Do not `rm -rf /var/cache/hyprpm/$USER/<plugin>` while the plugin is mapped
  in a running compositor — that is exactly how you get a deleted-but-mapped
  copy.
- `hyprpm` prints `✔ Loaded hy3` after a reload even when Hyprland rejected the
  plugin: `loadUnloadPlugin()` only checks the state hash and sends the socket
  command, it does not read the result. Always confirm with
  `hyprctl plugin list`.

## Choosing the hy3 revision

hy3 tracks Hyprland closely:

- Tagged releases are named `hl<hyprland version>` (e.g. `hl0.56.0`).
- `master` tracks Hyprland `main` and may not build against a stable release.
- `hyprpm.toml` contains `commit_pins`, mapping a Hyprland commit to the hy3
  commit to check out. For Hyprland **0.56.2** (`efb5099…`) the pin is
  `db288088c0e99cb15e72bc4468a2514bb26631a7` (2026-07-23).

`hyprpm add <url> <rev>` **overrides** the pins and builds exactly `<rev>`.
Prefer letting the manifest pin decide; only pin a rev when the manifest has
no pin for the installed Hyprland (which was the original reason for the pin in
`scripts/deploy.sh`).

### Current state (2026-10-23 23:20)

| Item | Value |
|---|---|
| Hyprland | `0.56.2-4`, commit `efb50993780079460b0cbed1363e2166a2de1d9f` |
| ABI | `efb5099…_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6` |
| hyprpm repo | `https://github.com/outfoxxed/hy3` |
| Repo rev pinned in state | `0f32517` (2026-07-21, "fixup: chase 0.56.0") |
| Recorded repo hash | `c35adfa3620a88484fafbbe37dc4d99b19319308` (upstream master) |
| Plugin state | `enabled = true`, `failed = false` |
| Built | 2026-10-23 23:20:38 |

Note: `0f32517` is **3 commits behind** the 0.56.2 manifest pin `db2880`
(which includes "fix: tab bars rendered in wrong orientation on rotated
monitors"). It builds and passes the ABI check because the ABI comes from the
headers, but it is not the revision upstream recommends for 0.56.2.

### Known drift in this repo

`scripts/deploy.sh` still does:

```bash
HY3_REV="0f32517"
hyprpm add "https://github.com/outfoxxed/hy3" "$HY3_REV"
```

That pin was added when upstream's manifest had no pin for the then-installed
Hyprland. Upstream now pins 0.56.0/0.56.1/0.56.2 (`db2880`), so the pin can be
dropped:

```bash
hyprpm add "https://github.com/outfoxxed/hy3"   # let the manifest pin decide
```

or updated to `db2880` if an explicit pin is still wanted. Also note that
`hyprpm add` fails with "Repository already installed" if a `hy3` repo exists;
`hyprpm remove hy3` first (deploy.sh already handles this).

`README.md` and `dotfiles/hypr/README.md` point at `outfoxxed/hy3`, which is
the canonical repo. A `kociap/hy3` fork was installed for a while (it is a
snapshot of upstream, at the time 2 commits behind); the state was switched
back to `outfoxxed/hy3` on 2026-10-23. Prefer upstream.

## Troubleshooting

### Error → cause → fix

| Message / symptom | Cause | Fix |
|---|---|---|
| `hy3 was compiled for a different version of hyprland` | hy3's client ABI ≠ running Hyprland's ABI — either a stale mapped DSO (most common), old headers, or a build from another Hyprland version | Check `/proc/<pid>/maps` for `(deleted)`; if stale → **restart Hyprland**. Otherwise `hyprpm update -f`, then restart |
| `Running Hyprland version (…) differs from plugin state (…), please restart Hyprland.` | You rebuilt for the newly installed Hyprland while the old compositor is still running | Log out and back in |
| `headers are not up-to-date, please run hyprpm update.` | `state.toml` ABI or `version.h` commit doesn't match the installed Hyprland | `hyprpm update` (then restart if the running compositor is older) |
| `Headers version mismatch. Please run hyprpm update to fix those.` | `headersRoot` was built from a different Hyprland commit | `hyprpm update`; `-f` if it insists they are up to date |
| `ABI is mismatched. Please run hyprpm update to fix that.` | Library versions in the headers differ from the installed libraries | Update packages, `hyprpm update` |
| `Headers missing.` / `Headers corrupted.` | `headersRoot` deleted or incomplete | `hyprpm update -f`; last resort `hyprpm purge-cache` |
| `Headers duplicated!!!` | Hyprland headers in more than one pkg-config location (e.g. `/usr/include` and `/usr/local/include`) | Remove the stray copy (see hy3 README), then `hyprpm update` |
| `Failed to write plugin state` | `hyprpm` couldn't `sudo install` its state file (no TTY / password prompt) | Run `hyprpm` from a real terminal |
| `hyprpm` says `Loaded hy3`, but `hyprctl plugin list` is empty | `hyprpm` doesn't check the load result; the plugin refused or crashed in init | Check the hy3/ABI error, then restart |
| Build fails after a Hyprland bump | hy3 revision doesn't support the new Hyprland yet | Check upstream for a new pin/tag; wait, pin a compatible rev, or temporarily disable hy3 |
| `hyprpm add` → `Repository already installed` | Repo name (`hy3`) already exists | `hyprpm remove hy3`, then add again |
| `Don't run hyprpm as a superuser.` | Ran with `sudo` | Run as your user; let hyprpm call sudo |

### Notes

- `hyprpm update` = update headers + rebuild all repos; `hyprpm reload` = only
  load/unload what is enabled; `hyprctl reload` = config only.
- `hyprpm update -f` forces a headers rebuild even if hyprpm thinks they are
  current. Useful after weird states.
- `hyprpm purge-cache` deletes the whole hyprpm cache (headers, built plugins,
  state). It is the nuclear option; afterwards you need `hyprpm update` and to
  re-add/enable hy3.
- On Arch, `/usr/include/hyprland` comes from the `hyprland` package. hyprpm
  builds against `/var/cache/hyprpm/$USER/headersRoot`, so both existing is
  normal; only remove `/usr/local/include/hyprland` if it exists and causes
  duplicate-header errors.
- If the plugin was built but Hyprland refuses to load it, look for
  `PluginSystem` / `crashed in init` lines in
  `$XDG_RUNTIME_DIR/hypr/<instance>/hyprland.log`.
- `hyprctl plugin load <path>` / `hyprctl plugin unload <path>` operate on the
  running compositor only; they do not update hyprpm state.

## Command cheat sheet

```bash
# What is running / what was it built against
hyprctl version
hyprctl -j version | jq -r '.commit, .abiHash'

# hyprpm state
hyprpm list
hyprpm --verbose list
cat /var/cache/hyprpm/$USER/state.toml
cat /var/cache/hyprpm/$USER/hy3/state.toml

# What is actually loaded right now
hyprctl plugin list
hyprctl -j plugin list

# Rebuild for the installed Hyprland
hyprpm update
hyprpm update -f          # force headers rebuild

# Load enabled plugins into the running compositor
hyprpm reload -n

# Enable / disable
hyprpm enable hy3
hyprpm disable hy3

# Reinstall the repo (e.g. after switching URL/rev)
hyprpm remove hy3
hyprpm add https://github.com/outfoxxed/hy3
hyprpm enable hy3

# Nuclear option
hyprpm purge-cache
```

## Health check

Run after logging in, or whenever hy3 behaves oddly:

```bash
echo "== hyprland =="
hyprctl version | sed -n '1p;/ABI/p'

echo "== hyprpm state =="
hyprpm list | sed 's/\x1b\[[0-9;]*m//g'

echo "== loaded plugins =="
hyprctl plugin list

echo "== stale mappings =="
grep -i hy3 /proc/$(pgrep -x Hyprland)/maps || echo "hy3 not mapped"

echo "== cache =="
stat -c '%y %n' /var/cache/hyprpm/$USER/hy3/hy3.so \
               /var/cache/hyprpm/$USER/hy3/state.toml \
               /var/cache/hyprpm/$USER/state.toml
```

Expected healthy output:

- `hyprctl plugin list` contains `hy3`.
- `/proc/<pid>/maps` shows the plugin **without** `(deleted)`, with the same
  inode as the file on disk.
- `hyprpm list` shows `enabled: true` (not "Plugin failed to build").
- `state.toml` ABI equals `hyprctl -j version | jq -r .abiHash`.

## Case study: 2026-10-23

What happened, for future reference:

1. Hyprland/hyprpm were updated to `0.56.2-4` (package build 2026-09-30,
   installed 22:53). The session was restarted at 23:01.
2. An older hy3 build was loaded into the new Hyprland session and failed
   hy3's version check. That failed load left the old `hy3.so` mapped in the
   Hyprland process (GNU-unique symbols → `NODELETE`). The stale copy was
   deleted when the cache was cleaned up during the rebuild.
3. Rebuilds at 23:03 and 23:04 produced a correct plugin for 0.56.2 (headers
   installed 23:04:06, plugin built 23:04:41), but the running process kept
   the old deleted inode (`/proc/<pid>/maps` showed `(deleted)`).
4. Every `hyprpm enable hy3` re-ran the old plugin's init and produced
   "hy3 was compiled for a different version of hyprland"; `hyprctl plugin
   list` stayed empty, while `hyprpm` still printed `✔ Loaded hy3`.
5. Verification that the on-disk build was fine:
   - `hyprctl -j version` ABI `efb5099…_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6`
   - the plugin's embedded commit/version literals were identical
     (`efb5099…`, `0.15.1`, `0.14.2`, `0.5.1`, `0.1.13`, `0.6.8`)
   - but `/proc/<pid>/maps` pointed at a deleted inode
6. The fix is a Hyprland restart. The plugin repo was also switched back from
   the `kociap/hy3` fork to `outfoxxed/hy3` (with `rev = 0f32517` from
   `deploy.sh`), rebuilt at 23:20.

Lesson: **a rebuild is not live until the compositor restarts.** Treat
`hyprctl plugin list` (not hyprpm's "Loaded" line) as the source of truth.

## References

- hyprpm / plugin docs: <https://wiki.hyprland.org/Plugins/Using-Plugins/>
- hy3: <https://github.com/outfoxxed/hy3>
- hy3 manifest (commit pins): <https://github.com/outfoxxed/hy3/blob/master/hyprpm.toml>
- Omarchy: <https://omarchy.org>
- This repo's deploy script: `scripts/deploy.sh`
