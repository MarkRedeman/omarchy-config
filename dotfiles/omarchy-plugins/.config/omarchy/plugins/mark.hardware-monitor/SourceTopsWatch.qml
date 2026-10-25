import QtQuick
import Quickshell.Io
import "Model.js" as Model

// TopsWatch HTTP source.
//
// This is the first implementation of the plugin's data-source contract:
// set `endpoint` and `intervalMs`, keep `active` true, and listen for
// `sampleReceived(var)`. A future local/sysfs source only has to emit the
// same TopsWatch-shaped sample, which Model.normalizeSample() already knows
// how to read.
//
// Polling rather than SSE is deliberate: the whole sample is ~9 KB, the
// process is one short-lived curl, and a failed request is unambiguous. It
// also avoids depending on a long-lived stream's reconnect semantics.
Item {
  id: root

  property string endpoint: "http://127.0.0.1:9876"
  property int intervalMs: 5000
  property bool active: true

  // "starting" | "online" | "offline" | "error"
  property string status: "starting"
  property string error: ""
  property var sample: null
  property double lastUpdated: 0

  signal sampleReceived(var sample)
  signal healthChanged(string status, string error)
  signal historyReceived(var history)

  readonly property bool hasData: lastUpdated > 0

  function baseUrl() {
    var value = String(endpoint || "").trim()
    if (value === "") value = "http://127.0.0.1:9876"
    if (value.indexOf("://") < 0) value = "http://" + value
    return value.replace(/\/+$/, "")
  }

  function metricsUrl() {
    return baseUrl() + "/api/metrics/latest"
  }

  function refresh() {
    if (!root.active || pollProc.running) return
    pollProc.running = true
  }

  function fetchHistory() {
    if (!root.active || historyProc.running) return
    historyProc.running = true
  }

  function setStatus(next, message) {
    var detail = String(message || "")
    if (root.status === next && root.error === detail) return
    root.status = next
    root.error = detail
    root.healthChanged(next, detail)
  }

  onEndpointChanged: refresh()
  onActiveChanged: if (active) refresh()

  Timer {
    id: pollTimer
    interval: Math.max(1000, root.intervalMs)
    repeat: true
    running: root.active
    onTriggered: root.refresh()
  }

  Process {
    id: pollProc
    command: ["curl", "-fsS", "--max-time", "3", root.metricsUrl()]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "")
        if (raw === "") {
          root.setStatus("error", "TopsWatch returned an empty response")
          return
        }
        var parsed = null
        try {
          parsed = JSON.parse(raw)
        } catch (parseError) {
          root.setStatus("error", "TopsWatch returned invalid JSON")
          return
        }
        if (!parsed || !parsed.metrics) {
          root.setStatus("error", "Unexpected TopsWatch response")
          return
        }
        root.sample = parsed
        root.lastUpdated = Date.now()
        root.setStatus("online", "")
        root.sampleReceived(parsed)
      }
    }

    stderr: StdioCollector {
      id: errorCollector
      waitForEnd: true
    }

    onExited: function(exitCode, exitStatus) {
      if (exitCode === 0) return
      var detail = String(errorCollector.text || "").trim()
      if (detail === "") detail = "curl exited with code " + exitCode
      if (exitCode === 22 && detail.indexOf("503") >= 0) {
        root.setStatus("starting", "TopsWatch is starting")
        return
      }
      root.setStatus("offline", detail)
    }
  }

  Component.onCompleted: refresh()

  // One-hour backfill for the utilization chart. This is fetched on demand
  // when the panel opens, not on every poll: the 1h tier is ~1.5 MB and only
  // changes every 10 seconds.
  Process {
    id: historyProc
    command: ["curl", "-fsS", "--max-time", "8", root.baseUrl() + "/api/metrics/history?range=1h"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "")
        if (raw === "") return
        var parsed = null
        try {
          parsed = JSON.parse(raw)
        } catch (parseError) {
          return
        }
        if (!parsed || typeof parsed.length !== "number") return
        root.historyReceived({
          cpu: Model.historyPoints(parsed, "cpu", "utilization"),
          gpu: Model.historyPoints(parsed, "gpu", "utilization"),
          npu: Model.historyPoints(parsed, "npu", "utilization")
        })
      }
    }

    stderr: StdioCollector {
      waitForEnd: true
    }
  }
}
