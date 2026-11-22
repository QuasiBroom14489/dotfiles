#!/usr/bin/env bash
# Show the frontmost app's name in the center of the bar.
#
# front_app_switched hands us the name in $INFO. Every other sender
# (bar load, Space change, forced update) has no $INFO, so ask
# LaunchServices for the frontmost app instead — otherwise the label
# stays blank until the next app switch. lsappinfo needs no permissions.

if [[ "$SENDER" == "front_app_switched" && -n "$INFO" ]]; then
  APP="$INFO"
else
  APP="$(lsappinfo info -only name "$(lsappinfo front)" 2>/dev/null | sed -n 's/.*"=\"\(.*\)\"$/\1/p')"
fi

sketchybar --set "$NAME" label="${APP:-—}"
