-- ~/.hammerspoon/init.lua
-- Reload with Hyper+Shift+R after edits, or via the Hammerspoon menu.

hs.window.animationDuration = 0

-- Load the IPC module so the `hs` command-line tool can talk to this
-- instance. Without it, `hs -c 'hs.reload()'` fails with "can't access
-- Hammerspoon message port". The `hs` binary itself is installed via
-- hs.ipc.cliInstall(), which is safe to call repeatedly.
require("hs.ipc")
if not hs.ipc.cliStatus() then hs.ipc.cliInstall() end

-- ── Hyper key ──────────────────────────────────────────────────────
-- Karabiner remaps Right Cmd to ⌘⌥⌃ — Shift is deliberately left out,
-- so ⌘⌥⌃⇧ is a genuinely distinct second layer rather than the same
-- chord.
--
-- There is no tiling WM any more (AeroSpace was dropped: it crashed on
-- `focus` over floating windows and stranded every hidden window in a
-- screen corner). Windows live on native Spaces; macOS itself owns
-- Hyper+1..9 to switch them (scripts/desktop.sh writes those shortcuts),
-- and Hammerspoon owns everything else on both layers, including the
-- Hyper+arrow snapping below.
local hyper      = {"cmd", "alt", "ctrl"}
local hyperShift = {"cmd", "alt", "ctrl", "shift"}

local function bind(key, fn) hs.hotkey.bind(hyper, key, fn) end
local function bindShift(key, fn) hs.hotkey.bind(hyperShift, key, fn) end

-- ── Obsidian shortcuts ─────────────────────────────────────────────
local VAULT = "LifeVault"
local function openURI(uri) hs.execute("open '" .. uri .. "'") end
local function urlencode(s) return (s:gsub("([^%w%-_%.~])", function(c) return string.format("%%%02X", string.byte(c)) end)) end

-- Hyper+O → today's daily note
bind("o", function()
  local today = os.date("%Y-%m-%d")
  openURI(("obsidian://advanced-uri?vault=%s&filepath=%s&openmode=true"):format(VAULT, urlencode(today)))
end)

-- Hyper+C → current class-week Canvas (assumes filename "Week N.canvas")
bind("c", function()
  -- Roughly ND academic weeks; adjust the epoch to your semester start.
  local epoch = os.time({year=2026, month=8, day=25, hour=0, min=0, sec=0})  -- Fall 2026 start
  local week = math.floor((os.time() - epoch) / (7 * 86400)) + 1
  if week < 1 then week = 1 end
  local file = ("Week %d.canvas"):format(week)
  openURI(("obsidian://advanced-uri?vault=%s&filepath=%s&openmode=true"):format(VAULT, urlencode(file)))
end)

-- Hyper+P → Pocket inbox note (LifeVault convention)
bind("p", function()
  openURI(("obsidian://advanced-uri?vault=%s&filepath=%s&openmode=true"):format(VAULT, urlencode("Pocket Inbox")))
end)

-- Hyper+Return → new Ghostty WINDOW in the existing instance.
--
-- This used to live in aerospace.toml as:
--   alt-cmd-ctrl-enter = 'exec-and-forget open -na Ghostty'
-- `open -n` launches a whole new *instance* of the app every time, so each
-- press added another Ghostty process and another Dock icon. Selecting the
-- File → New Window menu item reuses the running instance instead, which is
-- what a tiling WM actually wants: many windows, one app.
--
-- Menu selection is used rather than a synthetic Cmd+Shift+N because it does
-- not depend on Ghostty's keybind config and does not need the caller to hold
-- permission to post keystrokes.
bind("return", function()
  local app = hs.application.get("Ghostty")
  if app and app:selectMenuItem({"File", "New Window"}) then
    app:activate()
  else
    hs.application.launchOrFocus("Ghostty")
  end
end)

