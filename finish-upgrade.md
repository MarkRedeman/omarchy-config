# Finishing the quattro upgrade

Runbook as executed on 2026-08-23, after `omarchy-upgrade-to-quattro` had run
(2026-08-22) on Omarchy **4.0.0.alpha** / Hyprland **0.56.2**, staying on the
local `test` branch (which contains `origin/quatro` merged in).

## TL;DR

The two non-obvious bits that cost us time:

1. **hy3 must be installed rev-locked.** Its manifest has no commit pin for
   Hyprland 0.56.x patch releases, so an unpinned build uses master, which
   targets Hyprland git-master header paths and fails to compile against the
   installed 0.56.2 headers (upstream: [outfoxxed/hy3#324]).
2. **After enabling the plugin, run `hyprpm update`.** Until then Hyprland
   doesn't register the plugin for the Lua config and every
   `hl.plugin.hy3.…` reference dies with
   `attempt to index a nil value (local 'hy3')`.

[outfoxxed/hy3#324]: https://github.com/outfoxxed/hy3/issues/324

## 1. Repo

```bash
git fetch origin
git merge origin/quatro        # test already tracks the quattro work
```

## 2. Install hy3 (rev-locked)

```bash
hyprpm remove hy3                                       # only needed once, clears the failed entry
hyprpm add https://github.com/outfoxxed/hy3 0f32517     # last rev targeting the 0.56 release API
hyprpm enable hy3
hyprpm update                                           # ← registers the plugin with the Lua config
```

`0f32517` is "fixup: chase 0.56.0" — verified to compile cleanly against the
exact installed headers when master would not. Re-check whether upstream has
pinned/tagged a newer Hyprland release before bumping; `scripts/deploy.sh`
pins the same rev via `HY3_REV`.

## 3. Remove legacy v3 leftovers

```bash
find ~/.config/hypr -xtype l -delete   # dangling links: hyprland.conf, envs.conf,
                                       # looknfeel.conf, omarchy-defaults.conf,
                                       # plugins.conf, lock-and-clear-gpg.sh, shaders/*
rm ~/.config/hypr/autostart.conf ~/.config/hypr/bindings.conf \
   ~/.config/hypr/hypridle.conf ~/.config/hypr/input.conf \
   ~/.config/hypr/monitors.conf ~/.config/hypr/hypridle.conf.bak.*
```

Kept: `hyprsunset.conf`, `xdph.conf`, `.luarc.json` (still used), and all
`*.omarchy-upgrade-to-quattro.*.bak` snapshots.

## 4. Deploy the dotfiles (GNU Stow)

Full path: run `scripts/deploy.sh` (deps + fonts + pinned hy3 + stow +
fish/tailscale/pass). Stow-only variant:

```bash
dotfiles/hypr/.config/hypr/setup-fonts.sh

for package in dotfiles/*/; do
    stow --adopt --restow --target="$HOME" --dir="$PWD/dotfiles" "$(basename "$package")"
done
git checkout -- dotfiles/          # restore adopted files to committed versions
```

This turns all stock entry points written by the upgrade
(`~/.config/hypr/*.lua`, `~/.config/omarchy/shell.json`,
`~/.config/uwsm/env.d/`) into symlinks to our versions.

## 5. Activate & verify

Log out/in (cleanest for Quickshell + the dwindle→hy3 switch), then:

```bash
hyprctl getoption general:layout   # → str: hy3
hyprctl configerrors               # → empty
hyprctl binds | grep -c bind       # ~276, incl. i3-style hy3 group/focus binds
hyprpm list                        # Plugin hy3 … enabled: true
ls -la ~/.config/hypr/hyprland.lua # symlink into ~/projects/omarchy-config
```

Recovery hatch: if hy3 ever fails to load again after a Hyprland update, flip
`USE_HY3 = false` in `looknfeel.lua` (session falls back to dwindle) and see
QUATRO-MIGRATION.md §3.1.
