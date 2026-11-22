#!/bin/bash
# SketchyBar plugin — Vesper daemon state.
#
# Plain bash with no dependencies, matching the convention of the other plugins
# in ~/.config/sketchybar/plugins/. Sourced colors come from the same
# colors.sh the rest of the bar uses, so this stays in step with the theme.

source "$HOME/.config/sketchybar/colors.sh" 2>/dev/null || true

: "${MAGENTA:=0xffbb9af7}"
: "${CYAN:=0xff7dcfff}"
: "${GREEN:=0xff9ece6a}"
: "${GREY:=0xff565f89}"
: "${RED:=0xfff7768e}"

HOST="${VESPER_HOST:-127.0.0.1}"
PORT="${VESPER_PORT:-4873}"

# --max-time keeps a hung daemon from stalling the whole bar refresh.
health=$(curl -s --max-time 1 "http://${HOST}:${PORT}/health" 2>/dev/null)

if [ -z "$health" ]; then
  ICON="󰧵"; COLOR=$GREY; LABEL=""
else
  state=$(printf '%s' "$health" | sed -n 's/.*"state":"\([a-z]*\)".*/\1/p')
  case "$state" in
    thinking)  ICON="󰧵"; COLOR=$MAGENTA; LABEL="thinking" ;;
    listening) ICON="󰍬"; COLOR=$CYAN;    LABEL="listening" ;;
    speaking)  ICON="󰕾"; COLOR=$GREEN;   LABEL="" ;;
    idle)      ICON="󰧵"; COLOR=$CYAN;    LABEL="" ;;
    *)         ICON="󰧵"; COLOR=$RED;     LABEL="?" ;;
  esac
fi

sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$LABEL"
