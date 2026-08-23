import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.Commons
import qs.Ui
import "WorkspacesModel.js" as WorkspacesModel

// Workspace switcher panel for mark.workspace-switcher (SUPER+S).
//
// Mode A only (workspaces): a filter box over all existing workspaces —
// rows carry name, monitor and window count; Enter/click switches; typing a
// query that matches nothing offers "create + switch to" as the last row.
//
// The panel also owns monitor-scoped cycling: keybinds call cycle("next" |
// "prev") through `omarchy-shell shell call mark.workspace-switcher cycle …`.
// Cycling walks existing workspaces of the focused monitor with wrap-around
// and never creates anything.
//
// Opening dismisses any other summoned panel/launcher first — the host has
// no exclusivity of its own, so launchers stack unless a plugin closes its
// siblings (same contract as the built-in popout coordinator).
Item {
  id: root

  // Injected by the shell's panel loader.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property string filterText: ""
  property int selectedIndex: 0
  property bool caretOn: true

  // Shares the [menu] surface tokens so themes that style the launcher also
  // style this panel (same pattern as the clipboard picker).
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int contentSpacing: Style.spacing.md
  readonly property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  readonly property int rowHeight: Math.max(Style.space(40), Style.font.body * 2 + Style.space(8))
  readonly property int maxVisibleRows: 10

  readonly property int cardWidth: Math.min(Style.space(560), 560)

  // ---------------------------------------------------------- row models

  // All existing workspaces across monitors — switching may jump screens.
  readonly property var allRecords: WorkspacesModel.list(Hyprland.workspaces.values, null)

  function matchesQuery(record, query) {
    var hay = (WorkspacesModel.displayOf(record) + " " + record.name + " " + String(record.id)).toLowerCase()
    return hay.indexOf(query) !== -1
  }

  readonly property var matchedRecords: {
    var query = root.filterText.trim().toLowerCase()
    if (query === "") return root.allRecords
    var out = []
    for (var i = 0; i < root.allRecords.length; i++) {
      if (root.matchesQuery(root.allRecords[i], query)) out.push(root.allRecords[i])
    }
    return out
  }

  function exactMatchExists(query) {
    var lowered = query.toLowerCase()
    for (var i = 0; i < root.allRecords.length; i++) {
      var record = root.allRecords[i]
      if (record.name !== "" && record.name.toLowerCase() === lowered) return true
    }
    return false
  }

  // Offer create-and-switch only when the query is not an existing name.
  readonly property bool showCreateRow: root.filterText.trim() !== "" && !root.exactMatchExists(root.filterText.trim())
  readonly property int rowCount: matchedRecords.length + (showCreateRow ? 1 : 0)

  // ------------------------------------------------------- open / close

  function open(payloadJson) {
    // Dismiss every other summoned panel (menu, app picker, clipboard, …)
    // before taking the stage.
    if (root.shell && typeof root.shell.hide === "function") {
      var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
      var openIds = root.shell.openPanelIds || {}
      for (var id in openIds) {
        if (id === self) continue
        try { root.shell.hide(id) } catch (e) { /* panel going away anyway */ }
      }
    }

    root.opened = true
    root.filterText = ""
    root.selectedIndex = root.initialSelection()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (!root.opened) return
    root.opened = false
    // Route through the host so openPanelIds stays consistent (the
    // reentrant close() from hide() is a no-op thanks to the guard above).
    var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
    if (self && root.shell && typeof root.shell.hide === "function") {
      try { root.shell.hide(self) } catch (e) { }
    }
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  // Select the currently focused workspace when opening without a filter,
  // so Enter re-focuses it and Up/Down start from home ground.
  function initialSelection() {
    var index = WorkspacesModel.indexOfFocused(matchedRecords, Hyprland.focusedWorkspace)
    return index === -1 ? 0 : index
  }

  // Bidirectional launcher exclusivity: open() dismisses our siblings, and
  // this watcher handles the reverse direction — if another panel is
  // summoned while we are up (menu, app picker, clipboard, …), step aside.
  // The host keeps no exclusivity of its own, so each side must yield.
  Connections {
    target: root.shell

    function onOpenPanelIdsChanged() {
      if (!root.opened || !root.shell) return
      var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
      var ids = root.shell.openPanelIds || {}
      for (var id in ids) {
        if (id !== self) {
          // Hide through the host (not a local close()) so openPanelIds
          // stays consistent — the reentrant callback is a no-op because
          // opened is false by the time it lands.
          try { root.shell.hide(self) } catch (e) { root.close() }
          return
        }
      }
    }
  }

  // Debug/state probe: `omarchy-shell shell call mark.workspace-switcher status ''`
  function status() {
    return JSON.stringify({
      v: 3,
      opened: root.opened,
      filter: root.filterText,
      rows: root.rowCount,
      selected: root.selectedIndex,
      keyFocus: keyCatcher.activeFocus,
      openPanels: Object.keys((root.shell && root.shell.openPanelIds) || {})
    })
  }

  // ------------------------------------------------------------ actions

  function dispatchRecord(record) {
    Util.execDetached(WorkspacesModel.focusCommand(record))
    root.close()
  }

  function activateIndex(index) {
    if (index < 0 || index >= rowCount) return
    if (showCreateRow && index === matchedRecords.length) {
      createAndSwitch(filterText.trim())
      return
    }
    dispatchRecord(matchedRecords[index])
  }

  function createAndSwitch(name) {
    name = String(name || "").trim()
    if (name === "" || name.indexOf("special:") === 0) return
    var ref = ("name:" + name).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    Util.execDetached("hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + ref + "\" })'")
    root.close()
  }

  // IPC entry point: `omarchy-shell shell call mark.workspace-switcher cycle next|prev`
  function cycle(arg) {
    var direction = arg === "prev" ? "prev" : "next"
    var monitor = Hyprland.focusedMonitor
    var records = WorkspacesModel.list(
      Hyprland.workspaces.values,
      monitor ? monitor.name : "")
    var target = WorkspacesModel.cycle(records, Hyprland.focusedWorkspace, direction)
    if (target) Util.execDetached(WorkspacesModel.focusCommand(target))
  }

  function select(delta) {
    if (rowCount === 0) return
    root.selectedIndex = Math.max(0, Math.min(rowCount - 1, selectedIndex + delta))
  }

  function setFilter(text) {
    root.filterText = text
    // Fresh query: start from the top; open() seeds the focused row instead.
    root.selectedIndex = 0
  }

  // -------------------------------------------------------------- window

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mark-workspace-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: Math.min(
                root.headerHeight + root.contentSpacing
                  + Math.min(root.rowCount, root.maxVisibleRows) * (root.rowHeight + Style.space(4)),
                panel.height - Style.gapsOut * 2)
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.close()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            root.select(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            root.select(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.activateIndex(root.selectedIndex)
            event.accepted = true
          } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }

        Column {
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: root.contentSpacing

        // Filter line: typed query with blinking block-cursor.
        Item {
          width: parent.width
          height: root.headerHeight

          Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.filterText === "" ? "Type to filter or create…" : root.filterText
              color: root.filterText === "" ? Qt.alpha(root.foreground, 0.45) : root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.italic: root.filterText === ""
            }

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(Style.space(3), Style.font.heading / 3)
              height: Style.font.heading
              color: root.foreground
              opacity: root.caretOn ? 1 : 0
              visible: root.opened
            }
          }

          Timer {
            id: caretTimer
            interval: 530
            repeat: true
            running: root.opened
            onTriggered: root.caretOn = !root.caretOn
          }
        }

        // Rows.
        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing
          clip: true

          Column {
            id: rows
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.space(4)

            Repeater {
              model: root.rowCount

              delegate: Rectangle {
                id: rowDelegate
                required property int index

                readonly property bool isCreateRow: root.showCreateRow && index === root.matchedRecords.length
                readonly property var record: isCreateRow ? null : root.matchedRecords[index]
                readonly property bool selected: root.selectedIndex === index
                readonly property bool focusedHere: !isCreateRow && WorkspacesModel.sameSpace(record, Hyprland.focusedWorkspace)

                width: rows.width
                height: root.rowHeight
                radius: root.cornerRadius
                color: selected ? root.selectedBackground : "transparent"

                Text {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  text: rowDelegate.isCreateRow
                        ? "+ Create \u201C" + root.filterText.trim() + "\u201D"
                        : WorkspacesModel.displayOf(rowDelegate.record)
                  color: rowDelegate.selected ? root.selectedText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: rowDelegate.focusedHere
                  elide: Text.ElideRight
                  width: parent.width - Style.space(12) * 2 - badges.width - Style.space(10)
                }

                Row {
                  id: badges
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(12)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rowDelegate.isCreateRow && Hyprland.monitors.values.length > 1
                    text: rowDelegate.record ? rowDelegate.record.monitor : ""
                    color: rowDelegate.selected ? root.selectedText : Qt.alpha(root.foreground, 0.55)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !rowDelegate.isCreateRow && rowDelegate.record.windows > 0
                    text: rowDelegate.record ? rowDelegate.record.windows + "w" : ""
                    color: rowDelegate.selected ? root.selectedText : Qt.alpha(root.foreground, 0.55)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onPositionChanged: root.selectedIndex = rowDelegate.index
                  onClicked: root.activateIndex(rowDelegate.index)
                }
              }
            }

            Item {
              visible: root.rowCount === 0
              width: rows.width
              height: root.rowHeight

              Text {
                anchors.centerIn: parent
                text: "No matching workspaces"
                color: Qt.alpha(root.foreground, 0.45)
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.italic: true
              }
            }
          }
          }
        }
      }
    }
  }
}
