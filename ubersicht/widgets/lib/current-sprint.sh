#!/usr/bin/env bash
# Open items from every LifeVault goal's "## Current Sprint" section.
#
# Emits one TAB-separated  goal<TAB>item  line per unchecked checkbox, which
# the focus widget parses without needing jq. Silent (exit 0, no output) when
# the vault isn't there — iCloud Drive can evict the folder, and a widget
# showing "No open items" beats one showing a shell error.
set -uo pipefail

GOALS="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeVault/03 Goals"
[[ -d "$GOALS" ]] || exit 0

for f in "$GOALS"/*.md; do
  [[ -e "$f" ]] || continue
  # "01 Encore.md" -> "Encore"
  goal="$(basename "$f" .md)"
  goal="${goal#* }"

  awk -v goal="$goal" '
    # Any h2 closes the previous section; only Current Sprint opens one.
    /^## / { in_sprint = ($0 ~ /^## Current Sprint/); next }
    in_sprint && /^- \[ \]/ {
      sub(/^- \[ \][ \t]*/, "")
      if (length($0)) print goal "\t" $0
    }
  ' "$f"
done
