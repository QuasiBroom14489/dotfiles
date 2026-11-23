# CLAUDE.md — macOS rice (Spaces · Ghostty · Hammerspoon · SketchyBar)

Keyboard-first setup on native macOS desktops — **no tiling window manager** (see *Window management* below). Everything here is symlinked into place by `./bootstrap.sh`.

**Edit files in `~/dotfiles`, never in `~/.config`** — the latter are symlinks to the former. `git status` from `~/dotfiles` is the source of truth for what changed.

Full prose reference lives in Obsidian at `LifeVault/05 Resources/macOS Rice Reference.md`. **Keep it in sync** when you change behavior — it documents keybindings, capabilities, and use cases, and it is the thing the user actually reads.

---

## The Hyper key — the load-bearing invariant

Karabiner maps held **Right Command → `⌘⌥⌃`**. Shift is deliberately **excluded** so that `Hyper + Shift` is a genuinely distinct second layer.

| Layer | Chord | Owns |
|---|---|---|
| Hyper | `⌘⌥⌃` | Jumps, desktop switching, window snapping |
| Hyper + Shift | `⌘⌥⌃⇧` | Switching modes, screenshots, reload — acting |

> **Never restore the old four-modifier Hyper (`⌘⌥⌃⇧`).** It consumed the whole modifier space, making `Hyper+Shift+X` identical to `Hyper+X`. That collapsed both layers into one and caused real collisions: `Hyper+R` was bound to *both* the (since removed) AeroSpace `reload-config` and Hammerspoon `hs.reload()`, and the desktop modes had to hide behind a `Hyper+V` submenu because Focus mode wanted `Hyper+F` (taken by fullscreen) and Presenting wanted `Hyper+P` (taken by the Pocket Inbox jump).

### Before adding any binding, audit the keyspace

```sh
grep -nE 'bind(Shift)?\(|hotkey\.bind' ~/dotfiles/hammerspoon/.hammerspoon/init.lua ~/vesper/desktop/vesper.lua
```

Plus `Hyper+1..9`, which are macOS's own "Switch to Desktop N" symbolic hotkeys
(118–126), written by `scripts/desktop.sh` — they do not appear in any Lua file.

