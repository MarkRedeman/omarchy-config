"use strict"

const test = require("node:test")
const assert = require("node:assert/strict")

const logic = require("../NotificationLogic.js")

const URGENCY = { Low: 0, Normal: 1, Critical: 2 }
const DURATIONS = {
  lowUrgency: URGENCY.Low,
  low: 5000,
  normal: 8000,
  max: 30000
}

function notification(overrides) {
  return Object.assign({
    id: 7,
    appName: "Chromium",
    appIcon: "",
    summary: "Daan Krol",
    body: "Hello",
    urgency: URGENCY.Critical,
    expireTimeout: 0,
    hints: {},
    actions: []
  }, overrides || {})
}

test("critical browser chats get the normal lifetime", () => {
  const snapshot = logic.snapshotOf(notification(), 1000, URGENCY.Critical)
  assert.equal(snapshot.sticky, false)
  assert.equal(logic.popupDuration(snapshot.urgency, snapshot.expireTimeout, snapshot.sticky, DURATIONS), 8000)
})

test("critical browser calls stay sticky by wording", () => {
  const snapshot = logic.snapshotOf(notification({
    summary: "Daan Krol is calling you",
    body: ""
  }), 1000, URGENCY.Critical)
  assert.equal(snapshot.sticky, true)
  assert.equal(logic.popupDuration(snapshot.urgency, snapshot.expireTimeout, snapshot.sticky, DURATIONS), 0)
})

test("critical browser calls stay sticky by action", () => {
  const snapshot = logic.snapshotOf(notification({
    actions: [
      { identifier: "decline", text: "Decline" },
      { identifier: "answer", text: "Answer" }
    ]
  }), 1000, URGENCY.Critical)
  assert.equal(snapshot.sticky, true)
})

test("native critical alerts stay sticky", () => {
  for (const appName of ["notify-send", "omarchy-action", "systemd"]) {
    const snapshot = logic.snapshotOf(notification({
      appName,
      summary: "Battery low",
      body: "Plug in"
    }), 1000, URGENCY.Critical)
    assert.equal(snapshot.sticky, true, appName)
  }
})

test("non-critical notifications are never sticky", () => {
  const snapshot = logic.snapshotOf(notification({
    summary: "Daan Krol is calling you",
    urgency: URGENCY.Normal
  }), 1000, URGENCY.Critical)
  assert.equal(snapshot.sticky, false)
})

test("popupDuration mirrors the old low/normal/critical lifetimes", () => {
  assert.equal(logic.popupDuration(URGENCY.Low, 0, false, DURATIONS), 5000)
  assert.equal(logic.popupDuration(URGENCY.Normal, 0, false, DURATIONS), 8000)
  assert.equal(logic.popupDuration(URGENCY.Critical, 0, false, DURATIONS), 8000)
  assert.equal(logic.popupDuration(URGENCY.Critical, 0, true, DURATIONS), 0)
})

test("popupDuration honours and clamps a requested timeout", () => {
  assert.equal(logic.popupDuration(URGENCY.Normal, 12000, false, DURATIONS), 12000)
  assert.equal(logic.popupDuration(URGENCY.Low, 100, false, DURATIONS), 5000)
  assert.equal(logic.popupDuration(URGENCY.Normal, 60000, false, DURATIONS), 30000)
  assert.equal(logic.popupDuration(URGENCY.Normal, -1, false, DURATIONS), 8000)
})

test("pickHistoryRow walks backwards from the newest entry", () => {
  const rows = [{ timestamp: 3000 }, { timestamp: 2000 }, { timestamp: 1000 }]
  assert.equal(logic.pickHistoryRow(rows, 0), rows[0])
  assert.equal(logic.pickHistoryRow(rows, 3000), rows[1])
  assert.equal(logic.pickHistoryRow(rows, 2000), rows[2])
  assert.equal(logic.pickHistoryRow(rows, 1000), null)
  assert.equal(logic.pickHistoryRow([], 0), null)
})

test("sticky survives history and persistence round-trips", () => {
  assert.equal(logic.historyEntry({ sticky: true }, URGENCY.Normal).sticky, true)
  assert.equal(logic.historyEntry({}, URGENCY.Normal).sticky, false)

  const serialized = logic.serializePopup({
    id: 4,
    originalId: 4,
    app: "Chromium",
    summary: "Daan Krol is calling you",
    body: "",
    urgency: URGENCY.Critical,
    timestamp: 5000,
    sticky: true
  }, URGENCY.Normal)
  const parsed = logic.parsePopupFiles(serialized, URGENCY.Normal)

  assert.equal(parsed.length, 1)
  assert.equal(parsed[0].sticky, true)
  assert.equal(parsed[0].summary, "Daan Krol is calling you")
})
