// Pure parsing and formatting for mark.hardware-monitor.
//
// The QML layer owns polling and presentation; everything that can be tested
// without a running shell lives here. Keeping the TopsWatch schema in one
// place is what makes the source replaceable: a future local/sysfs source
// only has to produce the same normalized snapshot.

function finite(value, fallback) {
  var number = Number(value)
  return isFinite(number) ? number : fallback
}

function hasLabels(metric) {
  if (!metric || !metric.labels) return false
  for (var key in metric.labels) {
    if (Object.prototype.hasOwnProperty.call(metric.labels, key)) return true
  }
  return false
}

function asArray(value) {
  if (!value) return []
  if (typeof value.length === "number") return value
  return []
}

function metricList(metrics, moduleName) {
  if (!metrics) return []
  return asArray(metrics[moduleName])
}

// The first unlabeled metric with this name. Labeled families (per-core,
// per-engine, per-domain) are read through their own helpers below.
function metricValue(metrics, moduleName, name) {
  var list = metricList(metrics, moduleName)
  for (var i = 0; i < list.length; i++) {
    var metric = list[i]
    if (!metric || metric.name !== name || hasLabels(metric)) continue
    return finite(metric.value, -1)
  }
  return -1
}

function labeledValues(metrics, moduleName, name) {
  var out = []
  var list = metricList(metrics, moduleName)
  for (var i = 0; i < list.length; i++) {
    var metric = list[i]
    if (!metric || metric.name !== name || !metric.labels) continue
    out.push({ value: finite(metric.value, -1), labels: metric.labels })
  }
  return out
}

function sumLabeled(metrics, moduleName, name) {
  var values = labeledValues(metrics, moduleName, name)
  var total = 0
  var found = false
  for (var i = 0; i < values.length; i++) {
    if (values[i].value < 0) continue
    total += values[i].value
    found = true
  }
  return found ? total : -1
}

// ---------------------------------------------------------------- CPU

function coreMetrics(metrics) {
  var utilizations = {}
  var frequencies = {}
  var types = {}
  var order = []

  var utilList = metricList(metrics, "cpu")
  for (var i = 0; i < utilList.length; i++) {
    var metric = utilList[i]
    if (!metric || !metric.labels || metric.name !== "core_utilization") continue
    var core = String(metric.labels.core === undefined ? "" : metric.labels.core)
    if (core === "") continue
    if (utilizations[core] === undefined) {
      utilizations[core] = finite(metric.value, -1)
      order.push(core)
    }
    if (metric.labels.core_type) types[core] = String(metric.labels.core_type)
  }

  for (var j = 0; j < utilList.length; j++) {
    var freq = utilList[j]
    if (!freq || !freq.labels || freq.name !== "core_frequency") continue
    var freqCore = String(freq.labels.core === undefined ? "" : freq.labels.core)
    if (freqCore !== "") frequencies[freqCore] = finite(freq.value, -1)
  }

  order.sort(function(a, b) { return Number(a) - Number(b) })
  var cores = []
  for (var k = 0; k < order.length; k++) {
    var id = order[k]
    cores.push({
      core: id,
      type: types[id] || "unknown",
      utilization: utilizations[id] === undefined ? -1 : utilizations[id],
      frequency: frequencies[id] === undefined ? -1 : frequencies[id]
    })
  }
  return cores
}

function coreTypeSummary(devices) {
  var extra = devices && devices.cpu && devices.cpu.extra ? devices.cpu.extra : {}
  var p = finite(extra.p_cores, 0)
  var e = finite(extra.e_cores, 0)
  var lp = finite(extra.lp_cores, 0)
  var parts = []
  if (p > 0) parts.push(p + "P")
  if (e > 0) parts.push(e + "E")
  if (lp > 0) parts.push(lp + "LP")
  return parts.join(" / ")
}

// ---------------------------------------------------------------- GPU

var ENGINE_ORDER = ["rcs", "ccs", "bcs", "vcs", "vecs"]
var ENGINE_LABELS = {
  rcs: "Render",
  ccs: "Compute",
  bcs: "Copy",
  vcs: "Video",
  vecs: "Video enhance"
}
var ENGINE_DESCRIPTIONS = {
  rcs: "3D",
  ccs: "inference",
  bcs: "blitter",
  vcs: "decode/encode",
  vecs: "post-process"
}

