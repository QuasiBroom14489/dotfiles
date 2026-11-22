#!/usr/bin/env bash
# Click on desktop pill $1 → Hyper+$1, which is macOS's own "Switch to
# Desktop N" (scripts/desktop.sh). Hammerspoon posts the keystroke because
# it already holds Accessibility; the absolute path is because brew
# services launch SketchyBar with a bare PATH.
/opt/homebrew/bin/hs -t 2 -c "hs.eventtap.keyStroke({'cmd','alt','ctrl'}, '$1', 0)" </dev/null >/dev/null 2>&1