-- Hyper+J → project launcher: every project as a card, Enter resumes it in
-- its own Ghostty window (or focuses the window it is already open in).
-- View lives in launcher.lua + launcher/launcher.html; all project logic is
-- ~/.local/bin/proj. Loaded under pcall so a launcher bug can't take the
-- rest of this file down with it.
local okLauncher, launcher = pcall(require, "launcher")
if okLauncher then
  bind("j", launcher.toggle)
else
  hs.printf("launcher.lua failed to load: %s", tostring(launcher))
end

-- Hyper+/ (think "?") → controls reference: every key in this setup,
-- Zellij, Neovim and lazygit on one filterable sheet (keys.lua +
-- keys/keys.html). `keys` in a shell opens the same sheet.
local okKeys, keys = pcall(require, "keys")
if okKeys then
  bind("/", keys.toggle)
else
  hs.printf("keys.lua failed to load: %s", tostring(keys))
end

-- Hyper+Shift+R → reload Hammerspoon.
bindShift("r", function() hs.reload() end)

-- ── Window snapping (Hyper + arrows) ───────────────────────────────
-- On demand, never automatic: nothing moves a window unless you press a
-- key. Gaps match the old tiling layout so the desktop looks the same.
-- The top inset clears SketchyBar whether or not the menu bar is shown.
local GAP, BAR_HEIGHT = 8, 32

local function usableFrame(screen)
  local full, vis = screen:fullFrame(), screen:frame()
  local top = math.max(vis.y, full.y + BAR_HEIGHT) + GAP
  return hs.geometry.rect(vis.x + GAP, top, vis.w - 2 * GAP, vis.y + vis.h - GAP - top)
end

-- unit = fractions of the usable frame. Inner edges give up half a gap
-- each so two snapped halves sit exactly GAP apart.
local function snap(unit)
  local win = hs.window.focusedWindow()
  if not win then return end
  local u = usableFrame(win:screen())
  local x, w = u.x + u.w * unit.x, u.w * unit.w
  if unit.x > 0 then x, w = x + GAP / 2, w - GAP / 2 end
  if unit.x + unit.w < 1 then w = w - GAP / 2 end
  win:setFrame(hs.geometry.rect(x, u.y + u.h * unit.y, w, u.h * unit.h))
end

bind("left",  function() snap({ x = 0,   y = 0,   w = 0.5, h = 1 })   end)
bind("right", function() snap({ x = 0.5, y = 0,   w = 0.5, h = 1 })   end)
bind("up",    function() snap({ x = 0,   y = 0,   w = 1,   h = 1 })   end)
bind("down",  function() snap({ x = 0.15, y = 0.1, w = 0.7, h = 0.8 }) end)

local function shell(cmd) hs.execute(cmd .. " > /dev/null 2>&1 &", true) end

-- ── Screenshots (Shottr) ───────────────────────────────────────────
-- Shottr's own hotkeys are GUI-configured, which does not survive a rebuild
-- of the machine. Its `shottr://` URL scheme does the same jobs and lives in
-- this file instead, so screenshots are as reproducible as everything else.
--
-- All four sit on the Shift layer. `Hyper+S` is free but plain-Hyper is the
-- non-destructive focus/navigation layer by convention — taking a screenshot
-- acts on the world, so it belongs on the acting layer.
local function shottr(action)
  openURI("shottr://" .. action)
end

bindShift("s", function() shottr("grab/area") end)        -- area select
bindShift("a", function() shottr("grab/fullscreen") end)  -- All: whole screen
bindShift("w", function() shottr("grab/window") end)      -- pick a window
bindShift("g", function() shottr("grab/scrolling") end)   -- scrolling capture

