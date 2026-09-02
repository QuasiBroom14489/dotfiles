#!/usr/bin/env bash
# Memory pressure indicator — green (healthy) → yellow (warm) → red (critical)
source "$HOME/.config/sketchybar/colors.sh"

if [ "$SENDER" = "mouse.clicked" ]; then
  "$HOME/.config/sketchybar/plugins/diagnostics.sh" performance
  exit 0
fi

# Free % from vm_stat (pages free + inactive as "available")
PAGE_SIZE=$(vm_stat | head -1 | awk '{print $8}')
STATS=$(vm_stat)
FREE=$(echo "$STATS"  | awk '/Pages free/            {gsub("\\.",""); print $3}')
INACT=$(echo "$STATS" | awk '/Pages inactive/        {gsub("\\.",""); print $3}')
SPEC=$(echo "$STATS"  | awk '/Pages speculative/     {gsub("\\.",""); print $3}')
ACT=$(echo "$STATS"   | awk '/Pages active/          {gsub("\\.",""); print $3}')
WIRE=$(echo "$STATS"  | awk '/Pages wired down/      {gsub("\\.",""); print $4}')
COMP=$(echo "$STATS"  | awk '/Pages occupied by compressor/ {gsub("\\.",""); print $5}')

TOTAL=$((FREE + INACT + SPEC + ACT + WIRE + COMP))
USED=$((ACT + WIRE + COMP))
PCT=$(( USED * 100 / TOTAL ))

if   [ "$PCT" -ge 90 ]; then ICON=""; COLOR=$RED
elif [ "$PCT" -ge 75 ]; then ICON=""; COLOR=$YELLOW
else                         ICON=""; COLOR=$GREEN
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="MEM ${PCT}%"
