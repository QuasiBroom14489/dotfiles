#!/usr/bin/env bash
# Show the focused window's app name in the center of the bar.
#
# front_app_switched hands us the name in $INFO. Every other sender
# (bar load, workspace change, forced update) has no $INFO, so ask
# AeroSpace for the focused window instead — otherwise the label
# stays blank until the next app switch.

if [[ "$SENDER" == "front_app_switched" && -n "$INFO" ]]; then
  APP="$INFO"
else
  APP="$(aerospace list-windows --focused --format '%{app-name}' 2>/dev/null | head -1)"
fi

sketchybar --set "$NAME" label="${APP:-—}"
