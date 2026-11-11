import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mark.bar-drawer"

  // The scoped PluginBarApi facade does not expose the widget catalogue.
  // A companion service receives a detached catalogue snapshot from the
  // shell; the drawer resolves it through its own scoped shell facade.
  property var drawerService: null
  readonly property var hostBar: root.bar
  readonly property var registryWidgets: drawerService && drawerService.barWidgetRegistry
    ? drawerService.barWidgetRegistry.widgets : ({})

  readonly property color foreground: hostBar ? hostBar.barForeground : Commons.Color.foreground
  readonly property string fontFamily: hostBar ? hostBar.fontFamily : Style.font.family

  function resolveService() {
    var service = root.bar && root.bar.shell ? root.bar.shell.serviceFor("mark.bar-drawer") : null
    if (service && drawerService !== service) drawerService = service
  }

  function entryId(entry) {
    if (typeof entry === "string") return entry
    if (entry && entry.id !== undefined && entry.id !== null) return String(entry.id)
    return ""
  }

  function entrySettings(entry) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) return ({})
    var copy = {}
    for (var key in entry) if (key !== "id") copy[key] = entry[key]
    return copy
  }

  Timer {
    id: serviceResolveTimer
    interval: 100
    repeat: true
    running: !root.drawerService
    onTriggered: root.resolveService()
  }

  onBarChanged: resolveService()
  Component.onCompleted: {
    resolveService()
    Qt.callLater(resolveService)
  }

  // Settings & Configuration
  readonly property var defaultItems: [
    "io.github.kristoferlund.webcam",
    "mark.hardware-monitor",
    "omarchy.bluetooth",
    "omarchy.tailscale",
    "omarchy.monitor"
  ]
  readonly property var configuredItems: {
    var s = root.settings
    var list = s && s.items ? s.items : setting("items", null)
    if (list instanceof Array && list.length > 0) return list
    return defaultItems
  }
  readonly property int animationDuration: Math.max(50, Math.min(2000, setting("animationDuration", 350)))
  readonly property string chevronPosition: setting("chevronPosition", "left")
  readonly property bool chevronOnLeft: chevronPosition !== "right"
  readonly property bool showTrayIcons: {
    var value = setting("showTrayIcons", "On")
    if (typeof value === "boolean") return value
    var text = String(value).toLowerCase()
    return text !== "off" && text !== "false" && text !== "0"
  }

  // Native tray items rendered inside the drawer. Passive items are not
  // surfaced anywhere; everything else (Steam, chat clients, ...) appears
  // before the folded bar widgets.
  readonly property var trayItems: {
    if (!showTrayIcons) return []
    var values = SystemTray.items ? SystemTray.items.values : []
    var result = []
    for (var i = 0; i < values.length; i++) {
      var item = values[i]
      if (!item || item.status === Status.Passive) continue
      result.push(item)
    }
    return result
  }
  readonly property int trayItemExtent: Style.bar.iconSlot

  function trayIconSource(icon) {
    return String(icon || "")
  }

  function iconIsSymbolic(icon) {
    var name = String(icon || "").split("?")[0]
    return name.slice(-9) === "-symbolic"
  }

  function trayTooltip(item) {
    return item ? (item.tooltipTitle || item.title || item.id || "") : ""
  }

  // State
  readonly property bool defaultExpanded: {
    var value = setting("defaultExpanded", false)
    if (typeof value === "boolean") return value
    var text = String(value).toLowerCase()
    return text !== "off" && text !== "false" && text !== "0"
  }
  readonly property bool expandOnHover: {
    var value = setting("expandOnHover", true)
    if (typeof value === "boolean") return value
    var text = String(value).toLowerCase()
    return text !== "off" && text !== "false" && text !== "0"
  }
  readonly property int collapseDelay: Math.max(0, Math.min(2000, Number(setting("collapseDelay", 300))))

  property bool expanded: defaultExpanded
  readonly property bool opened: expanded
  property real revealProgress: expanded ? 1.0 : 0.0

  // Click targets owned by drawer children. While collapsed they sit outside
  // the visible drawer but still overlap neighbouring bar slots, so the host
  // bar's global click-target scan would route clicks on audio/network/power
  // into a hidden drawer child. Suppress them until the drawer opens again.
  property var suppressedTargets: []
  property var trayButtons: []

  function registerTrayButton(button) {
    if (!button || trayButtons.indexOf(button) !== -1) return
    var next = trayButtons.slice()
    next.push(button)
    trayButtons = next
  }

  function unregisterTrayButton(button) {
    trayButtons = trayButtons.filter(function(item) { return item !== button })
  }

  function firstTrayButton() {
    for (var i = 0; i < trayButtons.length; i++) {
      if (trayButtons[i] && trayButtons[i].active) return trayButtons[i]
    }
    return null
  }

  Behavior on revealProgress {
    NumberAnimation {
      duration: root.animationDuration
      easing.type: Easing.OutCubic
    }
  }

  // Tray menu state
  property bool trayMenuOpen: false
  property var activeTrayItem: null
  property var activeTrayAnchor: null
  // Submenu drill-down. QsMenuEntry.display() needs QApplication mode, which
  // omarchy's shell does not use, so nested entries are rendered by their own
  // QsMenuOpener inside the same card.
  property var submenuStack: []
  readonly property int submenuDepth: submenuStack.length
  readonly property string currentTitle: submenuDepth > 0 ? submenuStack[submenuDepth - 1].title : ""
  readonly property var currentChildren: submenuDepth > 0
    ? submenuStack[submenuDepth - 1].opener.children
    : trayMenuOpener.children
  property bool menuLevelSettling: false

  Component {
    id: submenuOpenerComponent
    QsMenuOpener {}
  }

  Timer {
    id: menuLevelSettleTimer
    interval: 250
    onTriggered: root.menuLevelSettling = false
  }

  function settleMenuLevel() {
    menuLevelSettling = true
    menuLevelSettleTimer.restart()
  }

  function resetTrayMenu() {
    menuLevelSettling = false
    menuLevelSettleTimer.stop()
    if (typeof trayMenuFlick !== "undefined" && trayMenuFlick) trayMenuFlick.contentY = 0
    // Clear the reactive stack before tearing anything down, so no binding can
    // read a partially-destroyed opener while this runs. Destroy deepest first:
    // an inner opener's entry is owned by its parent's children model.
    var openers = submenuStack
    submenuStack = []
    for (var i = openers.length - 1; i >= 0; i--) {
      if (openers[i] && openers[i].opener) openers[i].opener.destroy()
    }
  }

  function enterSubmenu(entry, title) {
    var opener = submenuOpenerComponent.createObject(root, { menu: entry })
    if (!opener) return
    var stack = submenuStack.slice()
    stack.push({ opener: opener, title: title })
    submenuStack = stack
    settleMenuLevel()
  }

  function leaveSubmenu() {
    if (submenuStack.length === 0) return
    var stack = submenuStack.slice()
    var top = stack.pop()
    submenuStack = stack
    top.opener.destroy()
    settleMenuLevel()
  }

  function closeTrayMenu() {
    if (!trayMenuOpen) return
    trayMenuOpen = false
    if (!drawerHover.hovered) collapseTimer.restart()
  }

  function openTrayMenu(item, anchorItem, mouse) {
    if (!item) return
    if (!item.menu) {
      if (anchorItem && anchorItem.QsWindow) {
        var localX = mouse ? mouse.x : anchorItem.width / 2
        var localY = mouse ? mouse.y : anchorItem.height
        var point = anchorItem.QsWindow.contentItem.mapFromItem(anchorItem, localX, localY)
        item.display(anchorItem.QsWindow.window, point.x, point.y)
      }
      return
    }

    // Reset before switching items: trayMenuOpener.menu binds to
    // activeTrayItem.menu, so assigning a new item invalidates the old root's
    // children before nested openers referencing them are torn down.
    resetTrayMenu()
    activeTrayItem = item
    activeTrayAnchor = anchorItem
    trayMenuOpen = true
  }

  function hasOpenChildPopout() {
    if (trayMenuOpen) return true
    var popout = root.hostBar ? root.hostBar.activePopout : null
    return !!(popout && root.isChildItem(popout))
  }

  function hasOpenChildPanel() {
    var repeater = layoutLoader.item ? layoutLoader.item.repeater : null
    if (!repeater) return false
    for (var i = 0; i < repeater.count; i++) {
      var slot = repeater.itemAt(i)
      if (slot && slot.activeItem && slot.activeItem.opened === true) return true
    }
    return false
  }

  // Hover opens the drawer; the chevron remains clickable for keyboard/mouse
  // users and for keeping it open while the pointer is elsewhere.
  HoverHandler {
    id: drawerHover

    onHoveredChanged: {
      if (hovered) {
        collapseTimer.stop()
        if (root.expandOnHover) root.expanded = true
      } else if (root.expandOnHover) {
        collapseTimer.restart()
      }
    }
  }

  Timer {
    id: collapseTimer
    interval: root.collapseDelay
    repeat: false
    onTriggered: {
      if (!root.hasOpenChildPopout() && !root.hasOpenChildPanel()) root.expanded = false
    }
  }

  readonly property string chevronIcon: {
    if (chevronOnLeft) {
      return expanded ? "󰅂" : "󰅁"
    } else {
      return expanded ? "󰅁" : "󰅂"
    }
  }

  readonly property real contentExtent: layoutLoader.item ? layoutLoader.item.contentExtent : 0
  readonly property real revealExtent: Math.round(contentExtent * revealProgress)

  implicitWidth: root.vertical ? root.barSize : (layoutLoader.item ? layoutLoader.item.implicitWidth : Style.bar.iconSlot)
  implicitHeight: root.vertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight : Style.bar.iconSlot) : root.barSize

  function toggleLocal() {
    expanded = !expanded
  }

  function expandLocal() {
    expanded = true
  }

  function collapseLocal() {
    expanded = false
  }

  function toggle() {
    toggleLocal()
  }

  function expand() {
    expandLocal()
  }

  function collapse() {
    collapseLocal()
  }

  function open() {
    expandLocal()
  }

  function close() {
    closeTrayMenu()
    collapseLocal()
  }

  function isChildItem(item) {
    if (!item) return false
    var repeater = layoutLoader.item ? layoutLoader.item.repeater : null
    if (!repeater) return false
    for (var i = 0; i < repeater.count; i++) {
      var slot = repeater.itemAt(i)
      if (slot && slot.activeItem === item) return true
    }
    return false
  }

  // Walk the visual parent chain to decide whether a click target lives inside
  // the clipped drawer content (and not in the always-visible chevron).
  function isInDrawerContent(item) {
    if (!item) return false
    try {
      for (var p = item; p; p = p.parent) {
        if (p.drawerContentHost === true) return true
      }
    } catch (e) {
    }
    return false
  }

  function suppressContentClickTargets() {
    var bar = root.hostBar
    if (!bar || root.expanded) return
    var current = bar.clickTargets ? bar.clickTargets.slice() : []
    var suppressed = root.suppressedTargets.slice()
    for (var i = 0; i < current.length; i++) {
      var target = current[i]
      if (!target || !root.isInDrawerContent(target)) continue
      if (suppressed.indexOf(target) === -1) suppressed.push(target)
      bar.unregisterClickTarget(target)
    }
    root.suppressedTargets = suppressed
  }

  function restoreContentClickTargets() {
    var bar = root.hostBar
    var suppressed = root.suppressedTargets
    root.suppressedTargets = []
    if (!bar) return
    for (var i = 0; i < suppressed.length; i++) {
      var target = suppressed[i]
      if (!target) continue
      try {
        if (root.isInDrawerContent(target)) bar.registerClickTarget(target)
      } catch (e) {
      }
    }
  }

  Connections {
    target: root.hostBar
    ignoreUnknownSignals: true

    function onClickTargetsChanged() {
      // Children register asynchronously while loading; keep pruning until the
      // drawer opens. Unregistering re-emits clickTargetsChanged, but the
      // accumulated list means the second pass finds nothing new.
      if (!root.expanded) root.suppressContentClickTargets()
    }
  }

  // Auto-expand when a nested child popout opens
  Connections {
    target: root.hostBar
    ignoreUnknownSignals: true

    function onActivePopoutChanged() {
      if (root.hostBar && root.hostBar.activePopout && root.isChildItem(root.hostBar.activePopout)) {
        if (!root.expanded) root.expandLocal()
      } else if (!root.hasOpenChildPopout() && !root.hasOpenChildPanel() && !drawerHover.hovered) {
        collapseTimer.restart()
      }
    }
  }

  // Close child popouts and the tray menu when the drawer collapses.
  onExpandedChanged: {
    if (expanded) {
      restoreContentClickTargets()
      return
    }
    closeTrayMenu()
    suppressContentClickTargets()
    if (root.hostBar && root.hostBar.activePopout && root.isChildItem(root.hostBar.activePopout)) {
      if (typeof root.hostBar.activePopout.close === "function") {
        root.hostBar.activePopout.close()
      }
    }
  }

  IpcHandler {
    target: "mark.bar-drawer"

    function toggle(): string {
      root.broadcast("toggleLocal")
      return root.expanded ? "expanded" : "collapsed"
    }

    function expand(): string {
      root.broadcast("expandLocal")
      return "expanded"
    }

    function collapse(): string {
      root.broadcast("collapseLocal")
      return "collapsed"
    }

    function trayMenu(): string {
      root.expandLocal()
      var button = root.firstTrayButton()
      if (!button) return "no tray icon"
      button.displayMenu(null)
      return "opened"
    }

    function status(): string {
      var repeater = layoutLoader.item ? layoutLoader.item.repeater : null
      var itemsDebug = []
      if (repeater) {
        for (var i = 0; i < repeater.count; i++) {
          var slot = repeater.itemAt(i)
          if (!slot) {
            itemsDebug.push({ index: i, slotNull: true })
            continue
          }
          itemsDebug.push({
            index: i,
            entry: slot.entry,
            moduleName: slot.moduleName,
            registered: slot.registered,
            hasComponent: slot.registryComponent !== null,
            loaderStatus: slot.loaderStatus,
            loaderError: slot.loaderError,
            hasActiveItem: slot.activeItem !== null,
            itemVisible: slot.activeItem ? slot.activeItem.visible : null,
            itemImplicitWidth: slot.activeItem ? slot.activeItem.implicitWidth : null,
            slotImplicitWidth: slot.implicitWidth,
            slotWidth: slot.width,
            slotVisible: slot.visible
          })
        }
      }
      var trayDebug = []
      for (var t = 0; t < root.trayItems.length; t++) {
        var trayItem = root.trayItems[t]
        trayDebug.push({
          id: trayItem.id,
          title: trayItem.title,
          status: trayItem.status,
          onlyMenu: trayItem.onlyMenu,
          hasMenu: !!trayItem.menu
        })
      }
      return JSON.stringify({
        expanded: root.expanded,
        contentExtent: root.contentExtent,
        revealExtent: root.revealExtent,
        revealProgress: root.revealProgress,
        implicitWidth: root.implicitWidth,
        width: root.width,
        visible: root.visible,
        hasBar: root.bar !== null,
        hasHostBar: root.hostBar !== null,
        hasService: root.drawerService !== null,
        hasRegistry: !!(root.drawerService && root.drawerService.barWidgetRegistry),
        registryWidgetsCount: Object.keys(root.registryWidgets).length,
        layoutLoaderItem: layoutLoader.item !== null,
        repeaterCount: repeater ? repeater.count : -1,
        suppressedTargets: root.suppressedTargets.length,
        ownedClickTargets: root.hostBar && root.hostBar.clickTargets ? root.hostBar.clickTargets.length : -1,
        trayMenuOpen: root.trayMenuOpen,
        activeTrayItem: root.activeTrayItem ? String(root.activeTrayItem.id || "") : "",
        submenuDepth: root.submenuDepth,
        trayCount: root.trayItems.length,
        trayButtons: root.trayButtons.length,
        trayPopupVisible: trayMenuPopup.visible,
        trayPopupWidth: trayMenuPopup.implicitWidth,
        trayPopupHeight: trayMenuPopup.implicitHeight,
        trayPopupHasWindow: !!(trayMenuPopup.anchorWindow),
        trayAnchorHasWindow: !!(root.activeTrayAnchor && root.activeTrayAnchor.QsWindow && root.activeTrayAnchor.QsWindow.window),
        trayItems: trayDebug,
        items: itemsDebug
      })
    }
  }

  Loader {
    id: layoutLoader
    anchors.fill: parent
    sourceComponent: root.vertical ? verticalLayout : horizontalLayout
  }

  Component {
    id: horizontalLayout

    Item {
      id: hRoot

      readonly property real contentExtent: {
        var rowWidth = contentRow.implicitWidth
        if (rowWidth > 0) return rowWidth
        var total = 0
        if (childSlotsRepeater) {
          for (var i = 0; i < childSlotsRepeater.count; i++) {
            var slot = childSlotsRepeater.itemAt(i)
            if (slot && slot.implicitWidth > 0) total += slot.implicitWidth
          }
        }
        return total
      }
      readonly property alias repeater: childSlotsRepeater

      implicitWidth: toggleButton.implicitWidth + clipContainer.width
      implicitHeight: root.barSize
      anchors.fill: parent

      BarIconButton {
        id: toggleButton
        bar: root.hostBar
        x: root.chevronOnLeft ? 0 : clipContainer.width
        anchors.verticalCenter: parent.verticalCenter
        text: root.chevronIcon
        tooltipText: root.expanded ? "Collapse drawer" : "Expand drawer"
        onPressed: function(button) {
          if (button === Qt.LeftButton) {
            root.toggleLocal()
          } else if (button === Qt.RightButton) {
            root.broadcast("toggleLocal")
          }
        }
      }

      Item {
        id: clipContainer
        property bool drawerContentHost: true
        x: root.chevronOnLeft ? toggleButton.implicitWidth : 0
        anchors.verticalCenter: parent.verticalCenter
        width: root.revealExtent
        height: root.barSize
        clip: true
        opacity: root.revealProgress
        enabled: root.expanded

        Row {
          id: contentRow
          x: root.chevronOnLeft ? 0 : (root.revealExtent - hRoot.contentExtent)
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Repeater {
            model: root.trayItems
            TrayButton {}
          }

          Repeater {
            id: childSlotsRepeater
            model: root.configuredItems

            DrawerChildSlot {
              required property var modelData
              entry: modelData
            }
          }
        }
      }
    }
  }

  Component {
    id: verticalLayout

    Item {
      id: vRoot

      readonly property real contentExtent: {
        var colHeight = contentCol.implicitHeight
        if (colHeight > 0) return colHeight
        var total = 0
        if (childSlotsRepeater) {
          for (var i = 0; i < childSlotsRepeater.count; i++) {
            var slot = childSlotsRepeater.itemAt(i)
            if (slot && slot.implicitHeight > 0) total += slot.implicitHeight
          }
        }
        return total
      }
      readonly property alias repeater: childSlotsRepeater

      implicitWidth: root.barSize
      implicitHeight: toggleButton.implicitHeight + clipContainer.height
      anchors.fill: parent

      BarIconButton {
        id: toggleButton
        bar: root.hostBar
        y: root.chevronOnLeft ? 0 : clipContainer.height
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.chevronIcon
        textRotation: 90
        tooltipText: root.expanded ? "Collapse drawer" : "Expand drawer"
        onPressed: function(button) {
          if (button === Qt.LeftButton) {
            root.toggleLocal()
          } else if (button === Qt.RightButton) {
            root.broadcast("toggleLocal")
          }
        }
      }

      Item {
        id: clipContainer
        property bool drawerContentHost: true
        y: root.chevronOnLeft ? toggleButton.implicitHeight : 0
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.barSize
        height: root.revealExtent
        clip: true
        opacity: root.revealProgress
        enabled: root.expanded

        Column {
          id: contentCol
          y: root.chevronOnLeft ? 0 : (root.revealExtent - vRoot.contentExtent)
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 0

          Repeater {
            model: root.trayItems
            TrayButton {}
          }

          Repeater {
            id: childSlotsRepeater
            model: root.configuredItems

            DrawerChildSlot {
              required property var modelData
              entry: modelData
            }
          }
        }
      }
    }
  }

  component TrayButton: Item {
    id: trayButton

    required property var modelData
    property var registeredBar: null

    readonly property bool active: !!modelData && modelData.status !== Status.Passive
    readonly property bool onlyMenu: !!modelData && modelData.onlyMenu === true
    readonly property bool tooltipHovered: visible && opacity > 0 && trayMouse.containsMouse

    // Shape consumed by Bar.moduleClickTargetAt(): the bar's slot MouseArea
    // routes left clicks here instead of to the drawer itself.
    property bool interactive: true
    property bool pressable: true
    property bool concealed: false

    visible: active
    implicitWidth: active ? root.trayItemExtent : 0
    implicitHeight: active ? root.trayItemExtent : 0
    width: implicitWidth
    height: implicitHeight

    function displayMenu(mouse) {
      root.openTrayMenu(modelData, trayButton, mouse)
    }

    function triggerPress(button) {
      if (!active) return
      if (button === Qt.LeftButton) {
        if (onlyMenu) displayMenu(null)
        else modelData.activate()
      }
    }

    function syncClickRegistration() {
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(trayButton)
      registeredBar = null
      if (!trayButton.active) return
      registeredBar = root.hostBar
      if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(trayButton)
    }

    onActiveChanged: syncClickRegistration()
    Component.onCompleted: {
      root.registerTrayButton(trayButton)
      syncClickRegistration()
    }
    Component.onDestruction: {
      root.unregisterTrayButton(trayButton)
      if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(trayButton)
    }

    Connections {
      target: root
      ignoreUnknownSignals: true
      function onHostBarChanged() { trayButton.syncClickRegistration() }
    }

    DrawerTrayIcon {
      anchors.centerIn: parent
      width: Style.space(12)
      height: Style.space(12)
      icon: trayButton.modelData ? trayButton.modelData.icon : ""
    }

    MouseArea {
      id: trayMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.hostBar) root.hostBar.showTooltip(trayButton, root.trayTooltip(trayButton.modelData))
      onExited: if (root.hostBar) root.hostBar.hideTooltip(trayButton)
      onPressed: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          trayButton.displayMenu(mouse)
          mouse.accepted = true
        }
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.RightButton) {
          mouse.accepted = true
        } else if (mouse.button === Qt.MiddleButton) {
          trayButton.modelData.secondaryActivate()
        } else if (trayButton.onlyMenu) {
          trayButton.displayMenu(mouse)
        } else {
          trayButton.modelData.activate()
        }
      }
      onWheel: function(wheel) {
        trayButton.modelData.scroll(wheel.angleDelta.y, false)
      }
    }
  }

  // Renders a tray icon, recoloring symbolic icons to the bar foreground so
  // they stay visible on any theme.
  component DrawerTrayIcon: Item {
    id: trayIconRoot
    required property var icon
    readonly property bool symbolic: root.iconIsSymbolic(icon)

    Image {
      id: trayIconImage
      anchors.fill: parent
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      sourceSize.height: Math.round(Math.min(width, height) * Screen.devicePixelRatio)
      source: root.trayIconSource(trayIconRoot.icon)
      visible: !trayIconRoot.symbolic
      layer.enabled: trayIconRoot.symbolic
    }

    MultiEffect {
      anchors.fill: trayIconImage
      source: trayIconImage
      visible: trayIconRoot.symbolic
      colorization: 1.0
      colorizationColor: root.foreground
    }
  }

  component DrawerChildSlot: Item {
    id: slotRoot

    required property var entry
    property string region: "right"
    readonly property real widgetWidth: 0
    readonly property real widgetHeight: 0
    readonly property string moduleName: root.entryId(entry)
    readonly property var moduleSettings: root.entrySettings(entry)
    readonly property var registryComponent: {
      var w = root.registryWidgets
      var registryName = Util.canonicalWidgetId(moduleName)
      return w[registryName] ? w[registryName].component : null
    }
    readonly property bool registered: registryComponent !== null
    readonly property var activeItem: loader.item
    readonly property int loaderStatus: loader.status
    readonly property string loaderError: loader.status === Loader.Error && typeof loader.errorString === "function" ? loader.errorString() : ""
    readonly property bool panelOpen: root.hostBar && root.hostBar.activePopout === activeItem

    readonly property real panelIndicatorExtent: {
      var key = root.vertical ? "openPanelIndicatorHeight" : "openPanelIndicatorWidth"
      var hint = activeItem && key in activeItem ? activeItem[key] : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round((root.vertical ? slotRoot.height : slotRoot.width) * 0.55))
    }

    readonly property real itemExtent: {
      if (!activeItem || activeItem.visible === false) return 0
      var extent = root.vertical ? activeItem.implicitHeight : activeItem.implicitWidth
      if (extent !== undefined && extent !== null && extent > 0) return extent
      return Style.bar.iconSlot
    }

    implicitWidth: root.vertical ? root.barSize : itemExtent
    implicitHeight: root.vertical ? itemExtent : root.barSize
    width: implicitWidth
    height: implicitHeight

    function syncModuleSlot() {
      if (root.hostBar && typeof root.hostBar.registerModuleSlot === "function") {
        root.hostBar.registerModuleSlot(slotRoot)
      }
    }

    Component.onCompleted: syncModuleSlot()
    Component.onDestruction: {
      if (root.hostBar && typeof root.hostBar.unregisterModuleSlot === "function") {
        root.hostBar.unregisterModuleSlot(slotRoot)
      }
    }

    Connections {
      target: root
      function onBarChanged() {
        slotRoot.syncModuleSlot()
        slotRoot.injectProps()
      }
      function onHostBarChanged() {
        slotRoot.syncModuleSlot()
        slotRoot.injectProps()
      }
    }

    // Keep the drawer open while this child's own panel is up, and open the
    // drawer when a panel is summoned from elsewhere.
    Connections {
      target: slotRoot.activeItem
      ignoreUnknownSignals: true

      function onOpenedChanged() {
        if (slotRoot.activeItem && slotRoot.activeItem.opened === true) {
          root.expanded = true
        } else if (!root.hasOpenChildPopout() && !root.hasOpenChildPanel() && !drawerHover.hovered) {
          collapseTimer.restart()
        }
      }
    }

    Loader {
      id: loader
      anchors.fill: parent
      active: slotRoot.registered
      sourceComponent: slotRoot.registered ? slotRoot.registryComponent : null
      onLoaded: {
        slotRoot.injectProps()
        Qt.callLater(slotRoot.injectProps)
      }
    }

    Rectangle {
      id: openPanelIndicator
      readonly property int inset: Style.space(2)
      visible: opacity > 0
      opacity: slotRoot.panelOpen ? 0.9 : 0
      color: Commons.Color.accent
      radius: Math.min(width, height) / 2
      width: root.vertical ? Style.space(2) : slotRoot.panelIndicatorExtent
      height: root.vertical ? slotRoot.panelIndicatorExtent : Style.space(2)
      x: root.vertical
        ? (root.hostBar && root.hostBar.position === "left" ? parent.width - width - inset : inset)
        : Math.round((parent.width - width) / 2)
      y: root.vertical
        ? Math.round((parent.height - height) / 2)
        : (root.hostBar && root.hostBar.position === "top" ? parent.height - height - inset : inset)
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    onActiveItemChanged: Qt.callLater(injectProps)
    onModuleSettingsChanged: injectProps()

    function injectProps() {
      if (typeof root === "undefined" || !root) return
      var target = activeItem
      if (!target) return
      if ("fixedEdge" in target && "fixedEdge" in root) target.fixedEdge = root.fixedEdge
      if ("bar" in target) target.bar = root.hostBar
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }
  }

  // PopupCard dismisses through owner.close() on an outside click. The drawer
  // itself is the owner, matching the native tray widget: closing the menu
  // then collapses the drawer as any other outside click would.
  QsMenuOpener {
    id: trayMenuOpener
    menu: root.activeTrayItem ? root.activeTrayItem.menu : null
  }

  PopupCard {
    id: trayMenuPopup
    anchorItem: root.activeTrayAnchor || root
    owner: root
    bar: root.hostBar
    open: root.trayMenuOpen
    // The card fades out over 140ms, so wait until it is fully hidden before
    // swapping a live submenu for the root menu.
    onVisibleChanged: if (!visible) root.resetTrayMenu()
    padding: Style.space(8)
    borderColor: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.45)
    contentWidth: trayMenuPopup.fittedContentWidth(Style.space(232))
    contentHeight: trayMenuPopup.fittedContentHeight(menuHeaderHeight + trayMenuColumn.implicitHeight, Style.space(420))

    readonly property int menuHeaderHeight: menuHeader.visible ? menuHeader.implicitHeight : 0

    Column {
      id: trayMenuLayout
      anchors.fill: parent
      spacing: 0

      Column {
        id: menuHeader
        visible: root.submenuDepth > 0
        width: trayMenuLayout.width
        spacing: 0

        Item {
          id: menuBackRow
          width: menuHeader.width
          implicitHeight: Style.space(30)

          Rectangle {
            anchors.fill: parent
            radius: Math.max(2, Style.cornerRadius)
            color: backMouse.containsMouse ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: Style.space(22)
            horizontalAlignment: Text.AlignHCenter
            text: "\u2039"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Style.space(28)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            text: root.currentTitle
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.menuLevelSettling) return
              trayMenuFlick.contentY = 0
              root.leaveSubmenu()
            }
          }
        }

        Item {
          width: menuHeader.width
          implicitHeight: Style.space(11)

          Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(10)
            anchors.right: parent.right
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Commons.Color.popups.border
            opacity: 0.45
          }
        }
      }

      Flickable {
        id: trayMenuFlick
        width: trayMenuLayout.width
        height: trayMenuLayout.height - trayMenuPopup.menuHeaderHeight
        contentWidth: width
        contentHeight: trayMenuColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: trayMenuColumn
          width: trayMenuFlick.width
          spacing: 0

          Repeater {
            model: root.currentChildren

            delegate: Item {
              id: menuRow
              required property var modelData
              required property int index

              readonly property string rowText: String(modelData.text || "")
              readonly property string activeTitle: root.activeTrayItem ? String(root.activeTrayItem.title || root.activeTrayItem.id || "") : ""
              readonly property bool atRoot: root.submenuDepth === 0
              readonly property bool rootTitleEntry: atRoot && index === 0 && modelData.hasChildren && rowText.toLowerCase() === activeTitle.toLowerCase()
              readonly property bool leadingSeparator: atRoot && modelData.isSeparator && index <= 1
              readonly property bool hiddenRow: rootTitleEntry || leadingSeparator

              visible: !hiddenRow
              width: trayMenuColumn.width
              implicitHeight: hiddenRow ? 0 : (modelData.isSeparator ? Style.space(11) : Style.space(30))
              opacity: modelData.enabled ? 1.0 : 0.45

              Rectangle {
                visible: menuRow.modelData.isSeparator
                anchors.left: parent.left
                anchors.leftMargin: Style.space(10)
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Commons.Color.popups.border
                opacity: 0.45
              }

              Rectangle {
                visible: !menuRow.modelData.isSeparator
                anchors.fill: parent
                radius: Math.max(2, Style.cornerRadius)
                color: rowMouse.containsMouse && menuRow.modelData.enabled ? Style.hoverFillFor(root.foreground, root.foreground) : "transparent"
              }

              Text {
                textFormat: Text.PlainText
                visible: !menuRow.modelData.isSeparator && menuRow.modelData.buttonType !== QsMenuButtonType.None
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                text: menuRow.modelData.checkState === Qt.Checked ? "\uf00c" : ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Image {
                id: menuIcon
                visible: !menuRow.modelData.isSeparator && String(menuRow.modelData.icon || "") !== ""
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Style.space(24)
                width: Style.space(16)
                height: Style.space(16)
                fillMode: Image.PreserveAspectFit
                sourceSize.width: width * Screen.devicePixelRatio
                sourceSize.height: height * Screen.devicePixelRatio
                source: menuRow.modelData.icon
              }

              Text {
                textFormat: Text.PlainText
                visible: !menuRow.modelData.isSeparator
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: menuIcon.visible ? Style.space(46) : Style.space(28)
                anchors.right: submenuGlyph.left
                anchors.rightMargin: Style.space(8)
                text: menuRow.rowText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              Text {
                id: submenuGlyph
                visible: !menuRow.modelData.isSeparator && menuRow.modelData.hasChildren
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                text: "\u203a"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              MouseArea {
                id: rowMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !menuRow.modelData.isSeparator && menuRow.modelData.enabled
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (root.menuLevelSettling) return
                  if (menuRow.modelData.hasChildren) {
                    trayMenuFlick.contentY = 0
                    root.enterSubmenu(menuRow.modelData, menuRow.rowText)
                  } else {
                    menuRow.modelData.triggered()
                    root.closeTrayMenu()
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
