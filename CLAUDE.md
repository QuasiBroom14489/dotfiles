# CLAUDE.md — macOS rice (AeroSpace · Ghostty · Hammerspoon · SketchyBar)

Keyboard-first tiling setup. Everything here is symlinked into place by `./bootstrap.sh`.

**Edit files in `~/dotfiles`, never in `~/.config`** — the latter are symlinks to the former. `git status` from `~/dotfiles` is the source of truth for what changed.

Full prose reference lives in Obsidian at `LifeVault/05 Resources/macOS Rice Reference.md`. **Keep it in sync** when you change behavior — it documents keybindings, capabilities, and use cases, and it is the thing the user actually reads.

---

## The Hyper key — the load-bearing invariant

Karabiner maps held **Right Command → `⌘⌥⌃`**. Shift is deliberately **excluded** so that `Hyper + Shift` is a genuinely distinct second layer.

| Layer | Chord | Owns |
|---|---|---|
| Hyper | `⌘⌥⌃` | Focus, navigation, jumps — non-destructive |
| Hyper + Shift | `⌘⌥⌃⇧` | Moving windows, switching modes — acting |

> **Never restore the old four-modifier Hyper (`⌘⌥⌃⇧`).** It consumed the whole modifier space, making `Hyper+Shift+X` identical to `Hyper+X`. That collapsed both layers into one and caused real collisions: `Hyper+R` was bound to *both* AeroSpace `reload-config` and Hammerspoon `hs.reload()`, and the desktop modes had to hide behind a `Hyper+V` submenu because Focus mode wanted `Hyper+F` (taken by fullscreen) and Presenting wanted `Hyper+P` (taken by the Pocket Inbox jump).

### Before adding any binding, audit the keyspace

```sh
grep -E '^alt.*=' ~/dotfiles/aerospace/.config/aerospace/aerospace.toml
grep -E '^\s*bind(Shift)?\("' ~/dotfiles/hammerspoon/.hammerspoon/init.lua
```

AeroSpace writes modifiers in a fixed `alt-shift-cmd-ctrl` order, so `alt-cmd-ctrl-f` (Hyper) and `alt-shift-cmd-ctrl-f` (Hyper+Shift) are **different chords** that look nearly identical. Read carefully.

Currently 48 chords, zero collisions. Free on both layers: `B E I Q T U X Y Z`.

`A G S W` were spent on the Shottr screenshot bindings. Note that `D N` are free on
the Hyper layer only and `C M O V` on the Shift layer only — a chord being free on
one layer says nothing about the other.

### Who owns what

- **AeroSpace** — window/workspace *arrangement*, both layers.
- **Hammerspoon** — anything acting on an *application*: `Hyper+O/C/P` (Obsidian), `Hyper+Return` (new terminal), `Hyper+Shift+S/A/W/G` (Shottr), the desktop modes, its own reload.

Neither binds a chord the other uses. Keep it that way — nothing should depend on which process wins an event race.

---

## Hard rules

**Never use `open -na Ghostty` to open a terminal window.** `-n` launches a new app *instance* — its own process, its own Dock icon, its own `Cmd+Q` scope. Six accumulated in one session before this was caught. `Hyper+Return` goes through Hammerspoon selecting `File → New Window` on the running instance. The one legitimate `-n` is `sketchybar/plugins/diagnostics.sh`, where a disposable instance is intentional.

`ghostty +new-window` does **not** exist on macOS (Linux-only). `open -a Ghostty` without `-n` opens no window at all. The menu-item route is the only one that works.

**Never add a startup `command` to the Ghostty config.** It used to run `zellij attach --create main`, which attached *every* window to one session. Zellij mirrors a session across all attached clients, so each new terminal was a duplicate view of the last, and windows piled up until tiling collapsed. Ghostty opens a plain login shell; Zellij is opt-in via the `zj` function in `.zshrc`.

**AeroSpace and Zellij must not both do layout.** AeroSpace tiles windows; Zellij provides persistence only. Don't reintroduce overlap between them.

---

## The desktop layer

Ten Übersicht widgets draw on the wallpaper, in three columns:

| Column | Widgets |
|---|---|
| Left | `class-strip` (today's courses), `day-tape` (day progress), `focus` (open Current Sprint items) |
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
aerospace reload-config --dry-run   # validate WITHOUT applying
aerospace reload-config             # apply
sketchybar --reload
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

**Check exit codes directly, not through a pipe** — `cmd | head; echo $?` reports the *pipe's* status, not the command's. Redirect to a file instead. AeroSpace exits non-zero under `--warnings-as-errors` because of a pre-existing `config-version = 1` warning; without that flag it exits 0.

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

**Overlapping tiled windows** — the app is refusing to shrink, not AeroSpace misplacing it. Many macOS apps enforce a minimum width (Safari: 574 px). Three Safari windows need 1722 px on a 1512 px screen. Check real frames before blaming config:

```sh
hs -c 'for _,w in ipairs(hs.window.allWindows()) do local f=w:frame()
  print(w:application():name(), w:id(), f.x, f.w, f.x+f.w) end'
```

Fix with `Hyper + ,` (accordion), not by editing the config.

**A window won't tile** — it's probably floating. `aerospace list-windows --workspace focused --format '%{app-name} | %{window-layout}'`; `floating` is the answer, `Hyper + Space` toggles it. Zoom, Teams, FaceTime, and System Settings float *by design*.

**Windows parked far off-screen** (e.g. `x=1511` on a 1512 px display) are on a non-visible workspace. Normal AeroSpace behavior.

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
aerospace list-windows --all --format '%{window-id} | %{app-name} | layout=%{window-layout}'
ps -Ao pid,etime,comm | grep '[G]hostty.app'      # instance count + age
pgrep -x sketchybar borders                        # running?
brew services list                                 # ...but registered as services?
```

`sketchybar` and `borders` currently run as plain processes, **not** Homebrew services — they will not survive a reboot until someone runs `brew services start` for each.

State any command you run that changes visible state (opening windows, killing processes) — the user watches the screen and unexplained changes read as bugs.
