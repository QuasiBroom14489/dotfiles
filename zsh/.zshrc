# ~/.zshrc — sourced for interactive shells
# Kept lean; heavy lifting is delegated to Starship / Atuin / Zellij.

# ── Path ─────────────────────────────────────────────────────────────
typeset -U path PATH
path=(
  $HOME/.local/bin
  /opt/homebrew/bin
  /opt/homebrew/sbin
  $path
)

# ── History ──────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS INC_APPEND_HISTORY

# ── Completion ───────────────────────────────────────────────────────
fpath=($HOME/dotfiles/zsh/completions $fpath)
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# ── Editor ───────────────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"

# ── Aliases ──────────────────────────────────────────────────────────
alias ls="eza --icons --group-directories-first"
alias ll="eza -l --icons --git --group-directories-first"
alias la="eza -la --icons --git --group-directories-first"
alias lt="eza --tree --level=2 --icons --git-ignore"
alias cat="bat --plain"
alias cats="bat"                           # syntax-highlighted view
alias grep="rg"
alias find="fd"
alias vim="nvim"
alias v="nvim"
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gl="git log --oneline --graph --decorate -20"
alias reload="source ~/.zshrc"
alias perf="btm"
alias bandwidth="sudo bandwhich"
alias connections="nettop"
alias netcheck="sudo mtr -rwzc 50 1.1.1.1"
alias dnscheck="dig +short"

# ── Obsidian URI shortcuts ───────────────────────────────────────────
export LIFEVAULT="LifeVault"

note() {
  # `note`         → open today's daily note
  # `note foo bar` → open the note named "foo bar"
  local name="${*:-$(date +%Y-%m-%d)}"
  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$name")
  open "obsidian://advanced-uri?vault=$LIFEVAULT&filepath=$encoded&openmode=true"
}

canvas() {
  # `canvas foo` → open the Canvas file named foo.canvas
  local name="${*:-Home}"
  local encoded
  encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1] + '.canvas'))" "$name")
  open "obsidian://advanced-uri?vault=$LIFEVAULT&filepath=$encoded&openmode=true"
}

# ── Zellij (opt-in persistence) ──────────────────────────────────────
# Ghostty opens a plain shell, so window layout and Zellij no longer duplicate
# each other's job: Hyper+arrows place windows, Zellij persists sessions.
#
#   zj          → attach to (or create) the long-lived "main" session
#   zj notes    → attach to (or create) a session named "notes"
#   zjl         → list sessions
#
# Attaching two windows to the SAME session mirrors it — same panes, same
# cursor. That is Zellij behaving correctly; use a different session name
# when you want an independent terminal.
zj() {
  if [[ -n "$ZELLIJ" ]]; then
    print -u2 "Already inside Zellij session '${ZELLIJ_SESSION_NAME}'."
    print -u2 "Detach with Ctrl-g o d before attaching to another."
    return 1
  fi
  zellij attach --create "${1:-main}"
}
alias zjl="zellij list-sessions"

# proj — one Zellij session per project folder (~/dotfiles/bin/proj).
#   proj            fuzzy-pick a project and resume it
#   proj NAME       resume / start NAME        proj note TEXT   leave a note
# Hyper+J and the desktop shelf call the same script. Completion: zsh/completions/_proj.

# keys — the controls reference (same sheet as Hyper+/).
alias keys="open -g hammerspoon://keys"

# ── Tool integrations ────────────────────────────────────────────────
# Starship prompt
eval "$(starship init zsh)"

# zoxide (`z <partial>` jumps to frequent dirs)
eval "$(zoxide init zsh --cmd cd)"

# fzf keybindings + fuzzy completion
[[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]] && source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
[[ -f /opt/homebrew/opt/fzf/shell/completion.zsh   ]] && source /opt/homebrew/opt/fzf/shell/completion.zsh
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --color=fg:#c0caf5,bg:#1a1b26,hl:#7aa2f7,fg+:#c0caf5,bg+:#292e42,hl+:#7dcfff,info:#e0af68,prompt:#bb9af7,pointer:#f7768e,marker:#9ece6a,spinner:#7aa2f7,header:#565f89'

# Atuin — cross-machine fuzzy history (Ctrl-R)
eval "$(atuin init zsh --disable-up-arrow)"

# Vi keybindings + friendlier delete
bindkey -e   # emacs-style; swap to `-v` for full vi mode if you want

# ── Local overrides ──────────────────────────────────────────────────
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# uv's installer env (absent on a machine set up with brew's uv)
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# >>> grok installer >>>
if [[ -d ~/.grok ]]; then
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
fi
# <<< grok installer <<<
export DBT_PROFILES_DIR="$HOME/.dbt"

# Cortex CLI completion (disable via /settings in cortex)
[[ -s ~/.zsh/completions/cortex.zsh ]] && source ~/.zsh/completions/cortex.zsh
