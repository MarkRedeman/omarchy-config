#!/bin/bash

STATE_FILE="$HOME/.local/state/omarchy/toggles/hypr/touchpad-disabled.conf"

if [[ -f "$STATE_FILE" ]]; then
  echo '{"text": "󰟸", "tooltip": "Touchpad disabled (click to enable)", "class": "active"}'
else
  echo '{"text": ""}'
fi
