#!/usr/bin/env bash
source "$HOME/.config/sketchybar/colors.sh"

PERCENT=$(pmset -g batt | grep -Eo '\d+%' | cut -d% -f1)
CHARGING=$(pmset -g batt | grep 'AC Power')

case "$PERCENT" in
  9[0-9]|100) ICON=""; COLOR=$GREEN ;;
  [7-8][0-9]) ICON=""; COLOR=$GREEN ;;
  [5-6][0-9]) ICON=""; COLOR=$YELLOW ;;
  [3-4][0-9]) ICON=""; COLOR=$YELLOW ;;
  [1-2][0-9]) ICON=""; COLOR=$RED ;;
  *)          ICON=""; COLOR=$RED ;;
esac

[[ -n "$CHARGING" ]] && ICON=""

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="${PERCENT}%"
