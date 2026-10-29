# mark.notifications

Local clone of Omarchy's `omarchy.notifications` service plugin.

Cloned with:

```bash
omarchy plugin clone omarchy.notifications
```

## Local changes

### Focused-monitor popups

Notification popups are shown only on the monitor Hyprland has focused, and a
visible toast stack follows focus when the user moves to another monitor.
Upstream draws one popup layer surface per output and binds them all to the
same popup model, which duplicates every toast on every screen.

- `focusedScreenName` resolves the output name from `Hyprland.focusedMonitor`,
  falling back to the first screen until Hyprland reports focus.
- Each per-output `PanelWindow` is visible only when its `modelData.name`
  matches `focusedScreenName`.

### Web-app notification lifetimes

Chromium-based web apps (the Teams PWA, Outlook, Gmail, Slack in the browser)
report every web notification as `urgency=critical`, so the stock "critical
never expires" rule pinned every chat message to the screen until it was
dismissed by hand. Native apps that send real critical notifications keep the
old sticky behaviour.

- Critical notifications from native senders stay sticky.
- Critical notifications from Chromium-derived senders get the normal 8s
  lifetime instead.
- A browser notification that looks like a call (`"… is calling you"`,
  `"incoming call"`, `"call from …"`) or carries an Answer/Decline action
  stays sticky.
- `sticky` is decided in `NotificationLogic.isStickyCritical` and persisted
  with the notification, so restored toasts keep the same behaviour.

### Burst handling

- A newer notification from the same app + summary replaces the older visible
  card (one Teams chat = one card).
- The visible stack is capped at 3 toasts; the oldest non-sticky one is
  dismissed into history first. Sticky calls and native criticals are never
  evicted.

### Restore last notification

`omarchy-shell notifications restoreLast` (bound to `SUPER + SHIFT + comma`)
re-shows the most recently dismissed history entry. Repeated calls walk
further back through history, dunst `history-pop` style. A newly arriving
notification resets the walk to the newest entry.

Everything else (DND, history, persistence, actions, replay) is upstream code.

## Updating

When Omarchy updates the built-in notification service, diff it against this
clone and re-apply the local changes:

```bash
diff -ru /usr/share/omarchy/shell/plugins/notifications \
  ~/.config/omarchy/plugins/mark.notifications
```

If the upstream version has changed substantially, re-clone it and port the
localised `Service.qml` changes plus the new functions in
`NotificationLogic.js`. The logic functions are covered by
`tests/notification-logic.test.js`:

```bash
node --test tests/notification-logic.test.js
```