Free on both layers: `B E H I K L M Q T U X Y Z` (`J` is the project launcher). `R` is free on the Hyper
layer only (it was AeroSpace's reload). A chord being free on one layer says
nothing about the other.

### Who owns what

- **macOS** — `Hyper+1..9` desktop switching (symbolic hotkeys from `desktop.sh`).
- **Hammerspoon** — everything else: `Hyper+←/→/↑/↓` snapping, `Hyper+O/C/P` (Obsidian), `Hyper+Return` (new terminal), `Hyper+J` (project launcher, `launcher.lua`), `Hyper+/` (controls sheet, `keys.lua`), `Hyper+Shift+S/A/W/G` (Shottr), the desktop modes, its own reload; `vesper.lua` owns `Hyper+A/Space/Escape`, `⌘⌥J` and Tab+V.

Never bind a `Hyper+digit` in Hammerspoon — it would race the macOS shortcut.

## Window management

AeroSpace was removed on 2026-10-13. It crashed on `focus` over floating
windows (upstream issue #1311, open in 0.21.3), and because it hides inactive
workspaces by parking windows in a screen corner, every crash left slivers of
windows stranded on screen. **Do not reintroduce a tiling WM without the user
asking.** The rule now is: *nothing moves a window unless a key was pressed.*
No watchers that reposition windows or switch desktops on activation — the
Vesper "follow the workspace" watcher was removed for exactly that reason.

- **Desktops** are native Spaces. `mru-spaces=false` keeps their order fixed.
- **SketchyBar pills** are plain items painted by `plugins/spaces.sh`, which asks
  Hammerspoon (`hs.spaces`) for the count of *user* desktops. SketchyBar's own
  `space` items are deliberately not used: they number full-screen app Spaces
  too, so pill N would disagree with `Hyper+N`. Clicks go through
  `plugins/space_click.sh` → Hammerspoon posts `Hyper+N`.
- **Snapping** is ~25 lines in `init.lua` (*Window snapping*): 8 px gaps, top
  inset clears the 32 px bar. Hammerspoon ignores keystrokes it posts itself,
  so test the geometry by calling the logic, not by `keyStroke`.
- **JankyBorders and SketchyBar are `brew services`** (labels `sh.brew.*`).
  Borders reads `borders/.config/borders/bordersrc`.

---

## Hard rules

**Never use `open -na Ghostty` to open a terminal window.** `-n` launches a new app *instance* — its own process, its own Dock icon, its own `Cmd+Q` scope. Six accumulated in one session before this was caught. `Hyper+Return` goes through Hammerspoon selecting `File → New Window` on the running instance. The one legitimate `-n` is `sketchybar/plugins/diagnostics.sh`, where a disposable instance is intentional.

`ghostty +new-window` does **not** exist on macOS (Linux-only). `open -a Ghostty` without `-n` opens no window at all. The menu-item route is the only one that works.

**Never add a startup `command` to the Ghostty config.** It used to run `zellij attach --create main`, which attached *every* window to one session. Zellij mirrors a session across all attached clients, so each new terminal was a duplicate view of the last, and windows piled up until tiling collapsed. Ghostty opens a plain login shell; Zellij is opt-in via the `zj` function in `.zshrc`.

**Zellij provides persistence only, not layout.** Windows are arranged by snapping; don't make Zellij the layout tool.

**Zellij keys are the official "unlock-first" preset** (rendered into
`config.kdl` from zellij v0.45.1 `presets.rs`): it starts locked so every
Ctrl key reaches Neovim; Zellij commands are `Ctrl-g` + a letter; Alt
shortcuts work while locked. Don't go back to the default preset — it
swallowed Neovim's Ctrl-s/h/j/k/l/n/p/o. Alt only arrives because Ghostty has
`macos-option-as-alt = left`. **Keybind edits only reach NEW sessions** —
Zellij 0.45.1 did not live-reload them into running servers (edit made via
the dotfiles path behind the ~/.config symlink; touching the symlinked path
didn't trigger it either). Running sessions keep old keys until restarted
(`proj end X`, then resume — resurrection loads the current config). **Any key change updates
`hammerspoon/.hammerspoon/keys/keys.html`** — the Hyper+/ sheet is the
user's day-to-day reference (its `SHEET` array is the single source).

---

## Projects — `bin/proj`

`proj` maps each project folder to one Zellij session named by the folder's
lowercase slug, and attaches / resurrects / creates it. It is the single
source of truth for every front end: the terminal picker today, the Hyper+J
launcher and the wallpaper shelf next (plan: `~/.claude/plans/project-hub.md`).
Linked by bootstrap to `~/.local/bin/proj`; config `proj/.config/proj/projects.conf`;
state (notes, pinned slugs) in `~/.local/state/proj/`; layouts `proj-code.kdl`,
`proj-course.kdl`; completion `zsh/completions/_proj` (on fpath, because the
grok installer's trailing `compinit -C` drops any `compdef` made earlier).

Contract front ends rely on — keep it stable:

- `proj status --tsv|--json` — columns `slug path kind type state clients dirty
  branch last parent note`. Zero stderr in every normal state (Übersicht turns
  one stderr byte into a 500), runs under `env -i`, ~0.4 s for 40 repos, and
  every git call uses `--no-optional-locks` so polling never writes to repos.
- `proj attach NAME` exits **3** when the session already has a client: focus
  that window instead of attaching a mirror. A client can be an ssh login or a
  hung process, so a launcher that finds no window may retry with `--force`.
- **No fuzzy resolution** for attach / end / note. A wrong guess (`ds` →
  `alphalab-dsr`) would open or kill the wrong session. Fuzzy belongs to the picker.
- `~/DataClub` is a hard-coded `never` floor that holds even if the config is
  missing — no git command may ever run inside it.
- `LC_COLLATE=C` is pinned so slugs are identical under Hammerspoon's empty
  locale and Ghostty's UTF-8 one; slugs that have a session or note are pinned
  in `state/slugs` so a newly created folder can't steal them.
- `dataStructures` (EXITED) and `datastructures` (live) share one cache
  directory on case-insensitive APFS. Don't `delete-session` the former — it
  deletes the live session's save. proj folds case and the live one wins.

### Neovim — `nvim/.config/nvim` (LazyVim)

LazyVim + extras clangd/python/typescript/json/rust, tokyonight-night. The old
config is preserved as `NVIM_APPNAME=nvim-old` (`~/.config/nvim-old`,
`~/.local/share/nvim-old`) — reference only, it is broken upstream.

- `lua/config/proj.lua` restores the persistence.nvim session on VimEnter
  **only** inside Zellij with no file args (bare `nvim` or `nvim .`), saves on
  BufWritePost/FocusLost (a reboot skips VimLeavePre), and calls
  `persistence.stop()` in any other nvim inside Zellij so an ad-hoc
  `nvim file` can't overwrite the project session. Layouts start bare `nvim`.
  The restore is `vim.schedule`d out of VimEnter: inline, did_filetype() was
  already true so `:setf` no-op'd and restored files had no filetype/LSP.
  The `edit` pane *is* nvim (`command="nvim"`): `:qa` closes the tab. To
  reload config tell the user `:restart`, never quit-and-relaunch.
- Headless installs: `:MasonInstall` does NOT block headless, and LazyVim
  starts some of the same installs itself ("Package is already installing").
  Drive `mason-registry` and wait on `is_installing()`; parsers via
  `require("nvim-treesitter").install(list):wait(ms)`.
- `checkhealth` run headless reports snacks "setup did not run" and "no
  ghostty" — artifacts of no UI, not real. `tree-sitter` CLI must be on the
  real PATH (Brewfile), not only Mason's.
- `lua/plugins/completion.lua` tunes blink.cmp: Tab accepts when the menu is
  open (setting `<Tab>` disables LazyVim's own, so its snippet/AI chain is
  repeated there), `exact` sort first, a kind column, and Python opens the
  menu after `import `/`from `/`from x import `/commas (Pyright has no space
  trigger). That show is `vim.schedule`d — blink closes the previous word's
  menu *after* TextChangedI, so an immediate `show()` is undone. Test
  completion over RPC (`nvim --headless --listen S`, `--remote-send` one key
  at a time); feedkeys from a sourced script never enters insert mode, and a
  key burst in the same send as the first InsertEnter is lost while blink loads.

### Python tests — `lua/config/pytools.lua` + `bin/ut`

One module decides interpreter (project venv → VS Code default → uv), runner
(VS Code's python.testing.*Enabled → pytest config → unittest; a venv that
merely has pytest must NOT flip a unittest project), and environment. Neotest,
nvim-dap-python and `ut` (which runs it via `nvim --clean -l … --emit`) all
use it, so editor and terminal agree. Rules from review (2026-11-22):
- **.env is allowlisted** (PYTHONPATH, DJANGO_SETTINGS_MODULE, PYTEST_ADDOPTS).
  Loading it all leaked API keys into every LSP/child (alphalab's `claude -p`
  would bill the API key) and let a repo set NODE_OPTIONS/GIT_CONFIG_*/PATH.
- PYTHONPATH entries are made absolute, the unittest `-s` dir (or ./tests) is
  prepended so sibling helpers import, and it prepends to the existing value.
- Root markers are ONE nested list in `vim.fs.root` (equal priority) and
  `~` is never a root: as a flat list `~/.vscode` beat a project's `.git`, so
  git-only projects ran tests from home (fixed 2026-11-23).
- `ut` exits 5 on "Ran 0 tests" — unittest discovery silently skips folders
  without `__init__.py`, which read as a false green.
- debugpy: Mason's build fails on Homebrew python@3.14 (ensurepip), so
  dap-python uses `~/.local/share/nvim/debugpy` (uv venv, made by bootstrap).

### The Hyper+J launcher — `launcher.lua` + `launcher/launcher.html`

One `hs.webview`, built at load and only shown/hidden (show ≈ 8 ms). Lessons
that cost time, measured on this machine:

- **`wv:hswindow()` takes 2.2 s** and **`hs.window.filter:getWindows()` 4.6 s**
  (it waits for apps to "register"), both blocking the main thread — banned.
  `hs.focus()` alone makes the borderless webview key; `hs.application.get(
  "com.mitchellh.ghostty"):allWindows()` (3 ms) covers the current Space and
  Ghostty's AppleScript (`windows` / `name` / `activate window`) covers the rest.
- **Windows open via Ghostty AppleScript** (`new window with configuration`,
  `initial working directory`, `command`), through `hs.task` + osascript so a
  pending Automation prompt can't block Hammerspoon. No keystroke fallback: a
  typed fallback once waited unbounded and would have typed `proj attach`
  into whichever Ghostty window got focus next. On -1743/-1712 it explains.
- Before opening, `proj attach X --dry-run` is asked (not the cached status):
  exit 3 → bring the existing window forward; never `--force` on its own.
- `hs.task` objects are kept in a table until they exit — an unreferenced task
  can be garbage-collected and killed mid-run.
- `launcher.beforeShow` disarms the Hyper+V modal, whose p/f/d/n/esc hotkeys
  would otherwise eat the letters typed into the search box.
- Tab is not a launcher key: vesper.lua's Tab+V chord owns Tab.

---

## The desktop layer

Ten Übersicht widgets draw on the wallpaper, in three columns:

| Column | Widgets |
|---|---|
| Left | `class-strip` (today's courses), `day-tape` (day progress), `focus` (open Current Sprint items) |
| Left gutter | `projects` (the shelf: open + recent projects; click resumes) — `left: 348px; top: 426px`, hidden below 1700 px |
| Centre | `clock`, `weather`, `system`, `now-playing` |
| Right | `agenda` (today's calendar), `golden-dome` (decorative), `assignments` (what's due) |

`day-tape` is top-anchored at 300px, which clears `class-strip` on its longest
day (Tue/Thu, four classes). Adding a fifth class to a day means re-checking
that number. `golden-dome` is likewise top-anchored at 300px in the right
column, which is why `agenda` above it now carries a `MAX_ITEMS` cap — it was
the one widget that would grow without limit.

`golden-dome` is the only widget that drives its own frame loop: a 15fps
`setInterval` at module scope writing into its `<pre>`. Animation must not go
through `refreshFrequency`, which would spawn a shell fifteen times a second.
The timer is guarded on `window.__ndDomeTimer` so a re-bundle replaces it
instead of stacking a second one, and the element is looked up every tick
rather than captured, so the loop survives Übersicht replacing the node.

Positions are hard-coded and chosen so the top-anchored and bottom-anchored
cards can't meet: check the numbers before adding a ninth. Centred cards use
`left: 0; right: 0; margin: 0 auto` rather than `translateX(-50%)`, because the
shared card animates `transform` on mount and the two would fight.

`now-playing` renders nothing when no track is loaded. Übersicht always paints
the widget's root element, so its card chrome hangs off an inner `.card` and the
root gets `SHELL` from the palette module. Any other widget that needs to vanish
must do the same.

**Widgets are edited in `~/dotfiles/ubersicht/widgets`.** `~/Library/Application
Support/Übersicht/widgets` is a symlink to it — Übersicht lstats the widget
directory and follows the link, and its file watcher still fires on edits made
through the repo, so a save re-bundles the widget within a second.

**Shared code goes under `widgets/lib/`.** Übersicht treats *every* `.js`,
`.jsx` and `.coffee` file in the widget tree as a widget, and a module with no
`render` export shows up as a broken one. Its scanner skips any path containing
`/lib/`, `/src/` or `/node_modules/` — so `lib/` is the supported place for a
shared palette (`lib/tokyonight.js`), the course table (`lib/schedule.js`), and
helper scripts. Browserify still bundles those imports normally.

**Widget commands run through `bash` with cwd set to the widgets directory**, so
`./lib/current-sprint.sh` resolves. That shell does not inherit Homebrew's PATH
reliably, which is why `agenda.jsx` prefixes `PATH=/opt/homebrew/bin:...` before
calling `icalBuddy`.

**`projects.jsx` is the project shelf.** Data is `lib/projects.sh` →
`proj status --tsv` (60 s refresh, read-only git, stderr silenced). A click
runs `open -g 'hammerspoon://project?name=SLUG'`, handled in launcher.lua by
the same `openProject` as Enter in Hyper+J (focus the open window, else a new
Ghostty window). It is the only widget with click handlers; Übersicht 1.6's
"Enable interaction" pref must stay on. Preview the whole desktop without
hiding windows by loading http://127.0.0.1:41416/ in a browser at 1920×1080.

**`scripts/desktop.sh` owns every `defaults` key** for the dock, desktop icons
and window animations, in one table so apply and `--restore` cannot drift. Don't
scatter `defaults write` calls elsewhere; add a row to `SETTINGS` instead.

**`scripts/wallpaper.sh` needs Automation permission** for whatever runs it —
System Events is still the only scriptable route to the desktop picture on
macOS 26, and the first call is what raises the prompt. It renders its own
Tokyo Night gradients with ImageMagick at 640x360 and upscales; blurring small
and scaling up is ~40x faster than blurring at 4K and looks identical.

Presentation modes quit and relaunch Übersicht rather than hiding it. That is
the crude option and it is deliberate: the AppleScript `hidden` property does
not work (above), and `hs.application:hide()` is worse — it hides the widgets
but Übersicht brings its desktop windows back at 0x0 on unhide, so they are
gone until you restart it anyway. The relaunch costs ~2s and re-runs each
widget's command.

## Reload and verify

```sh
sketchybar --reload
sketchybar --trigger space_change   # repaint desktop pills only
source ~/.zshrc
touch ~/dotfiles/ubersicht/widgets/*.jsx   # re-bundle + re-run all widgets
```

**Übersicht answers no AppleEvents.** On 1.6.82 / macOS 26 every command in its
scripting dictionary — `refresh`, `reload`, `set hidden of every widget` — times
out after ~30s with `-1712` and changes nothing (verified against
`WidgetSettings.json`, which stays `"hidden": false`). The dictionary is a lie;
don't script it. `touch` on the `.jsx` is the working refresh, because the file
watcher does fire.

To restart it, kill the whole bundle and reopen:

```sh
pkill -f '[b]ersicht.app/Contents/' && sleep 1 && open -a Übersicht
```

The pattern is ASCII on purpose — `pkill -x "Übersicht"` matches nothing, the
umlaut does not line up — and it covers `Contents/`, not just `Contents/MacOS`,
because the app spawns a node server that otherwise orphans while still holding
port 41416, leaving the next launch broken.

**A widget that fails to compile draws the error on the desktop** — a white card
with the file, line, column and offending source. That is the fastest signal, but
it is only visible if you can see the desktop, so fetch the bundle when windows
are in the way. A 200 with browserify boilerplate means it compiled; a 500 is the
error text:

```sh
curl -s http://127.0.0.1:41416/widgets/class-strip-jsx | head -c 200
```

Widget ids are the path with `.` and `/` turned into `-`, so `class-strip.jsx`
is `class-strip-jsx`. To test what a widget's `command` actually returns, POST it
to the same runner the widget uses rather than running it in your own shell:

```sh
printf '%s' './lib/current-sprint.sh' | curl -s -X POST --data-binary @- \
  -H 'Origin: http://127.0.0.1:41416' http://127.0.0.1:41416/run/
```

**Check exit codes directly, not through a pipe** — `cmd | head; echo $?` reports the *pipe's* status, not the command's. Redirect to a file instead.

**`hs -c` can hang when stdin is not a terminal** (it waits on input). Always
give it `</dev/null`, and `-t <seconds>` for a timeout.

**Hammerspoon:** `hs -c 'hs.reload()'` **hangs** — it kills the Lua state mid-call so the IPC response never arrives. Fire and forget:

```sh
(hs -c 'hs.timer.doAfter(0.2, function() hs.reload() end)' >/dev/null 2>&1 &); sleep 4
hs -c 'print("alive")'
hs -c 'local hk=hs.hotkey.getHotkeys(); print(#hk); for _,k in ipairs(hk) do print(k.msg) end'
```

`hs` requires `hs.ipc`, loaded at the top of `init.lua`. If it errors with *"can't access Hammerspoon message port"*, a stale config is running — only the menu-bar icon can reload it. AppleScript is disabled, so `osascript` cannot drive Hammerspoon either.

Karabiner needs no reload; it watches `karabiner.json` and applies on save. Verify what the keyboard actually emits with **Karabiner-EventViewer**: holding Right Command must show `left_command`, `left_control`, `left_option` and **no** `left_shift`.

---

## Constraints that look like bugs but aren't

**A snapped window overlaps the centre line** — the app is refusing to shrink. Many macOS apps enforce a minimum width (Safari: 574 px). Check real frames before blaming config:

```sh
hs -c 'for _,w in ipairs(hs.window.allWindows()) do local f=w:frame()
  print(w:application():name(), w:id(), f.x, f.w, f.x+f.w) end' </dev/null
```

**Hyper+N does nothing** — desktop N does not exist (add it in Mission Control), or the symbolic hotkeys were reset: re-run `./scripts/desktop.sh`. Full-screen apps are *not* desktops and are not counted.

**A Ghostty window appeared on its own** — SketchyBar's CPU, memory, and network pills are buttons that each launch a diagnostic window.

**Aliases bite scripts** — `grep`→`rg` and `find`→`fd` take different flags. Use `\grep` / `\find` for the real binaries.

**A widget renders as an empty rectangle** — its `command` wrote to stderr.
Übersicht's runner sets the HTTP status to 500 on the *first* byte of stderr,
and the widget then gets an error instead of its output, even if stdout was
fine. Anything chatty needs `2>/dev/null` (as `agenda.jsx` does for icalBuddy)
or the noise silenced at the source.

**A widget's CSS silently ends mid-block** — there is a backtick in a comment.
The whole `className` export is one template literal, so a stray backtick inside
`/* ... */` terminates it and the rest of the CSS is parsed as JavaScript. This
fails loudly (the error card appears), but the message points at a line well
past the real cause.

**Only one thing on this desktop pulses**, and it is the most overdue
assignment. Everything else that moves does so by CSS *transition* driven by a
changing value — the `day-tape` playhead, the `system` sparkline, every meter
fill. A transition is motion that means something happened; an infinite
animation is just noise competing with the windows in front of it. The
playhead's transition duration deliberately equals its `refreshFrequency` so
each tick hands off to the next and the line glides rather than steps.

**ASCII-render geometry is limited by the character grid, not by the maths.**
Three things cost real time in `golden-dome.jsx` and are worth not repeating:

- `ASPECT` must be `charAdvance / lineHeight`, measured rather than assumed.
  JetBrains Mono Nerd Font advances **0.684em**, not the 0.6em of the plain
  font. Guessing squashed the object vertically and made every subsequent
  proportion judgement wrong. Verify by rendering a sphere and checking it is
  circular before tuning anything else.
- **Detail finer than a character cell becomes noise.** A colonnade of 16
  modelled columns across a drum ~32 cells wide put each column on well under a
  cell and rendered as static. Eight shaded bands read where geometry cannot.
  Same reason the cornice is a flat band: as a torus, its overhang threw stray
  marks several cells clear of the silhouette.
- **Perspective is stronger than it looks.** At `K2 = 5` the object's own depth
  swung `1/z` by ~20%, so the near face of the drum projected visibly wider than
  the far face and the base flared out past the cornice. `K2 = 11` with `K1`
  scaled to match is near-orthographic and fixes it.

**A column chart's last column collapses** — `flex: 1 1 0` and
`grid-auto-columns: 1fr` both did this in `weather.jsx`, with and without
`min-width: 0`. `display: table; table-layout: fixed` divides the width equally
and ignores content, and is what that widget uses now. Reach for it before
spending an hour on flex.

**A widget shows stale data after an edit** — the file watcher follows the
symlinked widget folder, but it does not watch `lib/`. Editing
`lib/tokyonight.js` alone will not re-bundle the widgets that import it. Touch
the `.jsx` files; the AppleScript `refresh` command does nothing (see above).

**`Hyper+Shift+S` does nothing** — Shottr launched but has no Screen Recording
grant. The URL is handled either way, so `open` still exits 0. Check System
Settings → Privacy & Security → Screen Recording.

**The dock came back** — `killall Dock` restores the *process*, not the
preference. `autohide-delay` survives; the dock is still unreachable. If it is
genuinely appearing, something rewrote the key: re-run `./scripts/desktop.sh`.

---

## When diagnosing, measure before concluding

This setup has produced several symptoms whose obvious explanation was wrong. Prefer evidence:

```sh
ps -Ao pid,etime,comm | grep '[G]hostty.app'      # instance count + age
pgrep -x sketchybar borders                        # running?
brew services list                                 # ...but registered as services?
```

`sketchybar` and `borders` are Homebrew services and start at login. If `brew services list` shows them missing, `brew services start sketchybar borders`.

State any command you run that changes visible state (opening windows, killing processes) — the user watches the screen and unexplained changes read as bugs.
