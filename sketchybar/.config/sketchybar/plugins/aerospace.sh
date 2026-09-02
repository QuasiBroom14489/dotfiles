#!/usr/bin/env bash
# Highlight the current AeroSpace workspace pill.
# Called with $1 = workspace id.

source "$HOME/.config/sketchybar/colors.sh"

SID="$1"
FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null)}"

if [[ "$SID" == "$FOCUSED" ]]; then
  sketchybar --set space.$SID \
    background.color=$ACCENT_COLOR \
    icon.color=$BLACK
else
  sketchybar --set space.$SID \
    background.color=$ITEM_BG_COLOR \
    icon.color=$WHITE
fi
