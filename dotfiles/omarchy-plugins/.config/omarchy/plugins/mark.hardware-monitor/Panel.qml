import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// mark.hardware-monitor
//
// A native Omarchy bar widget and panel for CPU / GPU / NPU utilization.
// The collector is TopsWatch over its local HTTP API; the source adapter
// lives in SourceTopsWatch.qml and the panel only consumes the normalized
// snapshot from Metrics.qml. A future local/sysfs source can be added
// without changing this file.
Panel {
  id: root

  moduleName: "mark.hardware-monitor"
  ipcTarget: "mark.hardware-monitor"
  manageIpc: false

  // ---------------------------------------------------------- theme

  readonly property color foreground: Color.popups.text
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.68)
  readonly property color trackColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.12)
  readonly property color chartGrid: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.16)
  readonly property color warningColor: Qt.tint(accent, Qt.rgba(urgent.r, urgent.g, urgent.b, 0.6))
  readonly property color secondary: Qt.tint(accent, Qt.rgba(foreground.r, foreground.g, foreground.b, 0.35))
  readonly property color tertiary: Qt.tint(accent, Qt.rgba(urgent.r, urgent.g, urgent.b, 0.35))
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false

  // ---------------------------------------------------------- settings

  readonly property string barMode: String(setting("barMode", "All"))
  readonly property string endpoint: String(setting("endpoint", "http://127.0.0.1:9876"))
  readonly property int closedRefreshMs: Math.max(2000, Number(setting("closedRefreshSec", 5)) * 1000)
  readonly property int openRefreshMs: Math.max(1000, Number(setting("openRefreshSec", 1)) * 1000)
  readonly property real criticalThreshold: Math.max(Number(setting("critPercent", 95)), 61)
  readonly property real warningThreshold: Math.min(Number(setting("warnPercent", 80)), criticalThreshold - 1)

  // The manifest uses enum On/Off for booleans so the settings UI never has
  // to know a type the shell does not currently expose. Accept real booleans
  // too, for hand-edited shell.json entries.
  function boolSetting(name, fallback) {
    var value = setting(name, fallback ? "On" : "Off")
    if (typeof value === "boolean") return value
    var text = String(value).toLowerCase()
    return text !== "off" && text !== "false" && text !== "0"
  }

  property bool enginesExpanded: boolSetting("showEngines", true)
  property bool chartExpanded: boolSetting("showChart", true)
  property bool powerExpanded: boolSetting("showPower", true)

  function persistSetting(name, value) {
    var next = Object.assign({}, settings)
    next[name] = value
    settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, settings)
  }

  // ---------------------------------------------------------- data

  Metrics {
    id: metrics
    endpoint: root.endpoint
    panelOpen: root.opened
    closedRefreshMs: root.closedRefreshMs
    openRefreshMs: root.openRefreshMs
  }

  readonly property var snapshot: metrics.snapshot
  readonly property bool hasGpu: metrics.hasGpu
  readonly property bool hasNpu: metrics.hasNpu
  readonly property int headlineCount: 1 + (hasGpu ? 1 : 0) + (hasNpu ? 1 : 0)
  readonly property real headlineWidth: Math.max(0, (panelColumn.width - Style.space(8) * (headlineCount - 1)) / headlineCount)

  // ---------------------------------------------------------- bar

  readonly property bool iconOnly: barMode === "Icon"
  readonly property bool useSegments: !root.vertical && !root.iconOnly && root.barMode === "All"

  readonly property var barSegments: {
    var out = []
    out.push({ key: "cpu", label: "C", value: snapshot.cpu.utilization })
    if (hasGpu) out.push({ key: "gpu", label: "G", value: snapshot.gpu.utilization })
    if (hasNpu) out.push({ key: "npu", label: "N", value: snapshot.npu.utilization })
    return out
  }

  function levelColor(value) {
    if (!isFinite(value) || value < 0) return muted
    if (value >= criticalThreshold) return urgent
    if (value >= warningThreshold) return warningColor
    return accent
  }

  function segmentActive(value) {
    return isFinite(value) && value >= warningThreshold
  }

  function segmentActiveColor(value) {
    return isFinite(value) && value >= criticalThreshold ? urgent : warningColor
  }

  function barLabel() {
    return Model.barLabel(root.snapshot, root.barMode, root.vertical)
  }

  function currentValue() {
    if (root.barMode === "CPU") return root.snapshot.cpu.utilization
    if (root.barMode === "GPU") return root.snapshot.gpu.utilization
    if (root.barMode === "NPU") return root.snapshot.npu.utilization
    return Model.worstMetric(root.snapshot).value
  }

  function tooltipText() {
    var lines = []
    lines.push("CPU " + Model.formatPercent(snapshot.cpu.utilization) +
      (snapshot.cpu.frequency >= 0 ? " · " + Model.formatMHz(snapshot.cpu.frequency) : ""))
    if (hasGpu)
      lines.push("GPU " + Model.formatPercent(snapshot.gpu.utilization) +
        (snapshot.gpu.engines.length > 0 ? " · " + snapshot.gpu.engines.length + " engines" : ""))
    if (hasNpu)
      lines.push("NPU " + Model.formatPercent(snapshot.npu.utilization))
    if (snapshot.cpu.power >= 0)
      lines.push("Package " + Model.formatWatts(snapshot.cpu.power))
    lines.push(metrics.status === "online" && !metrics.stale
      ? "TopsWatch · updated " + ageText()
      : "TopsWatch offline · click for details")
    lines.push("Click for details · Right-click cycles")
    return lines.join("\n")
  }

  function ageText() {
    if (!metrics.hasData) return "never"
    var seconds = Math.max(0, Math.round((Date.now() - metrics.lastUpdated) / 1000))
    if (seconds < 2) return "now"
    if (seconds < 60) return seconds + "s ago"
    return Math.round(seconds / 60) + "m ago"
  }

  function cycleBarMode() {
    var modes = ["All", "CPU"]
    if (hasGpu) modes.push("GPU")
    if (hasNpu) modes.push("NPU")
    modes.push("Worst", "Icon")
    var index = modes.indexOf(barMode)
    var next = modes[(index + 1) % modes.length]
    persistSetting("barMode", next)
  }

  function barPressed(button) {
    if (button === Qt.RightButton) cycleBarMode()
    else if (button === Qt.MiddleButton) launchBtop()
    else toggle()
  }

  function anchorItem() {
    if (useSegments) return segmentRow
    if (iconOnly) return iconButton
    return singleButton
  }

  Row {
    id: segmentRow
    visible: root.useSegments
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 0
    opacity: metrics.status === "online" && !metrics.stale ? 1 : 0.55

    Repeater {
      model: root.barSegments

      WidgetButton {
        required property var modelData
        bar: root.bar
        text: modelData.label + Model.padPercent(modelData.value)
        fontSize: Style.font.caption
        horizontalMargin: Style.spaceReal(3)
        active: root.segmentActive(modelData.value)
        activeColor: root.segmentActiveColor(modelData.value)
        tooltipText: root.tooltipText()
        onPressed: function(button) { root.barPressed(button) }
      }
    }
  }

  WidgetButton {
    id: singleButton
    visible: !root.useSegments && !root.iconOnly
    anchors.fill: parent
    bar: root.bar
    text: root.barLabel()
    fontSize: Style.font.caption
    horizontalMargin: 6
    opacity: metrics.status === "online" && !metrics.stale ? 1 : 0.55
    active: root.currentValue() >= root.warningThreshold
    activeColor: root.currentValue() >= root.criticalThreshold ? root.urgent : root.warningColor
    tooltipText: root.tooltipText()
    onPressed: function(button) { root.barPressed(button) }
  }

  BarIconButton {
    id: iconButton
    visible: root.iconOnly
    anchors.fill: parent
    bar: root.bar
    text: "󰻠"
    opacity: metrics.status === "online" && !metrics.stale ? 1 : 0.55
    active: root.currentValue() >= root.warningThreshold
    activeColor: root.currentValue() >= root.criticalThreshold ? root.urgent : root.warningColor
    tooltipText: root.tooltipText()
    onPressed: function(button) { root.barPressed(button) }
  }

  implicitWidth: root.useSegments
    ? segmentRow.implicitWidth
    : (root.iconOnly ? iconButton.implicitWidth : singleButton.implicitWidth)
  implicitHeight: root.useSegments
    ? segmentRow.implicitHeight
    : (root.iconOnly ? iconButton.implicitHeight : singleButton.implicitHeight)

  // ---------------------------------------------------------- panel helpers

  function percent(value, digits) {
    return Model.formatPercent(value, digits === undefined ? 0 : digits)
  }

  function deviceMeta() {
    var devices = snapshot.devices || {}
    var cpuName = devices.cpu && devices.cpu.name ? String(devices.cpu.name) : ""
    var topology = Model.coreTypeSummary(devices)
    var gpuDriver = devices.gpu && devices.gpu.extra && devices.gpu.extra.driver
      ? String(devices.gpu.extra.driver) : ""
    var parts = []
    if (cpuName !== "") parts.push(cpuName.replace("Intel(R) Core(TM) ", ""))
    if (topology !== "") parts.push(topology)
    if (gpuDriver !== "") parts.push(gpuDriver)
    return parts.join(" · ")
  }

  function sourceBadge() {
    if (metrics.status === "offline") return "OFFLINE"
    if (metrics.status === "starting") return "STARTING"
    if (metrics.stale) return "STALE"
    return "TOPSWATCH"
  }

  function cpuTileDetail() {
    var parts = []
    if (snapshot.cpu.coresUsed >= 0)
      parts.push(snapshot.cpu.coresUsed.toFixed(1) + " cores")
    if (snapshot.cpu.frequency >= 0)
      parts.push(Model.formatMHz(snapshot.cpu.frequency))
    return parts.length > 0 ? parts.join(" · ") : "No CPU data"
  }

  function gpuTileDetail() {
    var parts = []
    if (snapshot.gpu.engines.length > 0)
      parts.push(snapshot.gpu.engines.length + " engines")
    if (snapshot.gpu.frequency >= 0)
      parts.push(Model.formatMHz(snapshot.gpu.frequency))
    return parts.length > 0 ? parts.join(" · ") : "No GPU data"
  }

  function npuTileDetail() {
    var parts = []
    if (snapshot.npu.frequency >= 0)
      parts.push(Model.formatMHz(snapshot.npu.frequency))
    if (snapshot.npu.power >= 0)
      parts.push(Model.formatWatts(snapshot.npu.power))
    if (parts.length === 0 && snapshot.npu.memoryPercent >= 0)
      parts.push("mem " + Model.formatPercent(snapshot.npu.memoryPercent, 1))
    return parts.length > 0 ? parts.join(" · ") : "No NPU data"
  }

  function mediaFreqText() {
    return snapshot.gpu.mediaFrequency >= 0
      ? "media " + Model.formatMHz(snapshot.gpu.mediaFrequency)
      : ""
  }

  function utilSeries() {
    var out = []
    out.push({ points: metrics.history.cpu, color: accent })
    if (hasGpu) out.push({ points: metrics.history.gpu, color: secondary })
    if (hasNpu) out.push({ points: metrics.history.npu, color: tertiary })
    return out
  }

  function powerSummary() {
    if (snapshot.cpu.power >= 0) return "package " + Model.formatWatts(snapshot.cpu.power)
    if (snapshot.power.battery.discharging) return "on battery"
    return ""
  }

  function openWebUI() {
    var command = "xdg-open " + endpoint
    if (bar && typeof bar.run === "function") bar.run(command)
    else Util.execDetached(command)
  }

  function launchBtop() {
    var command = "omarchy-launch-or-focus-tui btop"
    if (bar && typeof bar.run === "function") bar.run(command)
    else Util.execDetached(command)
    close()
  }

  onOpenedChanged: {
    if (opened) {
      enginesExpanded = boolSetting("showEngines", true)
      chartExpanded = boolSetting("showChart", true)
      powerExpanded = boolSetting("showPower", true)
      metrics.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { metrics.refresh(); return "ok" }
    function cycle(): string { root.cycleBarMode(); return root.barMode }
  }

  // ---------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem()
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        var flick = scrollArea.contentItem
        if (!flick) return
        var maxY = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(maxY, flick.contentY + dy * Style.space(24)))
      }
      onTextKey: function(text) {
        var key = String(text).toLowerCase()
        if (key === "r") metrics.refresh()
        else if (key === "e") root.enginesExpanded = !root.enginesExpanded
        else if (key === "w") root.openWebUI()
        else if (key === "b") root.launchBtop()
      }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: panelColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

        Column {
          id: panelColumn
          width: scrollArea.availableWidth
          spacing: Style.space(9)

          PanelHero {
            width: parent.width
            title: "Hardware"
            meta: root.deviceMeta()
            detail: root.sourceBadge()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰻠"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Row {
                spacing: Style.space(4)
                PanelActionButton {
                  iconText: "󰑐"
                  tooltipText: "Refresh (R)"
                  foreground: root.foreground
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: metrics.refresh()
                }
                PanelActionButton {
                  iconText: "󰖟"
                  tooltipText: "Open TopsWatch web UI (W)"
                  foreground: root.foreground
                  hoverColor: root.accent
                  fontFamily: root.fontFamily
                  onClicked: root.openWebUI()
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // Offline / stale banner. It sits above the data so the last good
          // sample remains readable while explaining why it is old.
          BorderSurface {
            width: parent.width
            visible: metrics.status !== "online" || metrics.stale
            color: Style.normalFillFor(root.foreground, root.urgent)
            borderSpec: Border.controlSpec("normal", root.foreground, root.urgent)
            radius: Style.cornerRadius
            implicitHeight: statusColumn.implicitHeight + Style.space(16)

            Column {
              id: statusColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(8)
              spacing: Style.space(3)

              Text {
                width: parent.width
                text: metrics.status === "offline"
                  ? "TopsWatch is not reachable at " + root.endpoint
                  : (metrics.stale ? "Showing the last sample from " + root.ageText() : "Waiting for TopsWatch…")
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.Wrap
              }

              Text {
                width: parent.width
                visible: metrics.status !== "online" && metrics.error !== ""
                text: metrics.error
                textFormat: Text.PlainText
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }

              Text {
                width: parent.width
                visible: metrics.status === "offline"
                text: "Start it with: sudo systemctl start topswatch"
                textFormat: Text.PlainText
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }

              Text {
                width: parent.width
                visible: metrics.status === "offline"
                text: "Not installed? See the plugin README or run install/install-topswatch.sh."
                textFormat: Text.PlainText
                color: root.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }
            }
          }

          // Headline tiles.
          Row {
            width: parent.width
            spacing: Style.space(8)

            StatTile {
              width: root.headlineWidth
              title: "CPU"
              value: root.percent(root.snapshot.cpu.utilization)
              detail: root.cpuTileDetail()
              meter: root.snapshot.cpu.utilization
              meterColor: root.levelColor(root.snapshot.cpu.utilization)
              alarming: root.snapshot.cpu.utilization >= root.criticalThreshold
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              fontFamily: root.fontFamily
            }

            StatTile {
              width: root.headlineWidth
              visible: root.hasGpu
              title: "GPU"
              value: root.percent(root.snapshot.gpu.utilization)
              detail: root.gpuTileDetail()
              meter: root.snapshot.gpu.utilization
              meterColor: root.levelColor(root.snapshot.gpu.utilization)
              alarming: root.snapshot.gpu.utilization >= root.criticalThreshold
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              fontFamily: root.fontFamily
            }

            StatTile {
              width: root.headlineWidth
              visible: root.hasNpu
              title: "NPU"
              value: root.percent(root.snapshot.npu.utilization)
              detail: root.npuTileDetail()
              meter: root.snapshot.npu.utilization
              meterColor: root.levelColor(root.snapshot.npu.utilization)
              alarming: root.snapshot.npu.utilization >= root.criticalThreshold
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              fontFamily: root.fontFamily
            }
          }

          // Utilization history.
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.chartExpanded

            SectionHeading {
              title: "UTILIZATION"
              value: "2 MIN"
            }

            Item {
              width: parent.width
              height: Style.space(62)

              Sparkline {
                anchors.fill: parent
                series: root.utilSeries()
                fixedMaximum: 100
                gridColor: root.chartGrid
                windowMs: 120000
              }
            }

            Row {
              spacing: Style.space(10)

              LegendDot { colorValue: root.accent; label: "CPU" }
              LegendDot { colorValue: root.secondary; label: "GPU"; visible: root.hasGpu }
              LegendDot { colorValue: root.tertiary; label: "NPU"; visible: root.hasNpu }
            }
          }

          // GPU engine breakdown.
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.enginesExpanded && root.hasGpu && root.snapshot.gpu.engines.length > 0

            SectionHeading {
              title: "GPU ENGINES"
              value: root.mediaFreqText()
            }

            Repeater {
              model: root.snapshot.gpu.engines

              EngineRow {
                width: parent.width
                label: modelData.label
                description: modelData.description
                value: modelData.value
                meterColor: root.levelColor(modelData.value)
              }
            }
          }

          // CPU detail.
          Column {
            width: parent.width
            spacing: Style.space(3)
            visible: root.snapshot.hasCpu

            SectionHeading {
              title: "CPU"
              value: Model.coreTypeSummary(root.snapshot.devices)
            }

            DetailRow {
              label: "Frequency"
              value: Model.formatMHz(root.snapshot.cpu.frequency)
              visible: root.snapshot.cpu.frequency >= 0
            }
            DetailRow {
              label: "Power"
              value: Model.formatWatts(root.snapshot.cpu.power)
              visible: root.snapshot.cpu.power >= 0
            }
            DetailRow {
              label: "Temperature"
              value: Model.formatTemperature(root.snapshot.cpu.temperature)
              visible: root.snapshot.cpu.temperature >= 0
            }
            DetailRow {
              label: "Memory"
              value: Model.formatBytes(root.snapshot.cpu.memoryUsed) + " / " + Model.formatBytes(root.snapshot.cpu.memoryTotal)
              visible: root.snapshot.cpu.memoryTotal > 0
              meter: root.snapshot.cpu.memoryPercent
              meterColor: root.levelColor(root.snapshot.cpu.memoryPercent)
            }
          }

          // GPU detail.
          Column {
            width: parent.width
            spacing: Style.space(3)
            visible: root.hasGpu

            SectionHeading {
              title: "GPU"
              value: root.snapshot.devices.gpu && root.snapshot.devices.gpu.extra
                ? String(root.snapshot.devices.gpu.extra.driver || "")
                : ""
            }

            DetailRow {
              label: "Frequency"
              value: root.snapshot.gpu.frequency >= 0
                ? Model.formatMHz(root.snapshot.gpu.frequency) +
                  (root.snapshot.gpu.frequencyMax >= 0 ? " / " + Model.formatMHz(root.snapshot.gpu.frequencyMax) : "")
                : "—"
            }
            DetailRow {
              label: "Media clock"
              value: Model.formatMHz(root.snapshot.gpu.mediaFrequency)
              visible: root.snapshot.gpu.mediaFrequency >= 0
            }
            DetailRow {
              label: "Power"
              value: Model.formatWatts(root.snapshot.gpu.power)
              visible: root.snapshot.gpu.power >= 0
            }
            DetailRow {
              label: "Temperature"
              value: Model.formatTemperature(root.snapshot.gpu.temperature)
              visible: root.snapshot.gpu.temperature >= 0
            }
            DetailRow {
              label: "Memory"
              value: Model.formatBytes(root.snapshot.gpu.memoryUsed)
              visible: root.snapshot.gpu.memoryUsed >= 0
            }
          }

          // NPU detail.
          Column {
            width: parent.width
            spacing: Style.space(3)
            visible: root.hasNpu

            SectionHeading {
              title: "NPU"
              value: root.snapshot.devices.npu && root.snapshot.devices.npu.extra
                ? String(root.snapshot.devices.npu.extra.generation || "").toUpperCase()
                : ""
            }

            DetailRow {
              label: "Frequency"
              value: Model.formatMHz(root.snapshot.npu.frequency)
              visible: root.snapshot.npu.frequency >= 0
            }
            DetailRow {
              label: "Power"
              value: Model.formatWatts(root.snapshot.npu.power)
              visible: root.snapshot.npu.power >= 0
            }
            DetailRow {
              label: "Temperature"
              value: Model.formatTemperature(root.snapshot.npu.temperature)
              visible: root.snapshot.npu.temperature >= 0
            }
            DetailRow {
              label: "DDR bandwidth"
              value: Model.formatRate(root.snapshot.npu.ddrBandwidth)
              visible: root.snapshot.npu.ddrBandwidth >= 0
            }
            DetailRow {
              label: "Memory"
              value: Model.formatBytes(root.snapshot.npu.memoryUsed) + " / " + Model.formatBytes(root.snapshot.npu.memoryTotal)
              visible: root.snapshot.npu.memoryTotal > 0
              meter: root.snapshot.npu.memoryPercent
              meterColor: root.levelColor(root.snapshot.npu.memoryPercent)
            }
            DetailRow {
              label: "Tile config"
              value: root.snapshot.npu.tileConfig >= 0 ? String(root.snapshot.npu.tileConfig) : "—"
              visible: root.snapshot.npu.tileConfig >= 0
            }
          }

          // Power domains.
          Column {
            width: parent.width
            spacing: Style.space(3)
            visible: root.powerExpanded && (root.snapshot.power.domains.length > 0 || root.snapshot.power.battery.capacity >= 0)

            SectionHeading {
              title: "POWER"
              value: root.powerSummary()
            }

            Repeater {
              model: root.snapshot.power.domains

              DetailRow {
                width: parent.width
                label: modelData.domain
                value: Model.formatWatts(modelData.watts)
              }
            }

            DetailRow {
              label: "Battery"
              value: root.snapshot.power.battery.capacity >= 0
                ? root.snapshot.power.battery.capacity + "%" +
                  (root.snapshot.power.battery.discharging ? " · discharging" : "")
                : "—"
              visible: root.snapshot.power.battery.capacity >= 0
              meter: root.snapshot.power.battery.capacity
              meterColor: root.snapshot.power.battery.capacity < 20 ? root.urgent : root.accent
            }
          }

          // Active TopsWatch warnings.
          Column {
            width: parent.width
            spacing: Style.space(3)
            visible: root.snapshot.warnings.length > 0

            SectionHeading {
              title: "WARNINGS"
              value: String(root.snapshot.warnings.length)
            }

            Repeater {
              model: root.snapshot.warnings

              BorderSurface {
                width: parent.width
                implicitHeight: warningText.implicitHeight + Style.space(12)
                color: Style.normalFillFor(root.foreground, root.urgent)
                borderSpec: Border.controlSpec("normal", root.foreground, root.urgent)
                radius: Style.cornerRadius

                Text {
                  id: warningText
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(6)
                  text: modelData.message
                  textFormat: Text.PlainText
                  color: modelData.severity === "critical" ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.Wrap
                }
              }
            }
          }

          // Footer.
          PanelSeparator { foreground: root.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(footerText.implicitHeight, footerButtons.implicitHeight)

            Text {
              id: footerText
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - footerButtons.width - Style.space(8)
              text: metrics.status === "online" && !metrics.stale
                ? "TopsWatch · " + root.ageText() + " · " + root.endpoint
                : "TopsWatch · offline · " + root.endpoint
              textFormat: Text.PlainText
              color: root.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              id: footerButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              PanelActionButton {
                iconText: "󰑐"
                tooltipText: "Refresh (R)"
                foreground: root.foreground
                hoverColor: root.accent
                fontFamily: root.fontFamily
                onClicked: metrics.refresh()
              }
              PanelActionButton {
                iconText: "󰖟"
                tooltipText: "Open TopsWatch web UI (W)"
                foreground: root.foreground
                hoverColor: root.accent
                fontFamily: root.fontFamily
                onClicked: root.openWebUI()
              }
              PanelActionButton {
                iconText: "󰆍"
                tooltipText: "Open btop (B)"
                foreground: root.foreground
                hoverColor: root.accent
                fontFamily: root.fontFamily
                onClicked: root.launchBtop()
              }
            }
          }
        }
      }
    }
  }

  // ---------------------------------------------------------- inline components

  component SectionHeading: Item {
    property string title: ""
    property string value: ""

    width: parent ? parent.width : 0
    implicitHeight: Math.max(headingText.implicitHeight, valueText.implicitHeight)

    PanelSectionHeader {
      id: headingText
      text: title
      textFormat: Text.PlainText
      foreground: root.foreground
      fontFamily: root.fontFamily
      elide: Text.ElideRight
      anchors.left: parent.left
      anchors.right: valueText.visible ? valueText.left : parent.right
      anchors.rightMargin: valueText.visible ? Style.space(8) : 0
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      id: valueText
      text: value
      visible: text !== ""
      textFormat: Text.PlainText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      elide: Text.ElideRight
      width: Math.min(implicitWidth, parent.width * 0.62)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
    }
  }

  component Meter: Rectangle {
    id: meter
    property real value: -1
    property color fillColor: root.accent

    height: Style.space(3)
    radius: height / 2
    color: root.trackColor

    Rectangle {
      width: meter.width * Math.max(0, Math.min(1, meter.value / 100))
      height: meter.height
      radius: meter.radius
      color: meter.fillColor

      Behavior on width {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }
    }
  }

  component DetailRow: Column {
    id: row
    property string label: ""
    property string value: "—"
    property real meter: -1
    property color meterColor: root.accent

    width: parent ? parent.width : 0
    spacing: Style.space(3)

    Item {
      width: parent.width
      implicitHeight: Math.max(labelText.implicitHeight, valueText.implicitHeight)

      Text {
        id: labelText
        text: row.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: valueText
        text: row.value
        textFormat: Text.PlainText
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      visible: row.meter >= 0
      value: row.meter
      fillColor: row.meterColor
    }
  }

  component EngineRow: Column {
    id: engine
    property string label: ""
    property string description: ""
    property real value: -1
    property color meterColor: root.accent

    width: parent ? parent.width : 0
    spacing: Style.space(3)

    Item {
      width: parent.width
      implicitHeight: Math.max(engineLabel.implicitHeight, engineValue.implicitHeight)

      Row {
        id: engineLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        Text {
          text: engine.label
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          text: engine.description
          textFormat: Text.PlainText
          visible: text !== ""
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        id: engineValue
        text: Model.formatPercent(engine.value, 1)
        textFormat: Text.PlainText
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      value: engine.value
      fillColor: engine.meterColor
    }
  }

  component LegendDot: Row {
    property color colorValue: root.accent
    property string label: ""

    spacing: Style.space(4)

    Rectangle {
      width: Style.space(6)
      height: width
      radius: width / 2
      color: parent.colorValue
    }

    Text {
      text: parent.label
      textFormat: Text.PlainText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