function engineClass(label) {
  var text = String(label || "")
  var match = text.match(/^([a-z]+)/)
  return match ? match[1] : text
}

function engineMetrics(metrics) {
  var values = labeledValues(metrics, "gpu", "engine_busy")
  var engines = []
  for (var i = 0; i < values.length; i++) {
    var label = String(values[i].labels.engine === undefined ? "" : values[i].labels.engine)
    var klass = engineClass(label)
    engines.push({
      engine: label,
      klass: klass,
      label: ENGINE_LABELS[klass] || label,
      description: ENGINE_DESCRIPTIONS[klass] || "",
      value: values[i].value
    })
  }
  engines.sort(function(a, b) {
    var ai = ENGINE_ORDER.indexOf(a.klass)
    var bi = ENGINE_ORDER.indexOf(b.klass)
    if (ai < 0) ai = ENGINE_ORDER.length
    if (bi < 0) bi = ENGINE_ORDER.length
    if (ai !== bi) return ai - bi
    return String(a.engine).localeCompare(String(b.engine))
  })
  return engines
}

// ---------------------------------------------------------------- NPU

// ---------------------------------------------------------------- power

var POWER_ORDER = ["package", "core", "uncore", "dram", "psys", "npu", "battery"]

function powerMetrics(metrics) {
  var values = labeledValues(metrics, "power", "power")
  var domains = []
  for (var i = 0; i < values.length; i++) {
    var domain = String(values[i].labels.domain === undefined ? "" : values[i].labels.domain)
    if (domain === "") continue
    domains.push({ domain: domain, watts: values[i].value })
  }
  domains.sort(function(a, b) {
    var ai = POWER_ORDER.indexOf(a.domain)
    var bi = POWER_ORDER.indexOf(b.domain)
    if (ai < 0) ai = POWER_ORDER.length
    if (bi < 0) bi = POWER_ORDER.length
    if (ai !== bi) return ai - bi
    return String(a.domain).localeCompare(String(b.domain))
  })

  var battery = {
    capacity: metricValue(metrics, "power", "battery_capacity"),
    voltage: metricValue(metrics, "power", "battery_voltage"),
    discharging: metricValue(metrics, "power", "battery_discharging") > 0
  }
  return { domains: domains, battery: battery }
}

// ---------------------------------------------------------------- snapshot

function emptySnapshot() {
  return {
    timestamp: "",
    devices: {},
    cpu: {
      utilization: -1,
      frequency: -1,
      power: -1,
      temperature: -1,
      memoryUsed: -1,
      memoryTotal: -1,
      memoryPercent: -1,
      coresUsed: -1,
      cores: []
    },
    gpu: {
      utilization: -1,
      frequency: -1,
      frequencyMax: -1,
      mediaFrequency: -1,
      power: -1,
      temperature: -1,
      memoryUsed: -1,
      engines: []
    },
    npu: {
      utilization: -1,
      frequency: -1,
      power: -1,
      temperature: -1,
      ddrBandwidth: -1,
      memoryUsed: -1,
      memoryTotal: -1,
      memoryPercent: -1,
      tileConfig: -1
    },
    power: { domains: [], battery: { capacity: -1, voltage: -1, discharging: false } },
    warnings: [],
    hasCpu: false,
    hasGpu: false,
    hasNpu: false,
    hasGpuEngines: false,
    hasCpuPower: false,
    source: ""
  }
}

