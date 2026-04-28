#!/bin/bash

ON_TEMP=4000
OFF_TEMP=6000

if ! pgrep -x hyprsunset >/dev/null; then
  echo '{"text": "󰖔", "tooltip": "Nightlight off", "class": "inactive"}'
  exit 0
fi

CURRENT_TEMP=$(hyprctl hyprsunset temperature 2>/dev/null | rg -o '[0-9]+' -m 1)

if [ "$CURRENT_TEMP" = "$ON_TEMP" ]; then
  echo '{"text": "󰖔", "tooltip": "Nightlight on", "class": "active"}'
else
  echo '{"text": "󰖨", "tooltip": "Nightlight off", "class": "inactive"}'
fi
