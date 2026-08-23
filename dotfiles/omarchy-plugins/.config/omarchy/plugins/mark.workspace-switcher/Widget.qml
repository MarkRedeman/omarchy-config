import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "WorkspacesModel.js" as WorkspacesModel

// Bar chips for mark.workspace-switcher.
//
// Shows only occupied-or-focused workspaces of the focused monitor, styled
// after our v3 waybar bar: plain name labels, unfocused at half opacity,
// focused bold at full opacity. Click focuses; scrolling cycles prev/next
// (monitor-scoped, wrap-around).
//
// Chip logic adapted from murdialthaf/omarchy-named-workspaces (MIT).
BarWidget {
  id: root
  moduleName: "mark.workspace-switcher"

  function records() {
    return WorkspacesModel.list(
      Hyprland.workspaces.values,
      Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
  }

  function focusRecord(record) {
    var command = WorkspacesModel.focusCommand(record)
    if (root.bar && typeof root.bar.run === "function") root.bar.run(command)
    else Util.execDetached(command)
  }

  function cycle(direction) {
    var target = WorkspacesModel.cycle(records(), Hyprland.focusedWorkspace, direction)
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

        readonly property bool focused: WorkspacesModel.sameSpace(modelData, Hyprland.focusedWorkspace)

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
          font.bold: chip.focused
          opacity: chip.focused ? 1 : 0.5
        }
      }
    }
  }
}