-- ── Übersicht desktop widgets ──────────────────────────────────────
-- Presentation modes clear the desktop by quitting Übersicht and bringing it
-- back, which is cruder than it should be.
--
-- Übersicht advertises a `hidden` property per widget in its AppleScript
-- dictionary, and that is the obvious mechanism — but on 1.6.82 / macOS 26
-- EVERY AppleEvent to the app times out with -1712 and has no effect (checked
-- against WidgetSettings.json, which stayed `"hidden": false`). `refresh` is
-- dead the same way. Do not reach for osascript here; it will appear to work
-- because the error is silent under `shell()`.
--
-- hs.application:hide() was the next candidate and is worse: it hides the
-- widgets, but Übersicht does not restore its desktop-level window frames on
-- unhide — they come back 0x0, i.e. invisible with no way back short of a
-- restart.
--
-- pkill/open costs a relaunch (~2s, and every widget re-runs its command),
-- but it is the only route that reliably ends in visible widgets. Both calls
-- go through the process, not AppleEvents, for exactly that reason.
--
-- Two things about the kill pattern, both learned the hard way:
--
--   * It must be ASCII. `pkill -x "Übersicht"` matches nothing — the umlaut
--     in the pattern does not line up with the process name — so the app
--     survives and the mode silently does nothing.
--   * It must cover Contents/ and not just Contents/MacOS. Übersicht spawns a
--     node server for its widget host; kill only the app and that server is
--     orphaned still holding port 41416, and the next launch comes up broken.
--
-- `[b]ersicht` is the same bracket trick used elsewhere in this repo: the
-- regex matches the running app, but not pkill's own command line.
local UBERSICHT = "/Applications/Übersicht.app"
local UBERSICHT_PROCS = "[b]ersicht.app/Contents/"

local function ubersichtWidgets(visible)
  if visible then
    shell(("open -a %q"):format(UBERSICHT))
  else
    shell(("pkill -f %q"):format(UBERSICHT_PROCS))
  end
end

-- ── Presentation modes ─────────────────────────────────────────────
-- Direct: Hyper+Shift+P/F/D/N.  Modal alternative: Hyper+V, then P/F/D/N.
local function setDND(on)
  -- Uses shortcuts.app; requires a Shortcut named "DND On" and "DND Off"
  -- that toggle the Focus you want. Create them once via Shortcuts.app.
  hs.execute("shortcuts run '" .. (on and "DND On" or "DND Off") .. "'")
end

local function modePresenting()
  shell("sketchybar --bar hidden=on")
  shell("borders active_color=0x00000000 inactive_color=0x00000000")
  ubersichtWidgets(false)
  setDND(true)
  hs.alert.show("Presenting", 1)
end

local function modeFocus()
  shell("sketchybar --bar hidden=off")
  shell("borders active_color=0xff9ece6a inactive_color=0xff565f89 width=6.0")
  ubersichtWidgets(true)
  setDND(true)
  for _, app in ipairs({"Slack", "Discord"}) do
    local a = hs.application.get(app)
    if a then a:kill() end
  end
  hs.alert.show("Focus", 1)
end

local function modeDemo()
  shell("sketchybar --bar hidden=off")
  shell("borders active_color=0xffbb9af7 inactive_color=0xff565f89 width=8.0")
  ubersichtWidgets(false)
  hs.alert.show("Demo", 1)
end

local function modeNormal()
  shell("sketchybar --bar hidden=off")
  shell("borders active_color=0xff7aa2f7 inactive_color=0xff565f89 width=6.0")
  ubersichtWidgets(true)
  setDND(false)
  hs.alert.show("Normal", 1)
end

local modeMenu = hs.hotkey.modal.new(hyper, "v")

local function bindMode(key, fn)
  modeMenu:bind({}, key, function()
    modeMenu:exit()
    fn()
  end)
end

function modeMenu:entered() hs.alert.show("Mode: P Present  F Focus  D Demo  N Normal", 2) end
modeMenu:bind({}, "escape", function() modeMenu:exit() end)
bindMode("p", modePresenting)
bindMode("f", modeFocus)
bindMode("d", modeDemo)
bindMode("n", modeNormal)

