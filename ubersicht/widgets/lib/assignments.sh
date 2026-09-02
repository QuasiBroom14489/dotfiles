#!/usr/bin/env bash
# Open, dated assignments across every LifeVault class folder.
#
# Emits TAB-separated  dueISO<TAB>course<TAB>title  lines, sorted by due date,
# overdue first. Silent (exit 0) if the vault isn't mounted — iCloud evicts
# folders, and an empty card beats a shell error rendered on the desktop.
#
# Source lines look like either of these, from Canvas sync or hand-written:
#   - [ ] PS02 [due:: 2026-09-03] · Thu Sep 3 · 12:30 PM [https://canvas...]
#   - [ ] Complete reading assignment (Canvas/Zybooks) [due:: 2026-08-26]
set -uo pipefail

ACADEMICS="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeVault/04 Areas/Academics"
[[ -d "$ACADEMICS" ]] || exit 0

# Anything older than this is stale rather than actionable — a semester's worth
# of un-ticked boxes would bury the two things due tomorrow.
CUTOFF="$(date -v-14d +%Y-%m-%d)"

for dir in "$ACADEMICS"/*/; do
  f="$dir/Assignments.md"
  [[ -f "$f" ]] || continue

  # "CSE20110 Discrete Mathematics" -> "CSE 20110"
  base="$(basename "$dir")"
  code="${base%% *}"
  course="$(echo "$code" | sed -E 's/^([A-Z]+)([0-9]+)$/\1 \2/')"

  awk -v course="$course" -v cutoff="$CUTOFF" '
    /^- \[ \]/ {
      line = $0
      if (match(line, /\[due:: [0-9]{4}-[0-9]{2}-[0-9]{2}\]/) == 0) next
      due = substr(line, RSTART + 7, 10)
      if (due < cutoff) next

      title = line
      sub(/^- \[ \][ \t]*/, "", title)
      sub(/[ \t]*\[due:: [0-9-]+\].*$/, "", title)   # marker and everything after
      gsub(/^[ \t]+|[ \t]+$/, "", title)
      if (length(title)) print due "\t" course "\t" title
    }
  ' "$f"
done | sort
