#!/usr/bin/env bash
# Current upload/download rate for the default route's interface.
source "$HOME/.config/sketchybar/colors.sh"

if [ "$SENDER" = "mouse.clicked" ]; then
  if [ "$MODIFIER" = "shift" ]; then
    "$HOME/.config/sketchybar/plugins/diagnostics.sh" route
  elif [ "$BUTTON" = "right" ]; then
    "$HOME/.config/sketchybar/plugins/diagnostics.sh" bandwidth
  else
    "$HOME/.config/sketchybar/plugins/diagnostics.sh" network
  fi
  exit 0
fi

INTERFACE=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
if [ -z "$INTERFACE" ]; then
  sketchybar --set "$NAME" icon.color="$RED" label="NET offline"
  exit 0
fi

COUNTERS=$(netstat -ibn | awk -v iface="$INTERFACE" \
  '$1 == iface && $3 ~ /^<Link#/ {print $7, $10; exit}')
read -r RX TX <<< "$COUNTERS"
RX=${RX:-0}; TX=${TX:-0}

STATE_DIR="${TMPDIR:-/tmp}/sketchybar-network-${UID}"
STATE_FILE="$STATE_DIR/$INTERFACE"
mkdir -p "$STATE_DIR"
NOW=$(date +%s)

if [ -r "$STATE_FILE" ]; then
  read -r OLD_RX OLD_TX OLD_NOW < "$STATE_FILE"
else
  OLD_NOW=0
fi

if [ "$OLD_NOW" -gt 0 ] && [ "$NOW" -gt "$OLD_NOW" ]; then
  ELAPSED=$((NOW - OLD_NOW))
  DOWN=$(( (RX - OLD_RX) / ELAPSED ))
  UP=$(( (TX - OLD_TX) / ELAPSED ))
  [ "$DOWN" -lt 0 ] && DOWN=0
  [ "$UP" -lt 0 ] && UP=0
else
  DOWN=0; UP=0
fi
printf '%s %s %s\n' "$RX" "$TX" "$NOW" > "$STATE_FILE"

human_rate() {
  awk -v bytes="$1" 'BEGIN {
    if (bytes >= 1048576) printf "%.1fM", bytes / 1048576
    else if (bytes >= 1024) printf "%.0fK", bytes / 1024
    else printf "%dB", bytes
  }'
}

sketchybar --set "$NAME" icon.color="$GREEN" \
  label="↓$(human_rate "$DOWN") ↑$(human_rate "$UP")"
