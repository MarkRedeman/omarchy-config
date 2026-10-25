# Bar Drawer

A chevron that folds secondary Omarchy bar widgets into a hover drawer. The
drawer instantiates the real widgets from the host bar's widget registry, so
their popups, services, and IPC handlers keep working while they are tucked
away.

![Bar Drawer](docs/drawer.png)

## Configuration

Add the drawer to a bar section and list the widgets it should contain:

```json
{
  "id": "mark.bar-drawer",
  "items": [
    "io.github.kristoferlund.webcam",
    "mark.hardware-monitor",
    "omarchy.bluetooth",
    "omarchy.tailscale",
    "omarchy.audio",
    "omarchy.monitor"
  ],
  "expandOnHover": "On",
  "collapseDelay": 300,
  "chevronPosition": "left",
  "animationDuration": 300
}
```

The list accepts widget ids or widget definition objects. Widgets in the list
must stay **enabled** so their component is registered:

- First-party widgets (`omarchy.*`) are enabled by default.
- Third-party widgets are enabled only when their id appears in
  `bar.layout.*` or `plugins[]`. If a third-party widget is not in the bar
  layout, add a bare entry to `plugins[]` so the shell keeps its component
  loaded:

```json
"plugins": [
  { "id": "io.github.kristoferlund.webcam" },
  { "id": "mark.hardware-monitor" }
]
```

The drawer loads each child's real component, so clicking the icon opens its
panel and the widget's own IPC target stays registered. Shell-level
`omarchy-shell shell toggle <widget-id>` does not route to drawer children
because they are not bar-section slots; use the icon or the widget's own IPC
target.

## Settings

| Key | Default | Meaning |
|---|---|---|
| `items` | six widgets | Widget ids or definition objects inside the drawer |
| `expandOnHover` | `On` | Open when the pointer enters the chevron |
| `collapseDelay` | `300` | Delay before collapsing after the pointer leaves |
| `chevronPosition` | `left` | Chevron on the left or right of the contents |
| `animationDuration` | `300` | Reveal animation duration in ms |
| `defaultExpanded` | `Off` | Start expanded |

## Controls

- **Hover** the chevron to reveal the drawer; move away to collapse it.
- **Left-click** the chevron to toggle it.
- **Right-click** the chevron to toggle every monitor's drawer.
- Child panels keep the drawer open; close the panel before the drawer can collapse.

## IPC

```bash
quickshell ipc -p /usr/share/omarchy/shell call mark.bar-drawer toggle
quickshell ipc -p /usr/share/omarchy/shell call mark.bar-drawer expand
quickshell ipc -p /usr/share/omarchy/shell call mark.bar-drawer collapse
quickshell ipc -p /usr/share/omarchy/shell call mark.bar-drawer status
```

## Attribution

Adapted from [nertwork/omarchy-drawer](https://github.com/nertwork/omarchy-drawer)
(MIT), with hover behavior and local defaults.

## License

MIT. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
