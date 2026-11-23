# dotfiles

Personal macOS rice — keyboard-first, Tokyo Night, native Spaces with on-demand snapping.

## Stack

- **Windows:** native macOS desktops + Hammerspoon snapping + JankyBorders (no tiling WM — AeroSpace was removed Oct 2026 after crash-stranded windows)
- **Terminal:** Ghostty (plain shell) + Zellij (opt-in persistence via `zj`)
- **Shell:** zsh + Starship + Atuin + zoxide
- **Scripting:** Hammerspoon + Karabiner-Elements
- **Bar:** SketchyBar
- **Desktop:** Übersicht widgets + generated Tokyo Night wallpapers
- **Screenshots:** Shottr (driven by `shottr://` URLs, not its own hotkeys)
- **Launcher:** Raycast
- **Agents:** Herdr (persistent Claude Code sessions)
- **System:** Vorssaint + Ice

Full plan: `~/.claude/plans/i-have-been-researching-snazzy-umbrella.md`

## First-time install

On a fresh Mac (Homebrew's installer also brings in git via the Xcode Command Line Tools):

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)" && brew install gh && gh auth login
gh repo clone QuasiBroom14489/dotfiles ~/dotfiles && ~/dotfiles/bootstrap.sh --minimal
```

`--minimal` sets up the dev core only: Ghostty, zsh + Starship/Atuin/zoxide/fzf, Neovim (LazyVim), lazygit, Zellij and `proj` (packages in `Brewfile.dev`). Drop the flag for the whole rice: SketchyBar, borders, Karabiner, Hammerspoon, Übersicht, wallpaper and Dock defaults (`Brewfile`, which includes `Brewfile.dev`).

`bootstrap.sh` symlinks configs into place, then runs `brew bundle`. Both modes are idempotent; re-run it to go from minimal to full. Anything requiring GUI permissions (Karabiner, Hammerspoon accessibility) is printed as a post-install checklist.

## Layout

```
borders/      → ~/.config/borders/
ghostty/      → ~/.config/ghostty/
zellij/       → ~/.config/zellij/
starship/     → ~/.config/starship.toml
sketchybar/   → ~/.config/sketchybar/
karabiner/    → ~/.config/karabiner/
hammerspoon/  → ~/.hammerspoon/
zsh/          → ~/.zshrc, ~/.zshenv
colors/       → shared palette (sourced by scripts)
ubersicht/    → ~/Library/Application Support/Übersicht/widgets
scripts/      → desktop.sh (macOS defaults), wallpaper.sh
```

## Desktop

Ten widgets on the wallpaper, all Tokyo Night, all edited in
`ubersicht/widgets`:

| Widget | Where | Shows |
|---|---|---|
| `class-strip` | top left | Today's Fall 2026 courses, with now / next highlighted |
| `day-tape` | middle left | Day progress as a 24x4 quarter-hour punch card, phase-coloured, with class-start ticks and a gliding playhead |
| `focus` | bottom left | Open `## Current Sprint` items from LifeVault's five goals |
| `clock` | top centre | Time, date, and how far through the semester you are |
| `weather` | centre | Conditions plus today's temperature curve (`wttr.in`, IP-located) |
| `system` | centre | CPU trend, memory, disk, uptime, biggest process |
| `now-playing` | bottom centre | Spotify track, progress, animated equaliser — hidden when nothing is loaded |
| `agenda` | top right | Today's calendar events (`icalBuddy`) |
| `assignments` | bottom right | What's due across every class, overdue first |
| `golden-dome` | middle right | The Golden Dome, rendered as rotating ASCII. Purely decorative |

`system` reuses the exact CPU and memory formulas from the SketchyBar plugins,
so the bar and the desktop never disagree. `assignments` reads the Canvas-synced
`Assignments.md` in each class folder.

Shared palette and the course table live in `ubersicht/widgets/lib/` — Übersicht
skips `/lib/` when scanning for widgets, so it is the right place for modules.

```sh
./scripts/desktop.sh              # dock unreachable, desktop icons off, no animations
./scripts/desktop.sh --restore    # put every key back

./scripts/wallpaper.sh generate   # render the Tokyo Night set with ImageMagick
./scripts/wallpaper.sh random     # pick one (drop your own images in the folder too)
```

Wallpapers land in `~/Pictures/Wallpapers/tokyonight` and are generated, not
committed — four gradients whose glows deliberately avoid the corners where the
widgets sit.

## Keybindings cheat sheet

### Hyper (Karabiner → Hammerspoon / macOS)

| Key | Action |
|---|---|
| Caps (tap) | Escape |
| Caps (hold) | Control |
| Right Cmd (hold) | Hyper (⌘⌥⌃) |
| Right Cmd + Shift | Second layer (⌘⌥⌃⇧) |
| Hyper + 1..9 | Switch to desktop N (macOS shortcut, set by `scripts/desktop.sh`) |
| Hyper + ← / → | Snap window to left / right half |
| Hyper + ↑ | Fill the screen (keeps gaps + bar) |
| Hyper + ↓ | Centre window at 70% × 80% |
| Hyper + Return | New Ghostty window |
| Hyper + O | Open Obsidian daily note |
| Hyper + C | Open current class-week Canvas |
| Hyper + P | Open Pocket-capture inbox |
| Hyper + Shift + S | Screenshot — area select |
| Hyper + Shift + A | Screenshot — whole screen |
| Hyper + Shift + W | Screenshot — pick a window |
| Hyper + Shift + G | Screenshot — scrolling capture |
| Hyper + Shift + P | Presenting mode |
| Hyper + Shift + F | Focus mode |
| Hyper + Shift + D | Demo mode |
| Hyper + Shift + N | Normal mode |
| Hyper + Shift + R | Reload Hammerspoon |

