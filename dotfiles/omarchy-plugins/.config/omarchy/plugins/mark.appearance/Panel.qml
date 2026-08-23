import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

// Appearance panel for mark.appearance (SUPER+ALT+A): gap comfort levels,
// corner rounding, and a theme picker with live preview.
//
// All applies go through omarchy-appearance-set / omarchy-theme-set so the
// state file, Hyprland, and the shell stay in agreement; this UI only ever
// reads state back (FileView watches) and shells out.
Item {
  id: root

  // Injected by the shell's panel loader.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false

  // Appearance state (mirrors ~/.local/state/omarchy/appearance.json).
  property int gap: 0
  property int rounding: 0

  // Both sliders walk powers of two: 0 1 2 4 8 16 32 64 128. The slider is
  // index-based (0..stepCount-1); stepValue()/stepIndexFor() translate.
  readonly property var steps: [0, 1, 2, 4, 8, 16, 32, 64, 128]
  readonly property int stepCount: steps.length

  function stepValue(index) {
    var i = Math.max(0, Math.min(stepCount - 1, Math.round(index)))
    return steps[i]
  }

  function stepIndexFor(value) {
    if (value <= 0) return 0
    return Math.max(1, Math.min(stepCount - 1, Math.round(Math.log2(value)) + 1))
  }

  // Theme state.
  property string currentTheme: ""
  property string pendingTheme: ""

  // Shares the [menu] surface tokens so themes that style the launcher also
  // style this panel.
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

  readonly property int cardWidth: Math.min(Style.space(520), 520)
  readonly property int previewHeight: Style.space(110)
  readonly property string previewsDir: Quickshell.env("HOME") + "/.cache/omarchy/theme-selector/previews"
  readonly property string appliedPreview: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/preview.png"

  // ------------------------------------------------------- theme helpers

  function prettify(id) {
    var parts = String(id || "").split("-")
    for (var i = 0; i < parts.length; i++)
      if (parts[i].length > 0) parts[i] = parts[i][0].toUpperCase() + parts[i].slice(1)
    return parts.join(" ")
  }

  function themeEntry(id) {
    var extensions = ["png", "jpg", "jpeg", "webp", "gif", "bmp"]
    for (var e = 0; e < extensions.length; e++) {
      var candidate = previewsDir + "/" + id + "." + extensions[e]
      if (previewExists[candidate] === true) return "file://" + candidate
    }
    return ""
  }

  readonly property var themeOptions: {
    var out = []
    for (var i = 0; i < themeIds.length; i++) {
      out.push({ value: themeIds[i], label: prettify(themeIds[i]) })
    }
    return out
  }

  // Previewed (pending) or applied theme's image for the header card.
  // previewVersion bumps once the thumbnail scan finishes so bindings that
  // probe previewExists through themeEntry() re-evaluate.
  property int previewVersion: 0

  readonly property string headerPreview: {
    void previewVersion
    var id = pendingTheme !== "" ? pendingTheme : currentTheme
    var fromCache = themeEntry(id)
    if (fromCache !== "") return fromCache
    // The applied theme always has its own rendered preview as a fallback.
    if (id === currentTheme && id !== "") return "file://" + appliedPreview
    return ""
  }

  Component.onCompleted: refreshThemes()

  // -------------------------------------------------------- state files

  function loadAppearance(blob) {
    try {
      var parsed = JSON.parse(blob || "{}")
      root.gap = Math.min(Math.max(parseInt(parsed.gap || 0), 0), 128)
      root.rounding = Math.min(Math.max(parseInt(parsed.rounding || 0), 0), 128)
    } catch (e) { /* keep current values on malformed state */ }
  }

  FileView {
    id: appearanceFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/appearance.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.loadAppearance(text())
    onFileChanged: root.loadAppearance(text())
    onLoadFailed: root.loadAppearance("")
  }

  FileView {
    id: themeNameFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onLoaded: root.currentTheme = text().trim()
    onFileChanged: {
      root.currentTheme = text().trim()
      // A completed apply resolves the pending selection.
      if (root.pendingTheme !== "" && root.pendingTheme === root.currentTheme)
        root.pendingTheme = ""
    }
    onLoadFailed: root.currentTheme = ""
  }

  // One image per theme lives flat in the upstream thumbnail cache;
  // existence probing drives both the dropdown previews and the header.
  property var themeIds: []
  property var previewExists: ({})

  Process {
    id: themeListProcess
    command: ["bash", "-c",
      "omarchy-theme-switcher --preload >/dev/null 2>&1; " +
      "ls -1 '" + root.previewsDir + "' 2>/dev/null"]
    stdout: SplitParser {
      onRead: function(line) {
        var name = String(line || "").trim()
        if (name === "") return
        var dot = name.lastIndexOf(".")
        if (dot === -1) return
        var id = name.slice(0, dot)
        root.previewExists[root.previewsDir + "/" + name] = true
        if (root.themeIds.indexOf(id) === -1) {
          var next = root.themeIds.slice()
          next.push(id)
          next.sort()
          root.themeIds = next
        }
      }
    }

    onExited: root.previewVersion++
  }

  function refreshThemes() {
    themeListProcess.running = true
  }

  // Debug/state probe: `omarchy-shell shell call mark.appearance status ''`
  function status() {
    return JSON.stringify({
      opened: root.opened,
      gap: root.gap,
      rounding: root.rounding,
      theme: root.currentTheme,
      pendingTheme: root.pendingTheme,
      openPanels: Object.keys((root.shell && root.shell.openPanelIds) || {})
    })
  }

  // --------------------------------------------------------------- IPC

  function setGap(value) {
    Util.execDetached("omarchy-appearance-set gap " + value)
    root.gap = value
  }

  function setRounding(value) {
    Util.execDetached("omarchy-appearance-set rounding " + Math.round(value))
    root.rounding = Math.round(value)
  }

  function applyPendingTheme() {
    if (root.pendingTheme === "") return
    Util.execDetached("omarchy-theme-set " + root.pendingTheme)
    notify("Applying theme: " + prettify(root.pendingTheme))
    // themeNameFile's watcher clears pendingTheme once theme.name flips.
  }

  function revertPendingTheme() {
    root.pendingTheme = ""
  }

  function notify(message) {
    Util.execDetached("notify-send 'Appearance' " +
      "'" + message.replace(/'/g, "'\\''") + "' -t 1500")
  }

  // ------------------------------------------------------- open / close

  function open(payloadJson) {
    // Dismiss every other summoned panel before taking the stage.
    if (root.shell && typeof root.shell.hide === "function") {
      var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
      var openIds = root.shell.openPanelIds || {}
      for (var id in openIds) {
        if (id === self) continue
        try { root.shell.hide(id) } catch (e) { }
      }
    }

    root.opened = true
    refreshThemes()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (!root.opened) return
    root.opened = false
    var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
    if (self && root.shell && typeof root.shell.hide === "function") {
      try { root.shell.hide(self) } catch (e) { }
    }
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  // Bidirectional launcher exclusivity (see mark.workspace-switcher).
  Connections {
    target: root.shell

    function onOpenPanelIdsChanged() {
      if (!root.opened || !root.shell) return
      var self = root.manifest && root.manifest.id ? String(root.manifest.id) : ""
      var ids = root.shell.openPanelIds || {}
      for (var id in ids) {
        if (id !== self) {
          try { root.shell.hide(self) } catch (e) { root.close() }
          return
        }
      }
    }
  }

  // -------------------------------------------------------------- window

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mark-appearance"
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
      height: Math.min(content.implicitHeight + root.contentMargin * 2,
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
          if (themeDropdown.popupOpen) return // dropdown owns keys while open
          if (event.key === Qt.Key_Escape) {
            if (root.pendingTheme !== "") root.revertPendingTheme()
            else root.close()
            event.accepted = true
          } else if (event.text === "q") {
            root.close()
            event.accepted = true
          }
        }

        Column {
          id: content
          anchors.fill: parent
          anchors.topMargin: card.contentTopInset
          anchors.rightMargin: card.contentRightInset
          anchors.bottomMargin: card.contentBottomInset
          anchors.leftMargin: card.contentLeftInset
          spacing: root.contentSpacing

          // ============================================== gaps section

          PanelSectionHeader {
            text: "Gaps"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(2)

            Repeater {
              // Presets set the inner gap; the outer gap is always 2x.
              model: [{ label: "i3", value: 0 }, { label: "Comfort", value: 4 }, { label: "Wide", value: 8 }]

              delegate: Button {
                required property var modelData

                readonly property bool isSelected: root.gap === modelData.value

                width: (content.width - Style.space(2) * 2) / 3
                height: Style.spacing.controlHeight
                text: modelData.label
                selected: isSelected
                fontFamily: root.fontFamily
                onClicked: root.setGap(modelData.value)
              }
            }
          }

          Item {
            width: parent.width
            height: Style.spacing.controlHeight

            PanelSlider {
              id: gapSlider
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.rightMargin: Style.space(56)
              minimum: 0
              maximum: root.stepCount - 1
              step: 1
              integer: true
              value: root.stepIndexFor(root.gap)
              fillColor: Color.accent
              knobColor: root.foreground
              trackColor: Qt.alpha(root.foreground, 0.25)

              onMoved: function(index) { gapLabel.text = root.stepValue(index) + " px" }
              onReleased: function(index) { root.setGap(root.stepValue(index)) }
            }

            Text {
              id: gapLabel
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              text: root.gap + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ============================================== corners section

          PanelSectionHeader {
            text: "Corner radius"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Item {
            width: parent.width
            height: Style.spacing.controlHeight

            PanelSlider {
              id: roundingSlider
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.rightMargin: Style.space(56)
              minimum: 0
              maximum: root.stepCount - 1
              step: 1
              integer: true
              value: root.stepIndexFor(root.rounding)
              fillColor: Color.accent
              knobColor: root.foreground
              trackColor: Qt.alpha(root.foreground, 0.25)

              onMoved: function(index) { cornerLabel.text = root.stepValue(index) + " px" }
              onReleased: function(index) { root.setRounding(root.stepValue(index)) }
            }

            Text {
              id: cornerLabel
              anchors.verticalCenter: parent.verticalCenter
              anchors.right: parent.right
              text: root.rounding + " px"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          // ================================================ theme section

          PanelSectionHeader {
            text: "Theme"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          // Current (or previewed) theme card.
          Rectangle {
            width: parent.width
            height: root.previewHeight + Style.space(34)
            radius: root.cornerRadius
            color: Qt.alpha(root.foreground, 0.06)

            Item {
              clip: true
              anchors.fill: parent
              anchors.margins: 1

              Image {
                anchors.fill: parent
                visible: root.headerPreview !== ""
                source: root.headerPreview
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
              }
            }

            Rectangle {
              anchors { left: parent.left; top: parent.left; margins: Style.space(8) }
              width: badgeLabel.implicitWidth + Style.space(12)
              height: Style.space(22)
              radius: Style.space(11)
              visible: root.pendingTheme !== ""
              color: root.selectedBackground

              Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: "Preview — not applied"
                color: root.selectedText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              anchors { left: parent.left; bottom: parent.bottom; margins: Style.space(10) }
              text: {
                var id = root.pendingTheme !== "" ? root.pendingTheme : root.currentTheme
                return root.prettify(id)
              }
              color: "white"
              styleColor: Qt.rgba(0, 0, 0, 0.65)
              style: Text.Outline
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Row {
              anchors { right: parent.right; bottom: parent.bottom; margins: Style.space(8) }
              spacing: Style.space(2)
              visible: root.pendingTheme !== ""

              Button {
                width: Style.space(70)
                height: Style.space(26)
                text: "Apply"
                active: true
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.applyPendingTheme()
              }

              Button {
                width: Style.space(70)
                height: Style.space(26)
                text: "Revert"
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                onClicked: root.revertPendingTheme()
              }
            }
          }

          SearchableDropdown {
            id: themeDropdown
            width: parent.width
            showLabel: false
            placeholderText: "Search themes…"
            value: root.pendingTheme !== "" ? root.pendingTheme : root.currentTheme
            options: root.themeOptions
            foreground: root.foreground
            background: root.background
            popupBorder: root.border
            accent: Color.accent
            fontFamily: root.fontFamily
            hasCursor: true

            onChanged: function(value) {
              if (value === root.currentTheme) root.pendingTheme = ""
              else root.pendingTheme = value
            }
          }

          // Keep a hint that theme applies run the full retint pipeline.
          Text {
            width: parent.width
            text: "Applying re-tints terminals, editors and browsers."
            color: Qt.alpha(root.foreground, 0.45)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }
}
