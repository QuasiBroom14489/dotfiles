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
  # ── Dock: present but unreachable. Spaces + Raycast cover everything it
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

  # ── Keep Spaces in a fixed order. By default macOS reshuffles them by most
  # recent use, which makes the numbered SketchyBar pills and Hyper+1..9 point
  # at a different desktop every day.
  "com.apple.dock|mru-spaces|-bool|false"

  # ── Stop a click on the wallpaper from sweeping every window off-screen.
  # macOS 14 turned this on by default: with widgets on the desktop you now
  # have three cards you cannot click without losing your layout.
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

# ── Hyper+1..9 → "Switch to Desktop N" ────────────────────────────────
# These are macOS's own Mission Control shortcuts (symbolic hotkeys
# 118–126), just rebound from Ctrl+N to Hyper+N (⌘⌥⌃ = 1835008) so the
# old workspace muscle memory still works with no window manager running.
# They live in one nested dict, so they cannot be rows in SETTINGS —
# restore disables them rather than deleting the whole dict.
SPACE_KEYCODES=(18 19 20 21 23 22 26 28 25)   # virtual keycodes for 1..9
HYPER_MASK=1835008

space_hotkeys() {
  local enabled="$1" i
  for i in "${!SPACE_KEYCODES[@]}"; do
    defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add $((118 + i)) \
      "<dict><key>enabled</key><${enabled}/><key>value</key><dict><key>parameters</key><array><integer>65535</integer><integer>${SPACE_KEYCODES[$i]}</integer><integer>${HYPER_MASK}</integer></array><key>type</key><string>standard</string></dict></dict>"
  done
  # Makes the change live without logging out.
  /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u 2>/dev/null || true
  ok "Hyper+1..9 desktop switching $([[ $enabled == true ]] && echo on || echo off)"
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
    space_hotkeys true
    restart_agents
    ;;
  --restore|restore)
    say "Restoring macOS desktop defaults…"
    restore
    space_hotkeys false
    restart_agents
    ;;
  *)
    echo "usage: $0 [apply|--restore]" >&2
    exit 64
    ;;
esac