Hyper deliberately excludes Shift, so `Hyper + Shift` is a distinct second layer.
Presenting and Demo hide the Übersicht widgets; Focus and Normal bring them back.

### Ghostty (Cmd — stays macOS-native)

| Key | Action |
|---|---|
| Cmd + T | New tab |
| Cmd + Shift + ] / [ | Next / previous tab |
| Ctrl + Tab / Ctrl + Shift + Tab | Next / previous tab |
| Cmd + 1..8 | Go to tab N |
| Cmd + 9 | Last tab |
| Cmd + Shift + I | Rename tab (`prompt_tab_title`) |
| Cmd + Shift + N | New window |
| Cmd + D | Split right |
| Cmd + Shift + D | Split down |
| Cmd + W | Close split / tab |
| Cmd + Alt + W | Close whole tab |

Only the rows in `ghostty/.config/ghostty/config` are ours; the rest are Ghostty
defaults. `shell-integration-features` includes `title`, so tab titles track the
running command until you set one manually.

### Zellij (Ctrl — modal, all stock defaults)

`config.kdl` sets no keybinds, so these are Zellij 0.45 defaults. `Ctrl + <key>`
enters a mode; the same combo (or `Esc` / `Enter`) leaves it. `Ctrl + G` locks
all of it out, `Ctrl + Q` quits the session.

**Anywhere (no mode needed)**

| Key | Action |
|---|---|
| Alt + N | New pane |
| Alt + H/L or Alt + ←/→ | Focus pane left/right, rolling into the next tab at the edge |
| Alt + J/K or Alt + ↑/↓ | Focus pane down / up |
| Alt + I / Alt + O | Move current tab left / right |
| Alt + = / Alt + - | Grow / shrink pane |
| Alt + [ / Alt + ] | Previous / next swap layout |
| Alt + F | Toggle floating panes |
| Alt + P | Add pane to group |
| Alt + Shift + P | Toggle group marking |
| Ctrl + G | Lock / unlock (passes all keys through) |
| Ctrl + Q | Quit session |

**Tab mode — `Ctrl + T`**

| Key | Action |
|---|---|
| N | New tab |
| R | Rename tab (`Esc` undoes, `Enter` commits) |
| H/K/← /↑ | Previous tab |
| L/J/→/↓ | Next tab |
| 1..9 | Go to tab N |
| Tab | Toggle between last two tabs |
| X | Close tab |
| S | Toggle sync — input goes to every pane in the tab |
| B | Break focused pane into its own tab |
| [ / ] | Break pane into the tab left / right |

**Pane mode — `Ctrl + P`**

| Key | Action |
|---|---|
| N | New pane |
| D / R | New pane down / right |
| S | New stacked pane |
| H/J/K/L or arrows | Move focus |
| P | Cycle focus |
| ; | Focus last pane |
| C | Rename pane |
| X | Close pane |
| F | Fullscreen focused pane |
| Shift + F | Fullscreen, no UI |
| Z | Toggle pane frames |
| W | Toggle floating panes |
| E | Embed a floating pane / float an embedded one |
| I | Pin a floating pane (stays on top) |

**Resize mode — `Ctrl + N`**

| Key | Action |
|---|---|
| H/J/K/L or arrows | Grow in that direction |
| Shift + H/J/K/L | Shrink in that direction |
| = / + | Grow |
| - | Shrink |

**Move mode — `Ctrl + H`**

| Key | Action |
|---|---|
| N or Tab | Move pane to next position |
| P | Move pane backwards |
| H/J/K/L or arrows | Move pane in that direction |

**Scroll mode — `Ctrl + S`**

| Key | Action |
|---|---|
| J/K or ↑/↓ | Line up / down |
| Ctrl + F / Ctrl + B, PgUp/PgDn | Page up / down |
| D / U | Half page down / up |
| [ / ] | Jump to previous / next shell prompt |
| M | Select the command at the scroll position |
| C | Copy last command's output |
| E | Open scrollback in Neovim (`scrollback_editor`) |
| S | Start a search |
| Ctrl + C | Jump to bottom, back to normal |

**Search — `S` from scroll mode**, type the query, `Enter`:

| Key | Action |
|---|---|
| N / P | Next / previous match |
| C | Toggle case sensitivity |
| W | Toggle wrap |
| O | Toggle whole-word |

**Session mode — `Ctrl + O`**

| Key | Action |
|---|---|
| D | Detach (session survives; reattach with `zj`) |
| W | Session manager |
| C | Configuration UI |
| P | Plugin manager |
| L | Layout manager |
| S | Share session |
| A | About |
| F | Toggle host fullscreen |
| [ / ] | Focus guest / host session |

**Tmux compat mode — `Ctrl + B`** — for muscle memory: `"` split down, `%`
split right, `c` new tab, `,` rename tab, `n`/`p` next/prev tab, `z` fullscreen,
`o` next pane, `x` close pane, `d` detach, `[` scroll mode, `Space` next swap
layout.

Zellij lives on Ctrl and the desktop on Hyper (⌘⌥⌃), so plain `Alt + H/L` reaches
Zellij untouched. Ghostty's Cmd binds never reach the terminal, so `Cmd + T`
makes a Ghostty tab even inside a Zellij session.

Full reference: LifeVault → `05 Resources/macOS Rice Reference`.
