#!/usr/bin/env bash
# Lightweight CPU indicator. Click to open the full bottom dashboard.
source "$HOME/.config/sketchybar/colors.sh"

if [ "$SENDER" = "mouse.clicked" ]; then
  "$HOME/.config/sketchybar/plugins/diagnostics.sh" performance
  exit 0
fi

PCT=$(top -l 1 -n 0 | awk '/CPU usage/ {
  gsub("%", "", $3)
  gsub("%", "", $5)
  printf "%.0f", $3 + $5
  exit
}')
PCT=${PCT:-0}

if   [ "$PCT" -ge 90 ]; then COLOR=$RED
elif [ "$PCT" -ge 70 ]; then COLOR=$YELLOW
else                         COLOR=$CYAN
fi

sketchybar --set "$NAME" icon.color="$COLOR" label="CPU ${PCT}%"
