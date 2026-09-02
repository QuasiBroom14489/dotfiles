#!/usr/bin/env bash
# Tokyo Night wallpapers — generate, list, and set.
#
#   ./scripts/wallpaper.sh generate   render the built-in set (idempotent)
#   ./scripts/wallpaper.sh list       show what's in the wallpaper directory
#   ./scripts/wallpaper.sh set FILE   set a specific image
#   ./scripts/wallpaper.sh random     pick one at random (for a launchd timer)
#
# Drop your own images into ~/Pictures/Wallpapers/tokyonight and `random`
# picks them up too — the generated ones are a floor, not a limit.
set -euo pipefail

DIR="${WALLPAPER_DIR:-$HOME/Pictures/Wallpapers/tokyonight}"
W=3840
H=2160

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
say()  { printf "${BLUE}▸${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }

# ── Generation ───────────────────────────────────────────────────────
#
# Each wallpaper is a four-corner bilinear gradient in Tokyo Night's base
# tones with two soft accent glows screened over it. The whole thing is
# composed at 640x360 and then upscaled: a Gaussian blur is O(area), so
# blurring small and scaling up is ~40x faster than blurring at 4K and
# visually identical for something this soft. The final +noise is there to
# break up 8-bit banding, which dark gradients show badly.
#
# Glows are kept away from the top-left, top-right and bottom-left corners
# on purpose — that is where the three Übersicht widgets sit, and their
# cards need a dark ground to stay readable.
render() {
  local out="$1" c_tl="$2" c_tr="$3" c_bl="$4" c_br="$5" \
        glow1="$6" g1x="$7" g1y="$8" g1r="$9" g1a="${10}" \
        glow2="${11}" g2x="${12}" g2y="${13}" g2r="${14}" g2a="${15}"

  magick -size 640x360 xc: \
    -sparse-color bilinear "0,0 $c_tl 639,0 $c_tr 0,359 $c_bl 639,359 $c_br" \
    \( -size 640x360 xc:black -fill "$glow1" \
       -draw "circle $g1x,$g1y $g1x,$((g1y + g1r))" -blur 0x45 -evaluate multiply "$g1a" \) \
    -compose screen -composite \
    \( -size 640x360 xc:black -fill "$glow2" \
       -draw "circle $g2x,$g2y $g2x,$((g2y + g2r))" -blur 0x45 -evaluate multiply "$g2a" \) \
    -compose screen -composite \
    -resize "${W}x${H}!" -attenuate 0.025 +noise Gaussian -depth 8 -alpha off \
    "$out"
}

generate() {
  command -v magick >/dev/null || { warn "ImageMagick not installed (brew install imagemagick)"; exit 1; }
  mkdir -p "$DIR"
  say "Rendering into $DIR (a few seconds each)…"

  #      out                          corners: TL       TR       BL       BR         glow 1                    glow 2
  render "$DIR/tn-aurora.png"         '#1a1b26' '#20222f' '#16161e' '#292e42'  '#7aa2f7' 430 300 170 0.32  '#bb9af7' 150 360 150 0.22
  render "$DIR/tn-midnight.png"       '#16161e' '#1a1b26' '#16161e' '#1f2335'  '#7dcfff' 330 340 190 0.22  '#3d59a1' 560 120 140 0.18
  render "$DIR/tn-ember.png"          '#1a1b26' '#1f1d2e' '#16161e' '#2a2438'  '#bb9af7' 470 320 170 0.30  '#ff9e64' 300 380 130 0.14
  render "$DIR/tn-storm.png"          '#1f2335' '#24283b' '#1a1b26' '#292e42'  '#565f89' 320 260 220 0.28  '#7aa2f7' 540 350 150 0.20

  ok "$(\ls -1 "$DIR" | wc -l | tr -d ' ') wallpapers in $DIR"
}

# ── Setting ──────────────────────────────────────────────────────────
#
# System Events is still the only scriptable route on macOS 26. It needs
# Automation permission for whatever runs it (Terminal/Ghostty the first
# time, Hammerspoon if a timer drives it) — the first call raises the
# prompt and fails until it is granted.
set_wallpaper() {
  local img="$1"
  [[ -f "$img" ]] || { warn "no such file: $img"; exit 1; }
  img="$(cd "$(dirname "$img")" && pwd)/$(basename "$img")"

  osascript -e "tell application \"System Events\" to tell every desktop to set picture to \"$img\"" \
    || { warn "System Events refused. Grant Automation access to this app in"
         warn "System Settings → Privacy & Security → Automation, then re-run."
         exit 1; }
  ok "wallpaper → $(basename "$img")"
}

case "${1:-}" in
  generate) generate ;;
  list)     \ls -1 "$DIR" 2>/dev/null || warn "nothing in $DIR — run: $0 generate" ;;
  set)      set_wallpaper "${2:?usage: $0 set FILE}" ;;
  random)
    [[ -d "$DIR" ]] || { warn "$DIR does not exist — run: $0 generate"; exit 1; }
    pick="$(\find "$DIR" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.heic' \) | sort -R | head -1)"
    [[ -n "$pick" ]] || { warn "no images in $DIR"; exit 1; }
    set_wallpaper "$pick"
    ;;
  *) echo "usage: $0 {generate|list|set FILE|random}" >&2; exit 64 ;;
esac
