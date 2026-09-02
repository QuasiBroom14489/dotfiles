# Homebrew Bundle — install with `brew bundle --file=~/dotfiles/Brewfile`
# Grouped by rice-plan band. Comment out anything you're not ready for yet.

# ── Taps ─────────────────────────────────────────────────────────────
tap "nikitabobko/tap"          # AeroSpace
tap "FelixKratz/formulae"      # SketchyBar + JankyBorders
tap "koekeishiya/formulae"     # SKHD (optional)

# ── Band 1: Foundation ───────────────────────────────────────────────
cask "aerospace"
cask "karabiner-elements"
cask "ghostty"
cask "raycast"
cask "font-jetbrains-mono-nerd-font"
cask "font-iosevka-nerd-font"
brew "borders"                 # JankyBorders

# ── Band 2: Terminal ergonomics ──────────────────────────────────────
brew "zellij"
brew "starship"
brew "atuin"
brew "zoxide"
brew "fzf"
brew "eza"
brew "bat"
brew "ripgrep"
brew "fd"
brew "git-delta"
brew "jq"                      # SketchyBar plugins use it
brew "yq"

# ── Band 3: Scripting & agents ───────────────────────────────────────
cask "hammerspoon"
cask "vorssaint"
cask "jordanbaird-ice"         # "Ice" menu bar organizer (Homebrew name is jordanbaird-ice)
# Herdr — install via curl per herdr.dev; not in Homebrew

# ── Band 4: Obsidian layer ───────────────────────────────────────────
# Obsidian already installed; plugins configured in-app.
brew "ical-buddy"              # feeds Übersicht calendar widget

# ── Band 5: Desktop presentation ─────────────────────────────────────
brew "sketchybar"
cask "ubersicht"
brew "imagemagick"             # scripts/wallpaper.sh renders the Tokyo Night set
cask "shottr"                  # free screenshot tool; swap for cleanshot-x if you buy it
# cask "cleanshot"             # paid alternative
# sketchybar-app-font: install manually if you want app icons in SketchyBar:
#   curl -L https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/sketchybar-app-font.ttf \
#     -o ~/Library/Fonts/sketchybar-app-font.ttf

# ── Band 6+: Polish ──────────────────────────────────────────────────
cask "maccy"                   # or skip if using Raycast clipboard
brew "neovim"
brew "chezmoi"                 # dotfiles manager (upgrade path from stow)
brew "stow"                    # simple symlink manager (starting point)
brew "tmux"                    # keep around as fallback
brew "wget"
brew "gh"                      # GitHub CLI

# ── Diagnostics ──────────────────────────────────────────────────
brew "bottom"                  # Cross-platform system monitor (`btm`)
brew "bandwhich"               # Per-process bandwidth monitor
brew "mtr"                     # Combined ping and traceroute diagnostics
