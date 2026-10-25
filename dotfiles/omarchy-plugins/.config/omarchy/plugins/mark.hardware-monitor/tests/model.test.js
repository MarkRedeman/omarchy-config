const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")
const Model = require(path.join(__dirname, "..", "Model.js"))
const fixture = require(path.join(__dirname, "fixtures", "topswatch-sample.json"))

test("normalizes the headline metrics", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.equal(snapshot.cpu.utilization, 12.5)
  assert.equal(snapshot.gpu.utilization, 42.5)
  assert.equal(snapshot.npu.utilization, 18)
  assert.equal(snapshot.cpu.power, 7.25)
  assert.equal(snapshot.gpu.power, 4.5)
  assert.equal(snapshot.npu.power, 1.75)
  assert.equal(snapshot.hasCpu, true)
  assert.equal(snapshot.hasGpu, true)
  assert.equal(snapshot.hasNpu, true)
  assert.equal(snapshot.hasCpuPower, true)
})

test("keeps unlabeled metrics separate from labeled families", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.equal(snapshot.cpu.memoryUsed, 12884901888)
  assert.equal(snapshot.cpu.cores.length, 2)
  assert.equal(snapshot.cpu.cores[0].core, "0")
  assert.equal(snapshot.cpu.cores[0].type, "performance")
  assert.equal(snapshot.cpu.cores[1].frequency, 1200)
})

test("sorts GPU engines in display order", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.deepEqual(snapshot.gpu.engines.map((engine) => engine.klass), ["rcs", "ccs", "bcs", "vcs", "vecs"])
  assert.equal(snapshot.gpu.engines[0].label, "Render")
  assert.equal(snapshot.gpu.engines[4].label, "Video enhance")
})

test("sums labeled GPU memory", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.equal(snapshot.gpu.memoryUsed, 1073741824 + 268435456)
})

test("sorts power domains and reads battery state", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.deepEqual(snapshot.power.domains.map((domain) => domain.domain), ["package", "core", "uncore", "dram", "battery"])
  assert.equal(snapshot.power.battery.capacity, 58)
  assert.equal(snapshot.power.battery.discharging, true)
})

test("core type summary matches Panther Lake topology", () => {
  assert.equal(Model.coreTypeSummary(fixture.devices), "4P / 8E / 4LP")
})

test("bar labels are fixed width for the All mode", () => {
  const snapshot = Model.normalizeSample(fixture)
  assert.equal(Model.barLabel(snapshot, "All", false), "C13 G43 N18")
  assert.equal(Model.barLabel(snapshot, "CPU", false), "CPU  13")
  assert.equal(Model.barLabel(snapshot, "Worst", false), "GPU  43")
  assert.equal(Model.barLabel(snapshot, "All", true), " 43")
})

test("worst metric ignores unavailable modules", () => {
  const snapshot = Model.normalizeSample(fixture)
  snapshot.hasNpu = false
  snapshot.npu.utilization = -1
  assert.deepEqual(Model.worstMetric(snapshot), { key: "gpu", label: "GPU", value: 42.5 })
})

test("formatters degrade to an em dash", () => {
  assert.equal(Model.formatPercent(-1), "—")
  assert.equal(Model.formatMHz(-1), "—")
  assert.equal(Model.formatWatts(-1), "—")
  assert.equal(Model.formatBytes(-1), "—")
  assert.equal(Model.formatRate(-1), "—")
  assert.equal(Model.formatBytes(1073741824), "1.0 GiB")
  assert.equal(Model.formatRate(1250), "1.25 GB/s")
})

test("appendPoint caps history and ignores missing values", () => {
  let list = []
  list = Model.appendPoint(list, 10, 1, 2)
  list = Model.appendPoint(list, 20, 2, 2)
  list = Model.appendPoint(list, 30, 3, 2)
  assert.deepEqual(list, [{ time: 2, value: 20 }, { time: 3, value: 30 }])
  assert.deepEqual(Model.appendPoint(list, -1, 4, 2), list)
})

test("appendPoint replaces a duplicate timestamp", () => {
  let list = Model.appendPoint([], 10, 1000, 10)
  list = Model.appendPoint(list, 12, 1000, 10)
  assert.deepEqual(list, [{ time: 1000, value: 12 }])
})

test("historyPoints extracts a utilization series", () => {
  const samples = [
    { timestamp: "2026-10-25T09:00:00Z", metrics: { cpu: [{ name: "utilization", value: 10, unit: "%" }] } },
    { timestamp: "2026-10-25T09:00:10Z", metrics: { cpu: [{ name: "utilization", value: 20, unit: "%" }] } },
    { timestamp: "2026-10-25T09:00:20Z", metrics: { cpu: [] } }
  ]
  const points = Model.historyPoints(samples, "cpu", "utilization")
  assert.equal(points.length, 2)
  assert.equal(points[0].value, 10)
  assert.equal(points[1].value, 20)
})

test("mergeHistory unions backfill and live points", () => {
  const base = [{ time: 1000, value: 10 }, { time: 2000, value: 20 }]
  const live = [{ time: 2000, value: 25 }, { time: 3000, value: 30 }]
  assert.deepEqual(Model.mergeHistory(base, live, 0, 10), [
    { time: 1000, value: 10 },
    { time: 2000, value: 25 },
    { time: 3000, value: 30 }
  ])
})

test("empty snapshots are safe to render", () => {
  const snapshot = Model.emptySnapshot()
  assert.equal(snapshot.hasGpu, false)
  assert.equal(Model.barLabel(snapshot, "All", false), "C--")
  assert.equal(Model.formatPercent(snapshot.gpu.utilization), "—")
})
