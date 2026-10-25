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

  readonly property string endpoint: String(setting("endpoint", "http://127.0.0.1:9876"))
  readonly property int closedRefreshMs: Math.max(2000, Number(setting("closedRefreshSec", 5)) * 1000)
  readonly property int openRefreshMs: Math.max(1000, Number(setting("openRefreshSec", 1)) * 1000)
  readonly property real criticalThreshold: Math.max(Number(setting("critPercent", 95)), 61)
  readonly property real warningThreshold: Math.min(Number(setting("warnPercent", 80)), criticalThreshold - 1)

  function boolSetting(name, fallback) {
    var value = setting(name, fallback ? "On" : "Off")
    if (typeof value === "boolean") return value
    var text = String(value).toLowerCase()
    return text !== "off" && text !== "false" && text !== "0"
  }

  property bool chartExpanded: boolSetting("showChart", true)
  property bool showPowerSection: boolSetting("showPower", true)

  // Card state is session-local: expanding a card should not rewrite
  // shell.json on every click.
  property bool cpuExpanded: false
  property bool gpuExpanded: false
  property bool npuExpanded: false
  property bool powerExpanded: false

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
  readonly property int tileCount: (snapshot.hasCpu ? 1 : 0) + (hasGpu ? 1 : 0) + (hasNpu ? 1 : 0)
  readonly property real tileWidth: Math.max(0,
    (panelColumn.width - Style.space(8) * Math.max(0, tileCount - 1)) / Math.max(1, tileCount))

  readonly property bool hasMemory: snapshot.cpu.memoryTotal > 0
  readonly property bool hasPower: showPowerSection &&
    (snapshot.power.domains.length > 0 || snapshot.power.battery.capacity >= 0 || snapshot.cpu.power >= 0)
  readonly property int secondaryTileCount: (hasMemory ? 1 : 0) + (hasPower ? 1 : 0)
  readonly property real secondaryTileWidth: Math.max(0,
    (panelColumn.width - Style.space(8) * Math.max(0, secondaryTileCount - 1)) / Math.max(1, secondaryTileCount))

  // ---------------------------------------------------------- bar

  function worstValue() {
    var value = snapshot.cpu.utilization
    if (snapshot.hasGpu && snapshot.gpu.utilization > value) value = snapshot.gpu.utilization
    if (snapshot.hasNpu && snapshot.npu.utilization > value) value = snapshot.npu.utilization
    return value
  }

  function levelColor(value) {
    if (!isFinite(value) || value < 0) return muted
    if (value >= criticalThreshold) return urgent
    if (value >= warningThreshold) return warningColor
    return accent
  }

  function barPressed(button) {
    if (button === Qt.MiddleButton) return
    if (button === Qt.RightButton) openWebUI()
    else toggle()
  }

  function ageText() {
    if (!metrics.hasData) return "never"
    var seconds = Math.max(0, Math.round((Date.now() - metrics.lastUpdated) / 1000))
    if (seconds < 2) return "now"
    if (seconds < 60) return seconds + "s ago"
    return Math.round(seconds / 60) + "m ago"
  }

  function tooltipText() {
    return "CPU " + Model.formatPercent(snapshot.cpu.utilization) +
      " · GPU " + Model.formatPercent(snapshot.gpu.utilization) +
      " · NPU " + Model.formatPercent(snapshot.npu.utilization) +
      " · MEM " + Model.formatPercent(snapshot.cpu.memoryPercent) +
      " · PWR " + root.powerTileValue()
  }


  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: "󰚗"
    opacity: metrics.status === "online" && !metrics.stale ? 1 : 0.55
    active: root.worstValue() >= root.warningThreshold
    activeColor: root.worstValue() >= root.criticalThreshold ? root.urgent : root.warningColor
    tooltipText: root.tooltipText()
    onPressed: function(button) { root.barPressed(button) }
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

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



  function coreCount() {
    if (snapshot.cpu.cores && snapshot.cpu.cores.length > 0) return snapshot.cpu.cores.length
    var extra = snapshot.devices.cpu && snapshot.devices.cpu.extra ? snapshot.devices.cpu.extra : {}
    return Number(extra.threads || 0)
  }

  function coreUsageText() {
    if (snapshot.cpu.coresUsed < 0) return "—"
    var total = coreCount()
    return snapshot.cpu.coresUsed.toFixed(1) + (total > 0 ? " / " + total : "")
  }

  function cpuSummary() {
    var parts = []
    if (snapshot.cpu.coresUsed >= 0)
      parts.push(snapshot.cpu.coresUsed.toFixed(1) + " cores")
    if (snapshot.cpu.frequency >= 0)
      parts.push(Model.formatMHz(snapshot.cpu.frequency))
    return parts.length > 0 ? parts.join(" · ") : "No CPU data"
  }

  function gpuSummary() {
    var parts = []
    if (snapshot.gpu.engines.length > 0)
      parts.push(snapshot.gpu.engines.length + " engines")
    if (snapshot.gpu.frequency >= 0)
      parts.push(Model.formatMHz(snapshot.gpu.frequency))
    return parts.length > 0 ? parts.join(" · ") : "No GPU data"
  }

  function npuSummary() {
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

  function powerDomain(name) {
    var domains = snapshot.power.domains
    for (var i = 0; i < domains.length; i++)
      if (domains[i].domain === name) return domains[i].watts
    return -1
  }

  function powerTileValue() {
    if (snapshot.cpu.power >= 0) return Model.formatWatts(snapshot.cpu.power)
    var psys = powerDomain("psys")
    if (psys >= 0) return Model.formatWatts(psys)
    if (snapshot.power.battery.capacity >= 0) return snapshot.power.battery.capacity + "%"
    return "—"
  }

  function powerTileDetail() {
    var parts = []
    var psys = powerDomain("psys")
    if (psys >= 0) parts.push("psys " + Model.formatWatts(psys))
    if (snapshot.power.battery.capacity >= 0)
      parts.push(snapshot.power.battery.capacity + "%" +
        (snapshot.power.battery.discharging ? " discharging" : ""))
    return parts.length > 0 ? parts.join(" · ") : "No power data"
  }

  function powerTileMeter() {
    return snapshot.power.battery.capacity >= 0 ? snapshot.power.battery.capacity : -1
  }

  function powerTileMeterColor() {
    if (snapshot.power.battery.capacity >= 0 && snapshot.power.battery.capacity < 20) return urgent
    return accent
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
      chartExpanded = boolSetting("showChart", true)
      showPowerSection = boolSetting("showPower", true)
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
    function toggleCard(name: string): string {
      if (name === "cpu") root.cpuExpanded = !root.cpuExpanded
      else if (name === "gpu") root.gpuExpanded = !root.gpuExpanded
      else if (name === "npu") root.npuExpanded = !root.npuExpanded
      else if (name === "power") root.powerExpanded = !root.powerExpanded
      return name
    }
  }

  // ---------------------------------------------------------- panel

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
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
        else if (key === "c") root.cpuExpanded = !root.cpuExpanded
        else if (key === "g") root.gpuExpanded = !root.gpuExpanded
        else if (key === "n") root.npuExpanded = !root.npuExpanded
        else if (key === "e") root.gpuExpanded = !root.gpuExpanded
        else if (key === "p") root.powerExpanded = !root.powerExpanded
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
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰚗"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
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

          // Summary cards are the first data in the panel. The colored dot
          // matches the group's line in the graph below, so the graph does
          // not need its own legend.
          Row {
            width: parent.width
            spacing: Style.space(8)

            GroupTile {
              width: root.tileWidth
              visible: root.snapshot.hasCpu
              title: "CPU"
              value: root.percent(root.snapshot.cpu.utilization)
              detail: root.cpuSummary()
              meter: root.snapshot.cpu.utilization
              meterColor: root.levelColor(root.snapshot.cpu.utilization)
              seriesColor: root.accent
              alarming: root.snapshot.cpu.utilization >= root.criticalThreshold
              expanded: root.cpuExpanded
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.cpuExpanded = !root.cpuExpanded
            }

            GroupTile {
              width: root.tileWidth
              visible: root.snapshot.hasGpu
              title: "GPU"
              value: root.percent(root.snapshot.gpu.utilization)
              detail: root.gpuSummary()
              meter: root.snapshot.gpu.utilization
              meterColor: root.levelColor(root.snapshot.gpu.utilization)
              seriesColor: root.secondary
              alarming: root.snapshot.gpu.utilization >= root.criticalThreshold
              expanded: root.gpuExpanded
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.gpuExpanded = !root.gpuExpanded
            }

            GroupTile {
              width: root.tileWidth
              visible: root.snapshot.hasNpu
              title: "NPU"
              value: root.percent(root.snapshot.npu.utilization)
              detail: root.npuSummary()
              meter: root.snapshot.npu.utilization
              meterColor: root.levelColor(root.snapshot.npu.utilization)
              seriesColor: root.tertiary
              alarming: root.snapshot.npu.utilization >= root.criticalThreshold
              expanded: root.npuExpanded
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.npuExpanded = !root.npuExpanded
            }
          }

          // Memory and power use the same card language as the top row.
          Row {
            width: parent.width
            spacing: Style.space(8)

            GroupTile {
              width: root.secondaryTileWidth
              visible: root.hasMemory
              title: "MEMORY"
              value: root.percent(root.snapshot.cpu.memoryPercent)
              detail: Model.formatBytes(root.snapshot.cpu.memoryUsed) + " / " +
                Model.formatBytes(root.snapshot.cpu.memoryTotal)
              meter: root.snapshot.cpu.memoryPercent
              meterColor: root.levelColor(root.snapshot.cpu.memoryPercent)
              seriesColor: root.muted
              alarming: root.snapshot.cpu.memoryPercent >= root.criticalThreshold
              interactive: false
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              accent: root.accent
              fontFamily: root.fontFamily
            }

            GroupTile {
              width: root.secondaryTileWidth
              visible: root.hasPower
              title: "POWER"
              value: root.powerTileValue()
              detail: root.powerTileDetail()
              meter: root.powerTileMeter()
              meterColor: root.powerTileMeterColor()
              seriesColor: root.warningColor
              expanded: root.powerExpanded
              interactive: true
              foreground: root.foreground
              muted: root.muted
              urgent: root.urgent
              accent: root.accent
              fontFamily: root.fontFamily
              onToggled: root.powerExpanded = !root.powerExpanded
            }
          }

          // The utilization graph follows the summary cards, so it stays
          // above the expanded detail sections.
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.chartExpanded

            SectionHeading {
              title: "UTILIZATION"
              value: "1 HOUR"
            }

            Item {
              width: parent.width
              height: Style.space(62)

              Sparkline {
                anchors.fill: parent
                series: root.utilSeries()
                fixedMaximum: 100
                gridColor: root.chartGrid
                windowMs: 3600000
              }
            }
          }

          // Expanded detail sections live below the summary rows and span the
          // full panel width, so their two-column grids have room to breathe.
          GroupDetail {
            width: parent.width
            visible: root.cpuExpanded && root.snapshot.hasCpu
            title: "CPU DETAILS"
            seriesColor: root.accent
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            fontFamily: root.fontFamily
            onToggled: root.cpuExpanded = false

            DetailGrid {
              DetailCell {
                label: "Frequency"
                value: Model.formatMHz(root.snapshot.cpu.frequency)
              }
              DetailCell {
                label: "Power"
                value: Model.formatWatts(root.snapshot.cpu.power)
              }
              DetailCell {
                label: "Temperature"
                value: Model.formatTemperature(root.snapshot.cpu.temperature)
              }
              DetailCell {
                label: "Cores"
                value: root.coreUsageText()
              }
            }
          }

          GroupDetail {
            width: parent.width
            visible: root.gpuExpanded && root.snapshot.hasGpu
            title: "GPU DETAILS"
            seriesColor: root.secondary
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            fontFamily: root.fontFamily
            onToggled: root.gpuExpanded = false

            DetailGrid {
              DetailCell {
                label: "Frequency"
                value: root.snapshot.gpu.frequency >= 0
                  ? Model.formatMHz(root.snapshot.gpu.frequency) +
                    (root.snapshot.gpu.frequencyMax >= 0 ? " / " + Model.formatMHz(root.snapshot.gpu.frequencyMax) : "")
                  : "—"
              }
              DetailCell {
                label: "Media clock"
                value: Model.formatMHz(root.snapshot.gpu.mediaFrequency)
              }
              DetailCell {
                label: "Power"
                value: Model.formatWatts(root.snapshot.gpu.power)
              }
              DetailCell {
                label: "Memory"
                value: Model.formatBytes(root.snapshot.gpu.memoryUsed)
              }
            }

            Column {
              width: parent.width
              spacing: Style.space(4)
              visible: root.snapshot.gpu.engines.length > 0

              SectionHeading {
                title: "ENGINES"
                value: root.mediaFreqText()
              }

              Grid {
                width: parent.width
                columns: 2
                columnSpacing: Style.space(12)
                rowSpacing: Style.space(6)

                Repeater {
                  model: root.snapshot.gpu.engines

                  EngineCell {
                    label: modelData.label
                    value: modelData.value
                    meterColor: root.levelColor(modelData.value)
                  }
                }
              }
            }
          }

          GroupDetail {
            width: parent.width
            visible: root.npuExpanded && root.snapshot.hasNpu
            title: "NPU DETAILS"
            seriesColor: root.tertiary
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            fontFamily: root.fontFamily
            onToggled: root.npuExpanded = false

            DetailGrid {
              DetailCell {
                label: "Frequency"
                value: Model.formatMHz(root.snapshot.npu.frequency)
              }
              DetailCell {
                label: "Power"
                value: Model.formatWatts(root.snapshot.npu.power)
              }
              DetailCell {
                label: "Temperature"
                value: Model.formatTemperature(root.snapshot.npu.temperature)
              }
              DetailCell {
                label: "DDR bandwidth"
                value: Model.formatRate(root.snapshot.npu.ddrBandwidth)
              }
              DetailCell {
                label: "Memory"
                value: Model.formatBytes(root.snapshot.npu.memoryUsed) + " / " +
                  Model.formatBytes(root.snapshot.npu.memoryTotal)
                meter: root.snapshot.npu.memoryPercent
                meterColor: root.levelColor(root.snapshot.npu.memoryPercent)
              }
              DetailCell {
                label: "Tile config"
                value: root.snapshot.npu.tileConfig >= 0 ? String(root.snapshot.npu.tileConfig) : "—"
              }
            }
          }

          GroupDetail {
            width: parent.width
            visible: root.powerExpanded && root.hasPower
            title: "POWER DETAILS"
            seriesColor: root.warningColor
            foreground: root.foreground
            muted: root.muted
            accent: root.accent
            fontFamily: root.fontFamily
            onToggled: root.powerExpanded = false

            DetailGrid {
              Repeater {
                model: root.snapshot.power.domains

                DetailCell {
                  label: modelData.domain
                  value: Model.formatWatts(modelData.watts)
                }
              }

              DetailCell {
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

  component DetailGrid: Grid {
    width: parent ? parent.width : 0
    columns: 2
    columnSpacing: Style.space(12)
    rowSpacing: Style.space(6)
  }

  component DetailCell: Column {
    id: cell

    property string label: ""
    property string value: "—"
    property real meter: -1
    property color meterColor: root.accent

    width: parent && parent.columnSpacing !== undefined
      ? (parent.width - parent.columnSpacing) / 2
      : (parent ? parent.width : 0)
    spacing: Style.space(2)

    Item {
      width: parent.width
      implicitHeight: Math.max(cellLabel.implicitHeight, cellValue.implicitHeight)

      Text {
        id: cellLabel
        width: Math.max(0, parent.width - cellValue.width - Style.space(6))
        text: cell.label
        textFormat: Text.PlainText
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        id: cellValue
        text: cell.value
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.bold: true
        width: Math.min(implicitWidth, parent.width * 0.68)
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignRight
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    Meter {
      width: parent.width
      visible: cell.meter >= 0
      value: cell.meter
      fillColor: cell.meterColor
    }
  }

  component EngineCell: Column {
    id: engine

    property string label: ""
    property real value: -1
    property color meterColor: root.accent

    width: parent && parent.columnSpacing !== undefined
      ? (parent.width - parent.columnSpacing) / 2
      : (parent ? parent.width : 0)
    spacing: Style.space(2)

    Item {
      width: parent.width
      implicitHeight: Math.max(engineLabel.implicitHeight, engineValue.implicitHeight)

      Text {
        id: engineLabel
        text: engine.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
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

}
