// Pure home-network detection and idle-timeout selection for mark.idle.
//
// Kept free of QML so the network match and timeout fallbacks can be tested
// with `node --test`. Service.qml turns Quickshell's Networking model into the
// plain device snapshots these functions expect.

// Used whenever the current network is not the configured home network. These
// are deliberately the secure fallbacks: a missing or unreadable local network
// config must not silently restore long at-home timeouts.
var SECURE_DEFAULTS = { screensaver: 300, lock: 900 }

// Upstream - and therefore the same fallback when at home without explicit
// idle.screensaver / idle.lock values.
var HOME_DEFAULTS = { screensaver: 150, lock: 300 }

function stringList(value) {
  if (!Array.isArray(value)) return []
  var out = []
  for (var i = 0; i < value.length; i++) {
    var text = String(value[i] === undefined || value[i] === null ? "" : value[i]).trim()
    if (text !== "" && out.indexOf(text) === -1) out.push(text)
  }
  return out
}

function objectOrEmpty(value) {
  return value && typeof value === "object" && !Array.isArray(value) ? value : {}
}

function normalizeHomeConfig(config) {
  var source = objectOrEmpty(config)
  return {
    ssids: stringList(source.ssids),
    connectionNames: stringList(source.connectionNames),
    addressPrefixes: stringList(source.addressPrefixes)
  }
}

function hasHomeRules(config) {
  var normalized = normalizeHomeConfig(config)
  return normalized.ssids.length > 0
    || normalized.connectionNames.length > 0
    || normalized.addressPrefixes.length > 0
}

function networkMatches(device, config) {
  if (!device || device.connected !== true) return false

  var address = String(device.address || "")
  for (var a = 0; a < config.addressPrefixes.length; a++) {
    if (address.indexOf(config.addressPrefixes[a]) === 0) return true
  }

  var connectionName = String(device.connectionName || "")
  if (connectionName !== "" && config.connectionNames.indexOf(connectionName) !== -1)
    return true

  var networks = Array.isArray(device.wifiNetworks) ? device.wifiNetworks : []
  for (var n = 0; n < networks.length; n++) {
    var network = networks[n]
    if (!network || network.connected !== true) continue
    if (config.ssids.indexOf(String(network.name || "")) !== -1) return true
  }

  return false
}

function isHomeNetwork(devices, homeConfig) {
  var config = normalizeHomeConfig(homeConfig)
  // No rules means home detection is not configured. Callers then use the
  // secure away defaults rather than assuming home.
  if (!hasHomeRules(config)) return false

  var list = Array.isArray(devices) ? devices : []
  for (var i = 0; i < list.length; i++) {
    if (networkMatches(list[i], config)) return true
  }
  return false
}

function timeoutValue(value, fallback) {
  if (value === null || value === undefined || value === "") return fallback
  var number = Number(value)
  if (!isFinite(number) || number < 0) return fallback
  return Math.floor(number)
}

function effectiveTimeouts(idleConfig, onHome) {
  var config = objectOrEmpty(idleConfig)

  if (onHome) {
    return {
      screensaver: timeoutValue(config.screensaver, HOME_DEFAULTS.screensaver),
      lock: timeoutValue(config.lock, HOME_DEFAULTS.lock)
    }
  }

  var away = objectOrEmpty(config.away)
  return {
    screensaver: timeoutValue(away.screensaver, SECURE_DEFAULTS.screensaver),
    lock: timeoutValue(away.lock, SECURE_DEFAULTS.lock)
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    SECURE_DEFAULTS: SECURE_DEFAULTS,
    HOME_DEFAULTS: HOME_DEFAULTS,
    normalizeHomeConfig: normalizeHomeConfig,
    hasHomeRules: hasHomeRules,
    isHomeNetwork: isHomeNetwork,
    effectiveTimeouts: effectiveTimeouts
  }
}
