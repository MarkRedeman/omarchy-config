#!/usr/bin/env bash

set -euo pipefail

TRANSITION_FILE="/tmp/waybar_tailscale_transition"
TRANSITION_SECONDS=2

get_status_json() {
  tailscale status --json 2>/dev/null || true
}

backend_state() {
  local status_json
  status_json="$(get_status_json)"
  if [[ -z "$status_json" ]]; then
    echo "Unavailable"
    return
  fi
  jq -r '.BackendState // "Unavailable"' <<<"$status_json"
}

status_class() {
  case "$(backend_state)" in
    Running) echo "connected" ;;
    Starting) echo "connecting" ;;
    Stopping) echo "disconnecting" ;;
    NoState|Stopped|NeedsLogin|Unavailable|*) echo "stopped" ;;
  esac
}

self_hostname() {
  local status_json
  status_json="$(get_status_json)"
  [[ -z "$status_json" ]] && { echo "Unknown"; return; }
  jq -r '.Self.HostName // .Self.DNSName // "Unknown"' <<<"$status_json"
}

self_tailnet() {
  local status_json login_name
  status_json="$(get_status_json)"
  [[ -z "$status_json" ]] && { echo "Unknown"; return; }
  login_name="$(jq -r '.CurrentTailnet.Name // .Self.UserProfile.LoginName // "Unknown"' <<<"$status_json")"
  echo "$login_name"
}

self_ip4() {
  local status_json
  status_json="$(get_status_json)"
  [[ -z "$status_json" ]] && { echo "Unavailable"; return; }
  jq -r '.Self.TailscaleIPs[0] // "Unavailable"' <<<"$status_json"
}

peer_counts() {
  local status_json total online
  status_json="$(get_status_json)"
  [[ -z "$status_json" ]] && { echo "0 0"; return; }
  total="$(jq -r '(.Peer // {}) | to_entries | length' <<<"$status_json")"
  online="$(jq -r '(.Peer // {}) | to_entries | map(select(.value.Online == true)) | length' <<<"$status_json")"
  echo "$online $total"
}

exit_node() {
  local status_json
  status_json="$(get_status_json)"
  [[ -z "$status_json" ]] && { echo "None"; return; }
  jq -r '.Self.ExitNodeStatus.Online // .Self.ExitNodeStatus.ID // "None"' <<<"$status_json"
}

tooltip_text() {
  local cls host tailnet ip4 peers_online peers_total exitnode
  cls="$(status_class)"

  if [[ "$cls" == "stopped" ]]; then
    printf 'Tailscale off\nClick to connect'
    return
  fi

  host="$(self_hostname)"
  tailnet="$(self_tailnet)"
  ip4="$(self_ip4)"
  read -r peers_online peers_total <<<"$(peer_counts)"
  exitnode="$(exit_node)"

  printf 'Tailscale: connected\nHost: %s\nTailnet: %s\nIP: %s\nPeers: %s/%s online\nExit node: %s\nClick to disconnect' \
    "$host" "$tailnet" "$ip4" "$peers_online" "$peers_total" "$exitnode"
}

show_status() {
  local cls alt tip
  cls="$(status_class)"
  case "$cls" in
    connected)
      alt="connected"
      ;;
    connecting)
      alt="connecting"
      ;;
    disconnecting)
      alt="disconnecting"
      ;;
    *)
      alt="stopped"
      ;;
  esac

  tip="$(tooltip_text)"
  jq -nc \
    --arg text "" \
    --arg class "$cls" \
    --arg alt "$alt" \
    --arg tooltip "$tip" \
    '{text:$text,class:$class,alt:$alt,tooltip:$tooltip}'
}

in_transition() {
  if [[ ! -f "$TRANSITION_FILE" ]]; then
    return 1
  fi

  local ts now
  ts="$(cut -d: -f1 "$TRANSITION_FILE" 2>/dev/null || true)"
  [[ -z "$ts" ]] && return 1
  now="$(date +%s)"

  if (( now - ts < TRANSITION_SECONDS )); then
    return 0
  fi

  rm -f "$TRANSITION_FILE"
  return 1
}

set_transition() {
  local state="$1"
  printf '%s:%s\n' "$(date +%s)" "$state" > "$TRANSITION_FILE"
}

transition_state() {
  cut -d: -f2 "$TRANSITION_FILE" 2>/dev/null || true
}

toggle() {
  local cls
  cls="$(status_class)"

  if [[ "$cls" == "connected" ]]; then
    set_transition "disconnecting"
    tailscale down >/dev/null 2>&1 || true
  else
    set_transition "connecting"
    tailscale up >/dev/null 2>&1 || true
  fi

  show_status
}

case "${1:-}" in
  --status)
    if in_transition; then
      state="$(transition_state)"
      if [[ "$state" == "connecting" || "$state" == "disconnecting" ]]; then
        jq -nc --arg text "" --arg class "$state" --arg alt "$state" --arg tooltip "Tailscale $state..." '{text:$text,class:$class,alt:$alt,tooltip:$tooltip}'
        exit 0
      fi
    fi
    show_status
    ;;
  --toggle)
    toggle
    ;;
  *)
    echo "Usage: $0 --status|--toggle" >&2
    exit 1
    ;;
esac
