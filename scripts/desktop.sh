#!/usr/bin/env bash
# macOS desktop presentation — the `defaults` half of the rice.
#
#   ./scripts/desktop.sh            apply
#   ./scripts/desktop.sh --restore  put every key back to the system default
#
# Idempotent: re-running applies the same values. Nothing here is destructive
# — every setting is a preference key that --restore deletes, after which the
# OS falls back to its built-in behaviour.
set -euo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; RESET='\033[0m'
say() { printf "${BLUE}▸${RESET} %s\n" "$*"; }
ok()  { printf "${GREEN}✓${RESET} %s\n" "$*"; }

MODE="${1:-apply}"

# domain key type value  — every key this script owns, in one table, so apply
# and restore can never drift apart.
SETTINGS=(
  # ── Dock: present but unreachable. AeroSpace + Raycast cover everything it
  # did, and a 1000s autohide delay means it never appears on an accidental
  # cursor trip to the bottom edge. `killall Dock` still brings it back for a
  # deliberate Mission Control gesture.
  "com.apple.dock|autohide|-bool|true"
  "com.apple.dock|autohide-delay|-float|1000"
  "com.apple.dock|autohide-time-modifier|-float|0"
  "com.apple.dock|show-recents|-bool|false"
  "com.apple.dock|expose-animation-duration|-float|0.1"
  "com.apple.dock|springboard-show-duration|-float|0.1"
  "com.apple.dock|springboard-hide-duration|-float|0.1"

  # ── Stop a click on the wallpaper from sweeping every window off-screen.
  # macOS 14 turned this on by default and it is actively hostile to a tiling
  # WM: with widgets on the desktop you now have three cards you cannot click
  # without losing your layout.
  "com.apple.WindowManager|EnableStandardClickToShowDesktop|-bool|false"

  # ── No icons on the desktop. The desktop is a surface for Übersicht
  # widgets and the wallpaper, not a dumping ground. Files are still in
  # ~/Desktop, still reachable from Finder — they are only not drawn.
  "com.apple.finder|CreateDesktop|-bool|false"

  # ── Window animations off. On a keyboard-driven setup every one of these is
  # latency between a keystroke and the window being where you asked for it.
  "NSGlobalDomain|NSAutomaticWindowAnimationsEnabled|-bool|false"
  "NSGlobalDomain|NSWindowResizeTime|-float|0.001"
  "NSGlobalDomain|NSScrollAnimationEnabled|-bool|false"
)

apply() {
  for row in "${SETTINGS[@]}"; do
    IFS='|' read -r domain key type value <<<"$row"
    defaults write "$domain" "$key" "$type" "$value"
  done
  ok "wrote ${#SETTINGS[@]} preference keys"
}

restore() {
  for row in "${SETTINGS[@]}"; do
    IFS='|' read -r domain key _ _ <<<"$row"
    defaults delete "$domain" "$key" 2>/dev/null || true
  done
  ok "deleted ${#SETTINGS[@]} preference keys — system defaults are back"
}

# Dock, Finder and WindowManager each cache their prefs at launch, so none of
# the above takes effect until the owning process is restarted. These restart
# themselves immediately; the desktop flickers once.
restart_agents() {
  say "Restarting Dock, Finder and WindowManager (the desktop will flicker)…"
  killall Dock          2>/dev/null || true
  killall Finder        2>/dev/null || true
  killall WindowManager 2>/dev/null || true
  ok "done"
}

case "$MODE" in
  apply)
    say "Applying desktop presentation defaults…"
    apply
    restart_agents
    ;;
  --restore|restore)
    say "Restoring macOS desktop defaults…"
    restore
    restart_agents
    ;;
  *)
    echo "usage: $0 [apply|--restore]" >&2
    exit 64
    ;;
esac
