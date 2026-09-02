#!/usr/bin/env bash
# System stats as  cpu|mem|disk|uptime|topName|topGB
#
# CPU and memory deliberately use the SAME formulas as the SketchyBar plugins
# (plugins/cpu.sh, plugins/mem.sh). Two different numbers for "CPU" on one
# screen is worse than no number at all, so if you change one, change both.
set -uo pipefail

CPU=$(top -l 1 -n 0 2>/dev/null | awk '/CPU usage/ {
  gsub("%", "", $3); gsub("%", "", $5); printf "%.0f", $3 + $5; exit
}')

STATS=$(vm_stat)
n() { echo "$STATS" | awk -v k="$1" '$0 ~ k {gsub("\\.",""); print $NF}'; }
FREE=$(n "Pages free"); INACT=$(n "Pages inactive"); SPEC=$(n "Pages speculative")
ACT=$(n "Pages active"); WIRE=$(n "Pages wired down"); COMP=$(n "Pages occupied by compressor")
TOTAL=$((FREE + INACT + SPEC + ACT + WIRE + COMP))
USED=$((ACT + WIRE + COMP))
MEM=$(( TOTAL > 0 ? USED * 100 / TOTAL : 0 ))

DISK=$(df -H / 2>/dev/null | awk 'NR==2 {gsub("%",""); print $5}')

# "up 3 days, 4:12," -> "3d 4h"; "up 1:23," -> "1h 23m"
UP=$(uptime | sed -E 's/.*up ([^,]*(, [0-9]+ (min|hrs?))?).*/\1/' \
  | sed -E 's/([0-9]+) days?/\1d/; s/([0-9]+) mins?/\1m/; s/^ *//; s/ *$//' \
  | sed -E 's/([0-9]+):([0-9]+)/\1h \2m/')

# The biggest RSS on the box — the same thing Hammerspoon's memory guard warns
# about, shown before it gets big enough to warn.
read -r TOPRSS TOPCMD <<<"$(ps -Ao rss,comm -m 2>/dev/null | sed -n 2p)"
TOPNAME=$(basename "${TOPCMD:-?}")
TOPGB=$(awk -v r="${TOPRSS:-0}" 'BEGIN { printf "%.1f", r / 1048576 }')

printf '%s|%s|%s|%s|%s|%s\n' "${CPU:-0}" "${MEM:-0}" "${DISK:-0}" "${UP:-?}" "$TOPNAME" "$TOPGB"
