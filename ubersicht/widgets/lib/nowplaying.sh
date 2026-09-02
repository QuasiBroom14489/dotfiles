#!/usr/bin/env bash
# Current Spotify track, as  state|title|artist|position|duration
#
# Two guards matter here:
#   * pgrep first. `tell application "Spotify"` LAUNCHES Spotify if it isn't
#     running, so an unguarded widget would start the music player every 5s
#     forever.
#   * try/on error inside the AppleScript. With Spotify open but nothing
#     loaded, `name of current track` raises -1728 rather than returning empty.
set -uo pipefail

pgrep -xq Spotify || exit 0

osascript 2>/dev/null <<'AS'
tell application "Spotify"
  try
    if player state is stopped then return ""
    set t to name of current track
    set a to artist of current track
    set p to player position
    set d to (duration of current track) / 1000
    return (player state as text) & "|" & t & "|" & a & "|" & (p as integer) & "|" & (d as integer)
  on error
    return ""
  end try
end tell
AS
