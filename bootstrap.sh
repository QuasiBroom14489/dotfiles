#!/usr/bin/env bash
# Bootstrap ~/dotfiles: symlink configs into place, then brew bundle.
# Idempotent — re-run any time.

set -euo pipefail

DOTFILES="$HOME/dotfiles"
CONFIG="$HOME/.config"
mkdir -p "$CONFIG"

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'
say()  { printf "${BLUE}▸${RESET} %s\n" "$*"; }
ok()   { printf "${GREEN}✓${RESET} %s\n" "$*"; }
warn() { printf "${YELLOW}!${RESET} %s\n" "$*"; }

# ── Symlink helper: link src → dest, backing up any existing non-symlink ──
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" ]]; then
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.pre-dotfiles.$(date +%s)"
    warn "Backed up existing $dest → $dest.pre-dotfiles.*"
  fi
  ln -s "$src" "$dest"
  ok "linked $dest"
}

say "Linking configs…"
link "$DOTFILES/borders/.config/borders"       "$CONFIG/borders"
link "$DOTFILES/ghostty/.config/ghostty"       "$CONFIG/ghostty"
link "$DOTFILES/zellij/.config/zellij"         "$CONFIG/zellij"
link "$DOTFILES/starship/.config/starship.toml" "$CONFIG/starship.toml"
link "$DOTFILES/sketchybar/.config/sketchybar" "$CONFIG/sketchybar"
link "$DOTFILES/karabiner/.config/karabiner"   "$CONFIG/karabiner"
link "$DOTFILES/hammerspoon/.hammerspoon"      "$HOME/.hammerspoon"
link "$DOTFILES/zsh/.zshrc"                    "$HOME/.zshrc"
link "$DOTFILES/zsh/.zshenv"                   "$HOME/.zshenv"
link "$DOTFILES/proj/.config/proj"             "$CONFIG/proj"
link "$DOTFILES/bin/proj"                      "$HOME/.local/bin/proj"

# Übersicht keeps its widgets under Application Support rather than
# ~/.config. Its server resolves a symlinked widget directory (it lstats the
# path and follows it), so linking the whole folder works and file-watching
# still fires on edits made in ~/dotfiles.
link "$DOTFILES/ubersicht/widgets" "$HOME/Library/Application Support/Übersicht/widgets"

# ── Homebrew ──
if ! command -v brew >/dev/null; then
  say "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

say "Trusting third-party taps (required since Homebrew 4.x)…"
for tap in FelixKratz/formulae koekeishiya/formulae; do
  brew tap "$tap" 2>/dev/null || true
  brew trust --tap "$tap" 2>/dev/null || true
done

say "Running brew bundle…"
brew bundle --file="$DOTFILES/Brewfile" || warn "Some items failed — see output above. Re-run bootstrap after fixing."
ok "brew bundle finished"

# ── Services ──
say "Starting background services…"
brew services start sketchybar || warn "SketchyBar didn't start — check permissions."
brew services start borders    || warn "JankyBorders didn't start."

# ── Desktop presentation ──
say "Applying desktop defaults (dock, desktop icons, animations)…"
"$DOTFILES/scripts/desktop.sh" apply

if [[ ! -d "$HOME/Pictures/Wallpapers/tokyonight" ]]; then
  say "Rendering Tokyo Night wallpapers (~40s, one time)…"
  "$DOTFILES/scripts/wallpaper.sh" generate || warn "Wallpaper render failed — needs ImageMagick."
fi
# Setting the wallpaper needs Automation access for whatever shell runs this,
# and the first attempt is what raises the prompt. Non-fatal either way.
"$DOTFILES/scripts/wallpaper.sh" set "$HOME/Pictures/Wallpapers/tokyonight/tn-aurora.png" \
  || warn "Couldn't set the wallpaper — grant Automation access, then: ./scripts/wallpaper.sh random"

open -a "Übersicht" 2>/dev/null || warn "Übersicht not installed — re-run brew bundle."

# Übersicht has no "launch at login" toggle of its own, so a reboot silently
# takes every desktop widget with it. Register it as a login item instead.
if ! osascript -e 'tell application "System Events" to get the name of every login item' 2>/dev/null \
     | grep -q "Übersicht"; then
  osascript -e 'tell application "System Events" to make login item at end \
    with properties {path:"/Applications/Übersicht.app", hidden:false}' >/dev/null 2>&1 \
    || warn "Couldn't register Übersicht as a login item — add it manually in System Settings → General → Login Items."
fi

# ── Post-install checklist ──
cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅  Symlinks + Homebrew done.

Manual steps left (they require GUI or system permissions):

1. Spaces: open Mission Control and add desktops until you have as
   many as you want (the SketchyBar pills draw one per Space, up to 9).
   Hyper+1..9 switch to them; scripts/desktop.sh registered those.

2. Karabiner-Elements: open once, grant Input Monitoring +
   Accessibility. Then in Karabiner UI, verify the two complex
   modifications ("Caps → Ctrl/Esc" and "Right Cmd → Hyper") are
   enabled under Complex Modifications.

3. Hammerspoon: open once, grant Accessibility.
   Then in Hammerspoon Preferences, tick "Launch at login".
   Create two Shortcuts.app shortcuts named "DND On" and "DND Off"
   that toggle your preferred Focus mode (used by presentation modes).

4. Ghostty: theme file is at ~/.config/ghostty/themes/tokyonight
   — already referenced from config.

5. Herdr (agent-persistence runtime): not on Homebrew.
   Install with:  curl -fsSL https://herdr.dev/install.sh | sh

6. Obsidian: open LifeVault, then Settings → Community plugins:
   Vim Mode (built-in Editor setting), Advanced URI, Excalidraw,
   Templater, Dataview. Install "Tokyo Night" community theme +
   Style Settings.

7. Übersicht: open once, grant Screen Recording (it draws on the
   desktop) and Calendar access (the agenda widget shells out to
   icalBuddy). Widgets are edited in ~/dotfiles/ubersicht/widgets.

8. Shottr: open once, grant Screen Recording. Leave its own hotkeys
   unset — Hyper+Shift+S/A/W/G drive it through shottr:// URLs from
   Hammerspoon.

9. Maccy: open once and set its popup hotkey in-app. Maccy has no URL
   scheme and no documented defaults key for it, so it is the one
   binding in the rig that cannot be checked into the repo.

10. Silence startup chime:
      sudo nvram StartupMute=%01

The dock, desktop icons and window animations are set by
./scripts/desktop.sh — `./scripts/desktop.sh --restore` puts them back.

Restart your login session or log out/in when done, then reload:
      brew services restart sketchybar borders
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
