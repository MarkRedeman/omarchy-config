import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WorkspacesModel.js" as WorkspacesModel

// Bar chips for mark.workspace-switcher.
//
// Shows only occupied-or-active workspaces of the monitor this bar surface
// lives on, styled after our v3 waybar bar: plain name labels, inactive at
// half opacity, active bold at full opacity. Click focuses; scrolling cycles
// prev/next on the same monitor (wrap-around).
//
// Chip logic adapted from murdialthaf/omarchy-named-workspaces (MIT).
BarWidget {
  id: root
  moduleName: "mark.workspace-switcher"

  // One bar window is created per screen, so the widget's own window tells us
  // which monitor to list. The bar host does not pass the monitor through its
  // facade, hence the QsWindow attached property. Until the backing window is
  // mapped, fall back to the focused monitor so chips never flash empty.
  readonly property string monitorName: {
    var win = root.QsWindow ? root.QsWindow.window : null
    var screen = win ? win.screen : null
    var name = screen ? String(screen.name || "") : ""
    if (name !== "") return name
    return Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
  }

  readonly property var monitor: {
    var values = Hyprland.monitors.values
    for (var i = 0; i < values.length; i++) {
      if (values[i] && String(values[i].name || "") === root.monitorName) return values[i]
    }
    return null
  }

  // The workspace currently displayed on this monitor — not the globally
  // focused one, which belongs to whichever monitor has keyboard focus.
  readonly property var visibleWorkspace: root.monitor && root.monitor.activeWorkspace
    ? root.monitor.activeWorkspace : Hyprland.focusedWorkspace

  function records() {
    var list = WorkspacesModel.list(Hyprland.workspaces.values, root.monitorName)
    // Unknown screen name (should not happen: Wayland output names match
    // Hyprland monitor names). Keep the bar useful rather than empty.
    if (list.length === 0 && !root.monitor) {
      return WorkspacesModel.list(
        Hyprland.workspaces.values,
        Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
    }
    return list
  }

  function focusRecord(record) {
    var command = WorkspacesModel.focusCommand(record)
    if (root.bar && typeof root.bar.run === "function") root.bar.run(command)
    else Util.execDetached(command)
  }

  function cycle(direction) {
    var target = WorkspacesModel.cycle(records(), root.visibleWorkspace, direction)
    if (target) focusRecord(target)
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: row.implicitWidth + trailingGap
  implicitHeight: root.barSize

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      root.cycle(event.angleDelta.y > 0 ? "prev" : "next")
    }
  }

  Row {
    id: row
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Repeater {
      model: root.records()

      Item {
        id: chip
        required property var modelData

        readonly property bool active: WorkspacesModel.sameSpace(modelData, root.visibleWorkspace)

        width: label.implicitWidth + Style.space(12)
        height: root.barSize

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.MiddleButton
          onClicked: root.focusRecord(chip.modelData)
        }

        Text {
          id: label
          anchors.centerIn: parent
          text: WorkspacesModel.displayOf(chip.modelData)
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          font.bold: chip.active
          opacity: chip.active ? 1 : 0.5
        }
      }
    }
  }
}
