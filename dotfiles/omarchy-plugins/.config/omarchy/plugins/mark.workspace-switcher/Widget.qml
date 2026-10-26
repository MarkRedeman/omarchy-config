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

  // The bar's empty space between the left modules and the centred clock is
  // covered by Omarchy's CenterGestureArea, a full-bar MouseArea that already
  // receives wheel events but has no wheel handler. Attach to that signal and
  // claim only the empty left side, so presentation scrolling works in the
  // gap while the clock and right-hand widgets keep their own wheel
  // behaviour. Nothing is added to the scene, so clicks, hover and bar
  // dragging behave exactly as before.
  readonly property var barWindow: root.QsWindow ? root.QsWindow.window : null
  property var barWheelTarget: null
  property real centerLeftX: -1

  function findCenterGestureArea(item, win) {
    if (!item || !item.children) return null
    for (var i = item.children.length - 1; i >= 0; i--) {
      var child = item.children[i]
      if (!child || !child.visible) continue
      if (child.wheel && Math.abs(child.width - win.width) < 1
          && Math.abs(child.height - win.height) < 1)
        return child
      var found = root.findCenterGestureArea(child, win)
      if (found) return found
    }
    return null
  }

  // Left edge of the centred module cluster. Wheel events to its left fall in
  // the empty presentation area; to its right belong to the clock/indicators
  // and the right-hand widgets. The cluster sits in the middle of the bar, so
  // modules found there are the centre ones, not the left or right section.
  function findCenterLeftX(win) {
    var left = win.width / 2
    var found = false

    function walk(item) {
      if (!item || !item.children) return
      for (var i = 0; i < item.children.length; i++) {
        var child = item.children[i]
        if (!child || !child.visible) continue
        if (child.moduleName && child.width > 0) {
          var point = child.mapToItem(win.contentItem, 0, 0)
          if (point.x > win.width * 0.25 && point.x < win.width * 0.75
              && (!found || point.x < left)) {
            left = point.x
            found = true
          }
        }
        walk(child)
      }
    }

    walk(win.contentItem)
    return found ? left : win.width / 2
  }

  function detachBarWheel() {
    if (barWheelTarget && barWheelTarget.wheel)
      barWheelTarget.wheel.disconnect(root.onBarWheel)
    barWheelTarget = null
  }

  function attachBarWheel() {
    root.detachBarWheel()
    var win = root.barWindow
    var target = win ? root.findCenterGestureArea(win.contentItem, win) : null
    if (!target || !target.wheel) return
    root.centerLeftX = root.findCenterLeftX(win)
    target.wheel.connect(root.onBarWheel)
    barWheelTarget = target
    // The centre modules may not be laid out yet when the widget first loads.
    // Re-read their position once the current event-loop turn has settled.
    Qt.callLater(function() {
      if (root.barWindow === win) root.centerLeftX = root.findCenterLeftX(win)
    })
  }

  function onBarWheel(wheel) {
    // CenterGestureArea spans the whole bar. Only claim the empty left side;
    // the chips have their own handler, and the clock/right widgets keep the
    // wheel for themselves.
    if (!root.vertical && root.centerLeftX > 0
        && wheel.x >= root.centerLeftX - Style.spaceReal(1))
      return
    root.cycle(wheel.angleDelta.y > 0 ? "prev" : "next")
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: row.implicitWidth + trailingGap
  implicitHeight: root.barSize

  onBarWindowChanged: {
    root.detachBarWheel()
    Qt.callLater(root.attachBarWheel)
  }

  // The bar rebuilds its modules when the layout changes; re-find the
  // gesture area after that instead of holding a connection to a dead item.
  Connections {
    target: root.bar
    function onLayoutConfigChanged() { Qt.callLater(root.attachBarWheel) }
  }

  Component.onCompleted: Qt.callLater(root.attachBarWheel)
  Component.onDestruction: root.detachBarWheel()

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
