#!/usr/bin/env bash
#
# Install the TopsWatch telemetry daemon used by mark.hardware-monitor.
#
# TopsWatch is the collector, not part of the plugin. It needs privileged
# access to RAPL, Intel PMT, and the xe PMU; the default unit runs it as a
# dynamic user with only the capabilities it needs. Pass --root if the
# capability setup does not work on your kernel.
#
# The build is pinned because TopsWatch has no tagged releases yet. Bump
# TOPSWATCH_REV deliberately after reviewing upstream changes.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TOPSWATCH_REPO="https://github.com/scottmbaker/topswatch.git"
# 2026-10-21: per-engine GPU utilization and media-GT clock landed here.
TOPSWATCH_REV="bfd355cd581df7877a306fa9a6356406e7859a6a"
SRC_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/topswatch/src"

BIN_PATH="/usr/local/bin/topswatch"
CONFIG_PATH="/etc/topswatch.yaml"
UNIT_PATH="/etc/systemd/system/topswatch.service"

MODE="caps"
DO_UNINSTALL=0
REV="$TOPSWATCH_REV"

usage() {
  cat <<'USAGE'
Usage: install-topswatch.sh [options]

Installs TopsWatch, its config, and a hardened systemd unit, then verifies
that the local API publishes the Panther Lake metrics the plugin needs.

Options:
  --root            Run the daemon as root instead of a capped dynamic user.
                    Use this if GPU/NPU metrics are missing after the default
                    install.
  --rev <git-ref>   Build a different TopsWatch revision (default: pinned).
  --src <dir>       Use a different source checkout directory.
  --uninstall       Stop and remove the service, config, and binary.
  -h, --help        Show this help.

After installation, enable the plugin if it is not already on the bar:

  omarchy-shell shell rescanPlugins
  omarchy plugin enable mark.hardware-monitor --section right --after omarchy.agents
USAGE
}

say() { printf '%s\n' "$*"; }
die() { printf 'install-topswatch: %s\n' "$*" >&2; exit 1; }

while (($# > 0)); do
  case "$1" in
    --root) MODE="root"; shift ;;
    --rev)
      [[ -n ${2:-} ]] || die "--rev requires a git ref"
      REV="$2"; shift 2 ;;
    --src)
      [[ -n ${2:-} ]] || die "--src requires a directory"
      SRC_DIR="$2"; shift 2 ;;
    --uninstall) DO_UNINSTALL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v sudo >/dev/null 2>&1 || die "sudo is required"
say "Requesting sudo once for the service install…"
sudo -v

if ((DO_UNINSTALL)); then
  say "Stopping and removing TopsWatch…"
  sudo systemctl disable --now topswatch 2>/dev/null || true
  sudo rm -f "$UNIT_PATH" "$CONFIG_PATH" "$BIN_PATH"
  sudo systemctl daemon-reload
  say "Removed the service, config, and binary. The plugin itself is untouched."
  exit 0
fi

for tool in git go curl python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    case "$tool" in
      go) say "Installing Go…"; omarchy-pkg-add go ;;
      git) say "Installing git…"; omarchy-pkg-add git ;;
      curl) say "Installing curl…"; omarchy-pkg-add curl ;;
      python3) say "Installing python…"; omarchy-pkg-add python ;;
    esac
  fi
done

for tool in git go curl python3; do
  command -v "$tool" >/dev/null 2>&1 || die "$tool is still unavailable"
done

say "Building TopsWatch at $REV…"
mkdir -p "$(dirname "$SRC_DIR")"
if [[ ! -d "$SRC_DIR/.git" ]]; then
  git clone "$TOPSWATCH_REPO" "$SRC_DIR"
fi
git -C "$SRC_DIR" remote set-url origin "$TOPSWATCH_REPO"
git -C "$SRC_DIR" fetch --depth 1 origin "$REV"
git -C "$SRC_DIR" checkout --detach --force FETCH_HEAD
(
  cd "$SRC_DIR"
  CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o "$SRC_DIR/topswatch" ./cmd/topswatch
)

say "Installing binary, config, and unit…"
sudo install -Dm0755 "$SRC_DIR/topswatch" "$BIN_PATH"
sudo install -Dm0644 "$SCRIPT_DIR/topswatch.yaml" "$CONFIG_PATH"
if [[ "$MODE" == "root" ]]; then
  sudo install -Dm0644 "$SCRIPT_DIR/topswatch-root.service" "$UNIT_PATH"
  say "Using the root fallback unit."
else
  sudo install -Dm0644 "$SCRIPT_DIR/topswatch.service" "$UNIT_PATH"
  say "Using the capped dynamic-user unit."
fi

sudo systemctl daemon-reload
sudo systemctl enable topswatch >/dev/null || true
sudo systemctl restart topswatch || true

say "Waiting for the local API…"
TMP_JSON="$(mktemp)"
trap 'rm -f "$TMP_JSON"' EXIT
ready=0
for _ in $(seq 1 40); do
  if curl -fsS --max-time 1 http://127.0.0.1:9876/api/metrics/latest -o "$TMP_JSON" 2>/dev/null; then
    ready=1
    break
  fi
  sleep 0.5
done

if ((ready == 0)) || [[ ! -s "$TMP_JSON" ]]; then
  say "TopsWatch did not answer on http://127.0.0.1:9876/api/metrics/latest"
  say "Recent service log:"
  sudo journalctl -u topswatch -n 40 --no-pager || true
  die "service did not start; fix the log above, then rerun this script"
fi

# Delta-based metrics (GPU utilization, power) need a prior sample. Give the
# daemon two more collection ticks before judging what it publishes.
sleep 2
curl -fsS --max-time 2 http://127.0.0.1:9876/api/metrics/latest -o "$TMP_JSON" || true

say ""
say "TopsWatch is running. Published metrics:"
python3 - "$TMP_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    sample = json.load(handle)

metrics = sample.get("metrics", {})
def has(module, name):
    return any(item.get("name") == name for item in metrics.get(module, []))

checks = [
    ("cpu utilization", has("cpu", "utilization")),
    ("cpu power (RAPL)", has("cpu", "power")),
    ("gpu frequency", has("gpu", "frequency_actual")),
    ("gpu utilization (perf)", has("gpu", "utilization")),
    ("gpu per-engine busy", has("gpu", "engine_busy")),
    ("gpu media clock", has("gpu", "media_frequency_actual")),
    ("gpu power (RAPL/PMT)", has("gpu", "power")),
    ("npu utilization (sysfs)", has("npu", "utilization")),
    ("npu frequency (PMT)", has("npu", "frequency")),
    ("npu power (PMT)", has("npu", "power")),
    ("npu temperature (PMT)", has("npu", "temperature")),
    ("npu DDR bandwidth (PMT)", has("npu", "ddr_bandwidth")),
    ("npu memory (sysfs)", has("npu", "memory_used")),
]
for label, ok in checks:
    print(f"  {'yes' if ok else 'no '}  {label}")

missing = [label for label, ok in checks if not ok]
if missing:
    print()
    print("Some metrics are unavailable. If GPU utilization or the NPU PMT")
    print("metrics are missing, rerun this script with --root:")
    print("  scripts/install-topswatch.sh --root")
    print("Then inspect: sudo journalctl -u topswatch -n 60 --no-pager")
PY

say ""
say "Service:  systemctl status topswatch"
say "Web UI:   http://127.0.0.1:9876"
say "Plugin:   omarchy-shell shell rescanPlugins"
say "          omarchy plugin enable mark.hardware-monitor --section right --after omarchy.agents"