function normalizeSample(sample) {
  var out = emptySnapshot()
  if (!sample || !sample.metrics) return out

  var metrics = sample.metrics
  out.timestamp = String(sample.timestamp || "")
  out.devices = sample.devices || {}
  out.source = "topswatch"

  out.cpu.utilization = metricValue(metrics, "cpu", "utilization")
  out.cpu.frequency = metricValue(metrics, "cpu", "frequency")
  out.cpu.power = metricValue(metrics, "cpu", "power")
  out.cpu.temperature = metricValue(metrics, "cpu", "temperature")
  out.cpu.memoryUsed = metricValue(metrics, "cpu", "memory_used")
  out.cpu.memoryTotal = metricValue(metrics, "cpu", "memory_total")
  out.cpu.memoryPercent = metricValue(metrics, "cpu", "memory_used_percent")
  out.cpu.coresUsed = metricValue(metrics, "cpu", "cores_used")
  out.cpu.cores = coreMetrics(metrics)

  out.gpu.utilization = metricValue(metrics, "gpu", "utilization")
  out.gpu.frequency = metricValue(metrics, "gpu", "frequency_actual")
  out.gpu.frequencyMax = metricValue(metrics, "gpu", "frequency_max")
  out.gpu.mediaFrequency = metricValue(metrics, "gpu", "media_frequency_actual")
  out.gpu.power = metricValue(metrics, "gpu", "power")
  out.gpu.temperature = metricValue(metrics, "gpu", "temperature")
  out.gpu.memoryUsed = sumLabeled(metrics, "gpu", "memory_used")
  out.gpu.engines = engineMetrics(metrics)

  out.npu.utilization = metricValue(metrics, "npu", "utilization")
  out.npu.frequency = metricValue(metrics, "npu", "frequency")
  out.npu.power = metricValue(metrics, "npu", "power")
  out.npu.temperature = metricValue(metrics, "npu", "temperature")
  out.npu.ddrBandwidth = metricValue(metrics, "npu", "ddr_bandwidth")
  out.npu.memoryUsed = metricValue(metrics, "npu", "memory_used")
  out.npu.memoryTotal = metricValue(metrics, "npu", "memory_total")
  out.npu.memoryPercent = metricValue(metrics, "npu", "memory_used_percent")
  out.npu.tileConfig = metricValue(metrics, "npu", "tile_config")

  out.power = powerMetrics(metrics)
  out.warnings = asArray(sample.warnings)

  out.hasCpu = out.cpu.utilization >= 0 || out.cpu.frequency >= 0 || out.cpu.temperature >= 0
  out.hasCpuPower = out.cpu.power >= 0
  out.hasGpu = out.gpu.utilization >= 0 || out.gpu.frequency >= 0 || out.gpu.power >= 0 ||
    out.gpu.temperature >= 0 || out.gpu.engines.length > 0
  out.hasGpuEngines = out.gpu.engines.length > 0
  out.hasNpu = out.npu.utilization >= 0 || out.npu.frequency >= 0 || out.npu.power >= 0 ||
    out.npu.temperature >= 0 || out.npu.memoryUsed >= 0

  return out
}

// ---------------------------------------------------------------- history

function appendPoint(list, value, time, cap) {
  var limit = cap === undefined ? 4000 : cap
  var number = Number(value)
  if (!isFinite(number) || number < 0) return list
  var next = asArray(list).slice()
  var stamp = Number(time)
  if (!isFinite(stamp)) return next
  var last = next.length > 0 ? next[next.length - 1] : null
  if (last && stamp <= Number(last.time)) {
    if (stamp === Number(last.time)) next[next.length - 1] = { time: stamp, value: number }
    return next
  }
  next.push({ time: stamp, value: number })
  if (next.length > limit) next = next.slice(next.length - limit)
  return next
}

// Extract one metric's time series from TopsWatch's
// /api/metrics/history?range=1h response (an array of ReducedSample).
function historyPoints(samples, moduleName, metricName) {
  var list = asArray(samples)
  var out = []
  for (var i = 0; i < list.length; i++) {
    var sample = list[i]
    if (!sample || !sample.metrics) continue
    var value = metricValue(sample.metrics, moduleName, metricName)
    if (value < 0) continue
    var time = Date.parse(String(sample.timestamp || ""))
    if (!isFinite(time)) continue
    out.push({ time: time, value: value })
  }
  return out
}

// Union of the history backfill and live samples. Live values win on a
// duplicate timestamp so the freshest sample is the one drawn.
function mergeHistory(base, live, cutoff, cap) {
  var limit = cap === undefined ? 4000 : cap
  var byTime = {}
  var order = []

  function add(list) {
    var points = asArray(list)
    for (var i = 0; i < points.length; i++) {
      var point = points[i]
      var time = Number(point.time)
      var value = Number(point.value)
      if (!isFinite(time) || !isFinite(value) || value < 0) continue
      if (cutoff !== undefined && time < Number(cutoff)) continue
      if (byTime[time] === undefined) order.push(time)
      byTime[time] = value
    }
  }

  add(base)
  add(live)
  order.sort(function(a, b) { return a - b })

  var out = []
  for (var j = 0; j < order.length; j++)
    out.push({ time: order[j], value: byTime[order[j]] })
  if (out.length > limit) out = out.slice(out.length - limit)
  return out
}

