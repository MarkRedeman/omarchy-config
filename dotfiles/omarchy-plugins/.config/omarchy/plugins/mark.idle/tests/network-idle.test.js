const test = require("node:test")
const assert = require("node:assert/strict")
const path = require("node:path")
const Model = require(path.join(__dirname, "..", "NetworkIdleModel.js"))

function wifi(name, connected) {
  return {
    type: "wifi",
    connected: connected !== false,
    address: "",
    connectionName: "",
    wifiNetworks: [{ name: name, connected: connected !== false }]
  }
}

function wired(connectionName, address) {
  return {
    type: "wired",
    connected: true,
    address: address || "",
    connectionName: connectionName || "",
    wifiNetworks: []
  }
}

const homeConfig = {
  ssids: ["Home Wi-Fi"],
  connectionNames: ["Home Ethernet"],
  addressPrefixes: ["192.168.2."]
}

test("matches a connected home SSID", () => {
  assert.equal(Model.isHomeNetwork([wifi("Home Wi-Fi")], homeConfig), true)
})

test("does not match a different SSID", () => {
  assert.equal(Model.isHomeNetwork([wifi("Hotel Wi-Fi")], homeConfig), false)
})

test("matches a wired connection by name", () => {
  assert.equal(Model.isHomeNetwork([wired("Home Ethernet")], homeConfig), true)
})

test("matches a connected interface by address prefix", () => {
  assert.equal(Model.isHomeNetwork([wired("Wired connection 1", "192.168.2.118")], homeConfig), true)
})

test("does not match an address outside the home prefix", () => {
  assert.equal(Model.isHomeNetwork([wired("Wired connection 1", "10.20.30.40")], homeConfig), false)
})

test("does not match a disconnected device", () => {
  const device = wifi("Home Wi-Fi", false)
  device.connected = true
  assert.equal(Model.isHomeNetwork([device], homeConfig), false)

  const disconnected = wired("Home Ethernet", "192.168.2.118")
  disconnected.connected = false
  assert.equal(Model.isHomeNetwork([disconnected], homeConfig), false)
})

test("no home rules means not home", () => {
  assert.equal(Model.isHomeNetwork([wifi("Home Wi-Fi")], {}), false)
  assert.equal(Model.isHomeNetwork([wifi("Home Wi-Fi")], null), false)
})

test("invalid and duplicate rules are ignored", () => {
  const normalized = Model.normalizeHomeConfig({
    ssids: [" Home Wi-Fi ", "", null, "Home Wi-Fi", 42],
    connectionNames: "not-an-array",
    addressPrefixes: null
  })
  assert.deepEqual(normalized.ssids, ["Home Wi-Fi", "42"])
  assert.deepEqual(normalized.connectionNames, [])
  assert.deepEqual(normalized.addressPrefixes, [])
})

test("home uses idle.screensaver and idle.lock", () => {
  const result = Model.effectiveTimeouts({
    screensaver: 900,
    lock: 3600,
    away: { screensaver: 300, lock: 900 }
  }, true)
  assert.deepEqual(result, { screensaver: 900, lock: 3600 })
})

test("away uses the away profile", () => {
  const result = Model.effectiveTimeouts({
    screensaver: 900,
    lock: 3600,
    away: { screensaver: 300, lock: 900 }
  }, false)
  assert.deepEqual(result, { screensaver: 300, lock: 900 })
})

test("missing away profile falls back to the secure defaults", () => {
  const result = Model.effectiveTimeouts({
    screensaver: 900,
    lock: 3600
  }, false)
  assert.deepEqual(result, Model.SECURE_DEFAULTS)
  assert.deepEqual(result, { screensaver: 300, lock: 900 })
})

test("missing home values fall back to Omarchy's defaults", () => {
  const result = Model.effectiveTimeouts({}, true)
  assert.deepEqual(result, Model.HOME_DEFAULTS)
  assert.deepEqual(result, { screensaver: 150, lock: 300 })
})

test("zero deliberately disables a timeout in either profile", () => {
  assert.deepEqual(Model.effectiveTimeouts({
    screensaver: 900,
    lock: 3600,
    away: { screensaver: 0, lock: 900 }
  }, false), { screensaver: 0, lock: 900 })

  assert.deepEqual(Model.effectiveTimeouts({
    screensaver: 0,
    lock: 0
  }, true), { screensaver: 0, lock: 0 })
})

test("invalid timeout values fall back per key", () => {
  const result = Model.effectiveTimeouts({
    screensaver: "not-a-number",
    lock: -5,
    away: { screensaver: null, lock: 900 }
  }, false)
  assert.deepEqual(result, { screensaver: 300, lock: 900 })
})
