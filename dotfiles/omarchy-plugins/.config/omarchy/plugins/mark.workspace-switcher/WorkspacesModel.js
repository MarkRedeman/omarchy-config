// Shared workspace list/sort/cycle logic for mark.workspace-switcher.
//
// `.pragma library` makes this module a singleton per QML engine, so the
// named-workspace ordering registry below is shared between Panel.qml and
// every Widget instance.
//
// Facts this encodes (verified against Hyprland 0.56.2):
//   * Numeric workspaces have positive ids (name == String(id)); ids >= 1
//     include anything above 10 created by e+1-style cycling.
//   * NAMED workspaces all share one negative id (-1337 during testing), so
//     ids are useless as keys or orderings for them. They are addressed and
//     sorted by NAME only.
//   * Special workspaces are negative-id entries whose names start with
//     "special:"; they never appear in lists or cycling.
//   * Empty workspaces are destroyed immediately once unfocused, so the bar
//     and cycling universe is "existing" only.
//
// Ordering (locked): 1..10 ascending first, then any other numeric
// workspaces ascending, then named workspaces in the order they were first
// seen being created (tracked via createworkspace events). Recreated named
// workspaces keep their original position while the shell lives.
.pragma library

// First-seen order of named workspace names. Shared module state.
var _namedOrder = []

function noteNamed(name) {
  var key = String(name || "")
  if (key === "" || _namedOrder.indexOf(key) !== -1) return
  _namedOrder.push(key)
}

function forgetNamed(name) {
  var index = _namedOrder.indexOf(String(name || ""))
  if (index !== -1) _namedOrder.splice(index, 1)
}

function namedCount() {
  return _namedOrder.length
}

function isNumeric(record) {
  return record.id >= 1
}

// Human label: workspace name, or the number ("10" renders as "0").
function displayOf(record) {
  if (record.name !== "") return record.name
  return record.id === 10 ? "0" : String(record.id)
}

// Build plain records out of Quickshell Hyprland workspace objects.
// Pass monitorName (focused monitor) to scope the list, or null for all.
// Numeric workspaces become { name: "" } records; named workspaces keep
// their (colliding) id untouched but are always addressed by name.
function list(workspacesValues, monitorName) {
  var out = []
  for (var i = 0; i < workspacesValues.length; i++) {
    var ws = workspacesValues[i]
    if (!ws || typeof ws.id !== "number") continue

    var name = String(ws.name || "")
    var monitor = ws.monitor && ws.monitor.name ? String(ws.monitor.name) : ""
    if (monitorName && monitor !== monitorName) continue

    if (ws.id >= 1) {
      // Numeric workspace; displayOf() renders it (id 10 as "0").
      out.push({ id: ws.id, name: "", monitor: monitor,
                 windows: ws.toplevels ? ws.toplevels.values.length : 0 })
      continue
    }

    // Negative-id space: specials are excluded by name prefix, everything
    // else is a named workspace (their ids collide, so name is the key).
    if (name.indexOf("special:") === 0 || name === "special") continue
    noteNamed(name)
    out.push({ id: ws.id, name: name, monitor: monitor,
               windows: ws.toplevels ? ws.toplevels.values.length : 0 })
  }

  sortRecords(out)
  return out
}

function compareRecords(a, b) {
  var aNum = isNumeric(a)
  var bNum = isNumeric(b)

  if (aNum !== bNum) return aNum ? -1 : 1

  if (aNum && bNum) {
    // 1..10 first, then higher numbers, each ascending.
    var aLow = a.id <= 10
    var bLow = b.id <= 10
    if (aLow !== bLow) return aLow ? -1 : 1
    return a.id - b.id
  }

  // Both named: creation order (unknown names go last, oldest first).
  var ai = _namedOrder.indexOf(a.name)
  var bi = _namedOrder.indexOf(b.name)
  if (ai === -1 && bi === -1) return a.name.toLowerCase() < b.name.toLowerCase() ? -1 : 1
  if (ai === -1) return 1
  if (bi === -1) return -1
  return ai - bi
}

function sortRecords(records) {
  records.sort(compareRecords)
}

// Match against the currently focused workspace: named spaces must compare
// by name because their ids collide.
function sameSpace(record, focusedWorkspace) {
  if (!focusedWorkspace) return false
  if (record.name !== "") return record.name === String(focusedWorkspace.name || "")
  return record.id === focusedWorkspace.id
}

function indexOfFocused(records, focusedWorkspace) {
  for (var i = 0; i < records.length; i++)
    if (sameSpace(records[i], focusedWorkspace)) return i
  return -1
}

// Wrap-only cycle across existing workspaces. Returns the target record or
// null. direction: "next" | "prev". Never creates or destroys anything.
function cycle(records, focusedWorkspace, direction) {
  if (!records.length) return null
  var index = indexOfFocused(records, focusedWorkspace)
  if (index === -1) index = direction === "prev" ? records.length - 1 : 0
  else if (direction === "prev") index = (index - 1 + records.length) % records.length
  else index = (index + 1) % records.length
  return records[index]
}

// Lua string literal for hl.dsp.focus({ workspace = … }): named spaces go by
// "name:x", numeric by id. Returns the inner value only (unquoted).
function focusRef(record) {
  if (record.name !== "") return "name:" + record.name
  return String(record.id)
}

// Shell command (single-quoted for bash) that focuses this workspace via the
// Lua dispatcher path — plain hyprctl string dispatches don't resolve under
// quattro's Lua config.
function focusCommand(record) {
  var ref = focusRef(record).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
  return "hyprctl dispatch 'hl.dsp.focus({ workspace = \"" + ref + "\" })'"
}