// ---------------------------------------------------------------- formatting

function formatPercent(value, digits) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "—"
  var places = digits === undefined ? 0 : digits
  return number.toFixed(places) + "%"
}

function formatMHz(value) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "—"
  return Math.round(number) + " MHz"
}

function formatWatts(value, digits) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "—"
  var places = digits === undefined ? 1 : digits
  return number.toFixed(places) + " W"
}

function formatTemperature(value) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "—"
  return Math.round(number) + "°C"
}

function formatBytes(value) {
  var amount = Number(value)
  if (!isFinite(amount) || amount < 0) return "—"
  var units = ["B", "KiB", "MiB", "GiB", "TiB"]
  var index = 0
  while (amount >= 1024 && index < units.length - 1) {
    amount /= 1024
    index++
  }
  var digits = index >= 3 ? 1 : (amount >= 100 ? 0 : 1)
  return amount.toFixed(digits) + " " + units[index]
}

function formatRate(value) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "—"
  if (number >= 1000) return (number / 1000).toFixed(2) + " GB/s"
  return number.toFixed(number >= 100 ? 0 : 1) + " MB/s"
}

function padPercent(value) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "--"
  if (number >= 100) return "100"
  var text = String(Math.round(number))
  return text.length < 2 ? "0" + text : text
}

function padPercent3(value) {
  var number = Number(value)
  if (!isFinite(number) || number < 0) return "  —"
  var text = String(Math.round(number))
  while (text.length < 3) text = " " + text
  return text
}

function worstMetric(snapshot) {
  var best = { key: "cpu", label: "CPU", value: snapshot && snapshot.cpu ? snapshot.cpu.utilization : -1 }
  var candidates = []
  if (snapshot && snapshot.hasGpu) candidates.push({ key: "gpu", label: "GPU", value: snapshot.gpu.utilization })
  if (snapshot && snapshot.hasNpu) candidates.push({ key: "npu", label: "NPU", value: snapshot.npu.utilization })
  for (var i = 0; i < candidates.length; i++) {
    if (candidates[i].value > best.value) best = candidates[i]
  }
  return best
}

function barLabel(snapshot, mode, vertical) {
  if (!snapshot) return "—"
  if (vertical) return padPercent3(worstMetric(snapshot).value)
  if (mode === "CPU") return "CPU " + padPercent3(snapshot.cpu.utilization)
  if (mode === "GPU") return "GPU " + padPercent3(snapshot.gpu.utilization)
  if (mode === "NPU") return "NPU " + padPercent3(snapshot.npu.utilization)
  if (mode === "Worst") {
    var worst = worstMetric(snapshot)
    return worst.label + " " + padPercent3(worst.value)
  }
  var parts = ["C" + padPercent(snapshot.cpu.utilization)]
  if (snapshot.hasGpu) parts.push("G" + padPercent(snapshot.gpu.utilization))
  if (snapshot.hasNpu) parts.push("N" + padPercent(snapshot.npu.utilization))
  return parts.join(" ")
}

function escapeMarkup(value) {
  return String(value === undefined || value === null ? "" : value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;")
}

// Node test support. QML has no `module`, so the guard is a no-op there.
if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    finite: finite,
    hasLabels: hasLabels,
    metricValue: metricValue,
    labeledValues: labeledValues,
    sumLabeled: sumLabeled,
    coreMetrics: coreMetrics,
    coreTypeSummary: coreTypeSummary,
    engineMetrics: engineMetrics,
    powerMetrics: powerMetrics,
    emptySnapshot: emptySnapshot,
    normalizeSample: normalizeSample,
    appendPoint: appendPoint,
    historyPoints: historyPoints,
    mergeHistory: mergeHistory,
    formatPercent: formatPercent,
    formatMHz: formatMHz,
    formatWatts: formatWatts,
    formatTemperature: formatTemperature,
    formatBytes: formatBytes,
    formatRate: formatRate,
    padPercent: padPercent,
    padPercent3: padPercent3,
    worstMetric: worstMetric,
    barLabel: barLabel,
    escapeMarkup: escapeMarkup
  }
}
