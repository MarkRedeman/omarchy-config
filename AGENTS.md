# AGENTS.md

Guidance for coding agents working in this repository. Read this before editing.

## What this repo is

Personal [Omarchy](https://omarchy.org) (Arch Linux + Hyprland) dotfiles managed
with GNU Stow. The current branch is `quatro`, which targets **Omarchy 4.x**:
Hyprland Lua config, the Quickshell shell, and Quickshell plugins.

The legacy v3 setup (hyprlang + Waybar + Walker) lives on a separate branch.
Do not carry v3 assumptions into this branch.

Hyprland uses the [hy3](https://github.com/outfoxxed/hy3) plugin for i3-style
tiling. `scripts/deploy.sh` installs it through `hyprpm` at a pinned revision;
keep hy3-specific binds and layout assumptions out of generic dwindle/master
advice.

Start with:

- `README.md` — install and package layout
- `QUATRO-MIGRATION.md` — what changed in the v4 migration
- `handoff-looknfeel.md` — theme, gaps, corner radius, bar reproduction
- plugin-local `PLAN.md` files under
  `dotfiles/omarchy-plugins/.config/omarchy/plugins/*/` — design notes for
  larger plugin work

## Ground rules

- Read the surrounding file and existing conventions before changing anything.
- **Never edit `~/.local/share/omarchy/`.** It is upstream, managed by git, and
  replaced on updates. Reading it is encouraged.
- Do not commit secrets. `dotfiles/ssh` and `dotfiles/gnupg` are intentionally
  ignored except for sample/config files.
- Treat unfamiliar files and untracked files as user work. Do not delete or
  stage them unless the task explicitly asks.
- Do not run destructive system commands, install services, or use `sudo`
  unless the user asked for it. The TopsWatch installer creates a systemd
  service; run it only with explicit approval.
- Stay on the `quatro` branch. Do not commit quattro changes to the legacy v3
  branch.

## Layout

```text
dotfiles/<package>/.config/...                    Stow packages
dotfiles/omarchy/.config/omarchy/shell.json       Bar layout + plugin entries (tracked, not stowed)
dotfiles/omarchy-plugins/.config/omarchy/plugins/ Quickshell plugins
dotfiles/omarchy-plugins/.config/omarchy/plugins/<id>/PLAN.md  Plugin design notes
scripts/deploy.sh                                 First-time setup (packages, hy3, stow)
scripts/stow.sh                                   Re-stow every package
scripts/shell-config.sh                           Diff/pull/push omarchy shell.json
scripts/install-topswatch.sh                      Hardware-monitor daemon installer wrapper
handoff-looknfeel.md                              Reproduce theme / gaps / bar
QUATRO-MIGRATION.md                               v4 migration tracker
```

## Deploying and testing config

```bash
# First-time setup: packages, hy3, fonts, stow
./scripts/deploy.sh

# Re-stow everything after pulling or editing
./scripts/stow.sh

# Re-stow one package
stow --restow --target="$HOME" --dir=dotfiles hypr
```

`scripts/stow.sh` uses `stow --adopt` followed by `git checkout -- dotfiles`.
That can discard live edits to tracked files. Check `git status` and the live
file before running it if the live config has changes.

### Live config is authoritative

`~/.config/omarchy/shell.json` is the live shell state. It is tracked at
`dotfiles/omarchy/.config/omarchy/shell.json` but **not stowed**:
`dotfiles/omarchy/.stow-local-ignore` excludes it because omarchy-shell rewrites
it with atomic writes, which replaces a stow symlink with a regular file.
`scripts/deploy.sh` seeds a fresh machine with the repo copy only when the live
file is missing. Prefer the live-aware commands when changing the running
system:

```bash
omarchy bar set <widget-id> <key> <value>
omarchy bar move <widget-id> --section right --after <other-id>
omarchy plugin enable <id> --section right --after <other-id>
omarchy plugin disable <id>
omarchy-shell shell rescanPlugins
omarchy-restart-shell
```

Then reconcile the repo copy deliberately instead of expecting stow to do it:

```bash
./scripts/shell-config.sh diff   # compare live and repo
./scripts/shell-config.sh pull   # live -> repo, then review and commit
./scripts/shell-config.sh push   # repo -> live, with a timestamped backup
```

Do not add `shell.json` back to the stow package, and do not assume the live
file is a stow symlink.

## Quickshell plugins

Plugins live in `~/.config/omarchy/plugins/<id>/`, stowed from
`dotfiles/omarchy-plugins/.config/omarchy/plugins/<id>/`.

- Saving a file under the plugin directory hot-reloads it. Use
  `omarchy-shell shell rescanPlugins` if a new file or manifest was added, and
  `omarchy-restart-shell` when the QML engine has cached a broken type.
- Validate the manifest with `omarchy plugin validate <plugin-dir>`.
- `omarchy plugin list` shows enabled/disabled state.
- `qmllint` can report false positives for Quickshell's typed `IpcHandler`
  functions (`: void`, `: string`). Treat the shell log as the source of truth.
- Logs: `journalctl --user -f | grep omarchy-shell`, or
  `journalctl --user --since "2 minutes ago" | grep -E 'omarchy-shell|<plugin-id>'`.

Plugin conventions:

- `manifest.json` at the plugin root, `schemaVersion: 1`, personal ids use the
  `mark.*` namespace.
- Use `qs.Ui` and `qs.Commons` (`Style`, `Color`, `Border`) for native styling;
  avoid hard-coded palettes.
- Settings are inline in `shell.json`; read with `setting()` and persist with
  `bar.shell.updateEntryInline()`.
- Keep a plugin self-contained: `README.md`, `LICENSE`, tests, docs, and any
  installer it needs. Do not put symlinks inside a plugin directory; the
  validator rejects them.

## mark.hardware-monitor

This plugin is the CPU/GPU/NPU bar widget and panel.

- Telemetry comes from a local **TopsWatch** daemon over
  `http://127.0.0.1:9876`. TopsWatch is a separate project and is not vendored
  (it currently has no upstream license file). The plugin is Apache-2.0;
  `Sparkline.qml` retains the MIT attribution for the adapted code.
- Installer: `scripts/install-topswatch.sh` delegates to
  `dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.hardware-monitor/install/install-topswatch.sh`.
  It builds a pinned TopsWatch revision, installs a hardened systemd unit, and
  binds the API to loopback. Run it only with user approval.
- Tests:

  ```bash
  cd dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.hardware-monitor
  node --test tests/model.test.js
  ```

- Manifest validation:

  ```bash
  omarchy plugin validate dotfiles/omarchy-plugins/.config/omarchy/plugins/mark.hardware-monitor
  ```

- Service checks:

  ```bash
  systemctl status topswatch
  journalctl -u topswatch -n 50 --no-pager
  curl -s http://127.0.0.1:9876/api/metrics/latest | head -c 200
  ```

- After UI changes, restart the shell, inspect the bar and panel, and update
  `docs/panel.png` when the layout changes.
- Useful IPC:

  ```bash
  quickshell ipc -p /usr/share/omarchy/shell call mark.hardware-monitor toggle
  quickshell ipc -p /usr/share/omarchy/shell call mark.hardware-monitor toggleCard gpu
  quickshell ipc -p /usr/share/omarchy/shell call mark.hardware-monitor refresh
  ```

## Validation checklist

Before calling a change done:

1. `bash -n` any changed shell scripts; run `shellcheck` if available.
2. `omarchy plugin validate <plugin-dir>` for plugin changes.
3. Run the relevant tests (`node --test ...`).
4. Restart or rescan the shell, check the journal for QML errors, and inspect
   the bar/panel visually.
5. `git status` and `git diff`; stage only the intended paths.

## Commits

- Imperative subject, short body, one logical change.
- Stage explicit paths. Do not stage unrelated untracked files such as
  `opencode.jsonc`, `readme.org`, `references/`, or local troubleshooting notes.
- Commit on `quatro`.

## Omarchy skill

`.agents/skills/omarchy/SKILL.md` is the end-user Omarchy customization skill.
Use it when changing live system config under `~/.config/`; it is not a
substitute for this repository's development conventions. In particular, this
repo is quattro/Quickshell, not the v3 Waybar/Walker setup described by parts of
that skill.
