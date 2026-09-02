# ~/.zshenv — sourced for every zsh invocation. Keep tiny.

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Starship config path (kept out of ~/.config to survive stow layout changes)
export STARSHIP_CONFIG="$XDG_CONFIG_HOME/starship.toml"

# Homebrew must be on PATH before .zshrc runs completions.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
