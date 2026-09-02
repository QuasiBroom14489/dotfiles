#!/usr/bin/env bash
# Open an interactive diagnostic in a fresh Ghostty window.
case "$1" in
  performance) COMMAND="exec /opt/homebrew/bin/btm" ;;
  network)     COMMAND="exec /usr/bin/nettop" ;;
  bandwidth)   COMMAND="sudo /opt/homebrew/bin/bandwhich; exec zsh" ;;
  route)       COMMAND="sudo /opt/homebrew/sbin/mtr 1.1.1.1; exec zsh" ;;
  *) exit 2 ;;
esac

open -na Ghostty --args -e /bin/zsh -lc "$COMMAND"
