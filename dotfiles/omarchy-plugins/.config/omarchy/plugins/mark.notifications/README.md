# mark.notifications

Local clone of Omarchy's `omarchy.notifications` service plugin.

Cloned with:

```bash
omarchy plugin clone omarchy.notifications
```

## Local change

Notification popups are shown only on the monitor Hyprland has focused, and a
visible toast stack follows focus when the user moves to another monitor.
Upstream draws one popup layer surface per output and binds them all to the
same popup model, which duplicates every toast on every screen.

The change is confined to `Service.qml`:

- `focusedScreenName` resolves the output name from `Hyprland.focusedMonitor`,
  falling back to the first screen until Hyprland reports focus.
- Each per-output `PanelWindow` is visible only when its `modelData.name`
  matches `focusedScreenName`.

Everything else (DND, history, persistence, actions, replay) is upstream code.

## Updating

When Omarchy updates the built-in notification service, diff it against this
clone and re-apply the focused-monitor change:

```bash
diff -ru /usr/share/omarchy/shell/plugins/notifications \
  ~/.config/omarchy/plugins/mark.notifications
```

If the upstream version has changed substantially, re-clone it and port the
two changes instead of merging by hand.
