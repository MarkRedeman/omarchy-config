import QtQuick
import "Model.js" as Model

// Source orchestrator.
//
// Today there is exactly one adapter (TopsWatch). The strategy seam is
// `sourceKind` plus a separate source component: adding a local/sysfs
// collector later means adding SourceLocal.qml and one branch here, while
// the panel keeps consuming the same normalized snapshot and history.
Item {
  id: root

  property string sourceKind: "topswatch" // future: "auto", "local"
  property string endpoint: "http://127.0.0.1:9876"
  property bool panelOpen: false
  property int closedRefreshMs: 5000
  property int openRefreshMs: 1000

  property var snapshot: Model.emptySnapshot()
  property var history: ({ cpu: [], gpu: [], npu: [] })
  property string status: "starting"
  property string error: ""
  property double lastUpdated: 0
  property bool stale: false

  readonly property bool hasData: lastUpdated > 0
  readonly property bool hasGpu: snapshot.hasGpu
  readonly property bool hasNpu: snapshot.hasNpu
  readonly property bool hasGpuEngines: snapshot.hasGpuEngines
  readonly property bool hasCpuPower: snapshot.hasCpuPower
  readonly property int refreshMs: panelOpen ? openRefreshMs : closedRefreshMs

  function refresh() {
    source.refresh()
  }

  function reset() {
    root.snapshot = Model.emptySnapshot()
    root.history = ({ cpu: [], gpu: [], npu: [] })
    root.lastUpdated = 0
    root.status = "starting"
    root.error = ""
    root.stale = false
  }

  onEndpointChanged: reset()

  function ingest(sample) {
    var next = Model.normalizeSample(sample)
    root.snapshot = next
    root.lastUpdated = Date.now()
    root.status = "online"
    root.error = ""
    root.stale = false
    root.appendHistory(next)
  }

  function appendHistory(next) {
    var now = Date.now()
    var current = root.history
    root.history = {
      cpu: Model.appendPoint(current.cpu, next.cpu.utilization, now, 240),
      gpu: Model.appendPoint(current.gpu, next.gpu.utilization, now, 240),
      npu: Model.appendPoint(current.npu.utilization, now, 240)
    }
  }

  onPanelOpenChanged: if (panelOpen) refresh()

  SourceTopsWatch {
    id: source
    endpoint: root.endpoint
    intervalMs: root.refreshMs
    active: root.sourceKind === "topswatch" || root.sourceKind === "auto"
    onSampleReceived: function(sample) { root.ingest(sample) }
    onHealthChanged: function(status, error) {
      root.status = status
      root.error = error
    }
  }

  // Keep the last good sample visible but mark it when the daemon stops
  // answering. The panel uses this to dim the footer and show a stale banner.
  Timer {
    id: staleTimer
    interval: 1000
    repeat: true
    running: root.hasData
    onTriggered: {
      var limit = Math.max(4000, root.refreshMs * 3)
      root.stale = Date.now() - root.lastUpdated > limit
    }
  }
}