-- An armed Hyper+V menu keeps p/f/d/n/esc as global hotkeys until it exits,
-- so typing "flex" into the Hyper+J launcher would run Focus mode (and kill
-- Slack). Opening the launcher disarms the menu first.
if okLauncher then launcher.beforeShow = function() modeMenu:exit() end end
if okKeys then keys.beforeShow = function() modeMenu:exit() end end

-- Direct one-chord equivalents on the Shift layer. These are the bindings
-- the modes always wanted: Hyper+F (Focus) and Hyper+P (Present) used to
-- collide with AeroSpace fullscreen and the Pocket Inbox jump, which is why
-- the Hyper+V menu existed. On the Shift layer they no longer collide.
bindShift("p", modePresenting)
bindShift("f", modeFocus)
bindShift("d", modeDemo)
bindShift("n", modeNormal)

-- ── Auto light/dark — follow macOS's own setting ──────────────────
-- macOS Settings → Appearance → Auto already tracks sunrise/sunset.
-- We just mirror that into a `~/.config/theme.txt` sentinel other tools watch.
local themeFile = os.getenv("HOME") .. "/.config/theme.txt"

local function currentSystemTheme()
  local out, ok = hs.execute("defaults read -g AppleInterfaceStyle 2>/dev/null", true)
  if ok and out and out:match("Dark") then return "dark" else return "light" end
end

-- Only on an actual change: this runs every 5 minutes, and a full
-- `sketchybar --reload` each time made the bar blink for nothing.
local function applyTheme(t)
  local f = io.open(themeFile, "r")
  local old = f and f:read("*a") or nil
  if f then f:close() end
  if old == t then return end
  f = io.open(themeFile, "w"); if f then f:write(t); f:close() end
  shell("sketchybar --reload")
end

hs.timer.doEvery(300, function() applyTheme(currentSystemTheme()) end)
applyTheme(currentSystemTheme())

-- ── Zoom / call auto-focus ─────────────────────────────────────────
local callWatcher = hs.application.watcher.new(function(name, event, app)
  if event == hs.application.watcher.launched and
     (name == "zoom.us" or name == "Microsoft Teams" or name == "Google Chrome" and false) then
    modePresenting()
  end
end)
callWatcher:start()

-- ── Memory-pressure guard ──────────────────────────────────────────
-- Alerts if any single app crosses a hard RSS threshold, so runaway
-- leaks (looking at you, iTerm2) get caught before they eat all RAM.
local RSS_LIMIT_GB = 8   -- alert if any process > 8 GB
local memWatcher

local function checkMemoryHogs()
  local out = hs.execute("ps -Ao rss,comm -m | head -6")
  for line in out:gmatch("[^\n]+") do
    local rss_kb, name = line:match("^%s*(%d+)%s+(.+)$")
    if rss_kb then
      local gb = tonumber(rss_kb) / 1024 / 1024
      if gb > RSS_LIMIT_GB then
        local short = name:match("([^/]+)$") or name
        hs.notify.new({
          title  = "Memory hog: " .. short,
          informativeText = string.format("Using %.1f GB — consider quitting.", gb),
          soundName = "Basso",
          hasActionButton = true,
          actionButtonTitle = "Quit",
        }):send()
      end
    end
  end
end

memWatcher = hs.timer.doEvery(120, checkMemoryHogs)
checkMemoryHogs()

-- Vesper assistant bindings (Hyper+A to launch/focus, ⌘⌥J to ask inline).
-- Lives in vesper.lua so the HUD project owns its own keymap.
local okVesper, vesperErr = pcall(require, "vesper")
if not okVesper then
  hs.printf("vesper.lua failed to load: %s", tostring(vesperErr))
end

-- SketchyBar's desktop pills ask Hammerspoon what to draw. At login the bar
-- usually starts first, gets no answer and draws nothing, so repaint once
-- Hammerspoon is actually up.
shell("sketchybar --trigger space_change")

hs.alert.show("Hammerspoon loaded", 1)
