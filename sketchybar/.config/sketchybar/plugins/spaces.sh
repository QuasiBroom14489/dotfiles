#!/usr/bin/env bash
# Paint the desktop pills. Runs on space_change / display_change / wake.
#
# Hammerspoon answers "how many regular desktops, and which one is focused"
# in one round trip. Full-screen app Spaces are skipped so pill N matches
# Hyper+N. When a full-screen app is focused, no pill is highlighted.

source "$HOME/.config/sketchybar/colors.sh"

read -r COUNT CURRENT < <(/opt/homebrew/bin/hs -t 2 -c '
  local f, n, cur = hs.spaces.focusedSpace(), 0, 0
  for _, id in ipairs(hs.spaces.spacesForScreen() or {}) do
    if hs.spaces.spaceType(id) == "user" then
      n = n + 1
      if id == f then cur = n end
    end
  end
  return n .. " " .. cur' </dev/null 2>/dev/null | tail -1)

# Hammerspoon not up yet (e.g. first seconds after login): show nothing
# rather than a wrong number; the next Space change repaints.
[[ "$COUNT" =~ ^[0-9]+$ ]] || exit 0

args=()
for sid in 1 2 3 4 5 6 7 8 9; do
  if (( sid > COUNT )); then
    args+=(--set space.$sid drawing=off)
  elif (( sid == CURRENT )); then
    args+=(--set space.$sid drawing=on background.color=$ACCENT_COLOR icon.color=$BLACK)
  else
    args+=(--set space.$sid drawing=on background.color=$ITEM_BG_COLOR icon.color=$WHITE)
  fi
done
sketchybar "${args[@]}"
