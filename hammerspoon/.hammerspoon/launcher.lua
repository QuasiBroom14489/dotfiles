-- launcher.lua — Hyper+J project launcher.
--
-- A full-screen Tokyo Night card grid of every project `proj` knows about.
-- Type to filter; Enter resumes the project in its own Ghostty window, or
-- brings forward the window it is already open in. All project logic lives
-- in ~/.local/bin/proj — this file is only a view and a window opener.
-- init.lua binds the key (the keyspace audit greps there).
--
-- Rules this file keeps (see ~/.claude/plans/project-hub.md, CLAUDE.md):
--   * One hs.webview, created at load and only shown/hidden. A WKWebView per
--     keypress would pay a web-content process start every time.
--   * Everything slow runs through hs.task, never hs.execute (which blocks
--     the Lua state; vesper.lua's event taps have died of that before).
--     Two calls are banned for the same reason: wv:hswindow() (2.2 s here)
--     and hs.window.filter:getWindows() (4.6 s here).
--   * Ghostty windows open via its AppleScript `new window with
--     configuration`, sent to the RUNNING instance — never `open -na`. The
--     first use raises a one-time Automation prompt (Hammerspoon → Ghostty).
--   * Never type into a window we did not create. If AppleScript is refused,
--     say so; don't fall back to keystrokes.
--   * Never attach a second client on our own: `--force` is the user's call.
--   * Nothing moves a window. Bringing an existing one forward is the only
--     window action, and only on Enter.

local M = {}

local HOME     = os.getenv("HOME")
local PROJ     = HOME .. "/.local/bin/proj"
local HTML     = hs.configdir .. "/launcher/launcher.html"
local GHOSTTY  = "com.mitchellh.ghostty"
local SELF_ID  = "org.hammerspoon.Hammerspoon"

local wv, uc
local loaded, visible = false, false
local pendingJS = {}
local cache                   -- last `proj status --json` output (JSON string)
local statusTask, wantRefresh -- in-flight refresh; another one requested?
local afterRefresh = {}       -- callbacks waiting for the next refresh
local prevApp                 -- app to hand focus back to when dismissed
local live = {}               -- running hs.task objects, kept from the GC

-- ── Helpers ────────────────────────────────────────────────────────
local function sq(s) return "'" .. tostring(s):gsub("'", "'\\''") .. "'" end   -- shell single-quote

-- hs.task that cannot be garbage-collected mid-run.
local function spawn(path, args, callback)
  local t
  t = hs.task.new(path, function(code, out, err)
    live[t] = nil
    if callback then callback(code, out or "", err or "") end
  end, args)
  live[t] = true
  if not t:start() then
    live[t] = nil
    if callback then callback(-1, "", "could not start " .. path) end
  end
  return t
end

local function say(msg, secs) hs.alert.show(msg, secs or 3) end

local function js(code)
  if wv and loaded then wv:evaluateJavaScript(code) else table.insert(pendingJS, code) end
end

-- ── Data ───────────────────────────────────────────────────────────
local function refresh()
  if statusTask then wantRefresh = true; return end
  statusTask = spawn(PROJ, { "status", "--json" }, function(code, out)
    statusTask = nil
    if code == 0 and out:match("^%[") then
      cache = out:gsub("%s+$", "")
      js("render(" .. cache .. ")")
    else
      js("render([], " .. hs.json.encode({ "proj status failed (exit " .. tostring(code) .. ")" }):sub(2, -2) .. ")")
    end
    local waiting = afterRefresh; afterRefresh = {}
    for _, f in ipairs(waiting) do pcall(f) end
    if wantRefresh then wantRefresh = false; refresh() end
  end)
end

local function project(slug)
  if not cache then return end
  local ok, list = pcall(hs.json.decode, cache)
  if not ok or type(list) ~= "table" then return end
  for _, p in ipairs(list) do if p.slug == slug then return p end end
end

local function proj(args)   -- fire a proj subcommand, report errors, refresh
  spawn(PROJ, args, function(code, _, err)
    if code ~= 0 and #err > 0 then say((err:gsub("^proj: ", ""):gsub("%s+$", ""))) end
    refresh()
  end)
end

-- ── Focus ──────────────────────────────────────────────────────────
-- Give focus back to whatever had it, but only if that is on the current
-- desktop: re-activating an app on another Space would switch desktops.
local function restoreFocus()
  if prevApp and prevApp:isRunning() then
    local w = prevApp:focusedWindow()
    local ok, spaces = pcall(function() return w and hs.spaces.windowSpaces(w) end)
    if ok and spaces and hs.fnutils.contains(spaces, hs.spaces.focusedSpace()) then
      prevApp:activate(); return
    end
  end
  local top = hs.window.orderedWindows()[1]
  if top then top:focus() end
end

-- ── Ghostty ────────────────────────────────────────────────────────
local function osascript(src, argv, callback)
  local args = { "-e", src }
  for _, a in ipairs(argv) do table.insert(args, a) end
  spawn("/usr/bin/osascript", args, callback)
end

local function explainAppleScriptFailure(err)
  hs.printf("launcher: Ghostty AppleScript failed: %s", err)
  if err:match("%-1743") then
    say("Hammerspoon isn't allowed to control Ghostty.\nSystem Settings › Privacy & Security › Automation", 6)
  elseif err:match("%-1712") then
    say("Ghostty didn't answer in time.\nIf a permission prompt is open, click Allow and try again.", 6)
  else
    say("Couldn't open a Ghostty window — see the Hammerspoon console.", 4)
  end
  restoreFocus()
end

-- New Ghostty window in `dir`. With `inner`, the window runs it through a
-- login zsh and then stays as an interactive shell, so detaching from
-- Zellij leaves you in the project instead of closing the window.
local function newWindow(dir, inner)
  local command = inner and ("/bin/zsh -lc " .. sq(inner .. "; exec /bin/zsh -il")) or ""
  osascript([[
on run argv
  with timeout of 300 seconds
    tell application id "com.mitchellh.ghostty"
      set cfg to new surface configuration
      set initial working directory of cfg to item 1 of argv
      if item 2 of argv is not "" then set command of cfg to item 2 of argv
      new window with configuration cfg
      activate
    end tell
  end timeout
end run]], { dir, command }, function(code, _, err)
    if code ~= 0 then explainAppleScriptFailure(err) end
  end)
end

-- Bring forward the Ghostty window Zellij titled "<slug> | <pane>".
-- Ghostty's own window list (this Space) is instant; its AppleScript sees
-- every Space. Calls back with true if a window was found.
local function focusSessionWindow(slug, callback)
  local prefix = slug .. " | "
  local app = hs.application.get(GHOSTTY)
  for _, w in ipairs(app and app:allWindows() or {}) do
    local t = w:title() or ""
    if t == slug or t:sub(1, #prefix) == prefix then w:focus(); return callback(true) end
  end
  osascript([[
on run argv
  set want to item 1 of argv
  tell application id "com.mitchellh.ghostty"
    repeat with w in windows
      set n to name of w
      if n is want or n starts with (want & " | ") then
        activate window w
        activate
        return "found"
      end if
    end repeat
  end tell
  return "none"
end run]], { slug }, function(code, out, err)
    if code ~= 0 then explainAppleScriptFailure(err); return end
    callback(out:match("found") ~= nil)
  end)
end

-- ── Actions from the page ──────────────────────────────────────────
local function safeSlug(s) return type(s) == "string" and s:match("^[a-z0-9][a-z0-9-]*$") end

local actions = {}

-- Ask proj (not the cache, which can be seconds old) whether the session is
-- already attached: exit 3 → bring that window forward; 0 → new window.
local function openProject(p)
  spawn(PROJ, { "attach", p.slug, "--dry-run" }, function(code, _, err)
    if code == 3 then
      focusSessionWindow(p.slug, function(found)
        if not found then
          say(p.slug .. " is attached somewhere I can't see (ssh?).\nTake it over with:  proj attach " .. p.slug .. " --force", 6)
          restoreFocus()
        end
      end)
    elseif code == 0 then
      newWindow(p.path, sq(PROJ) .. " attach " .. p.slug)
    else
      say((err:gsub("^proj: ", ""):gsub("%s+$", "")))
      restoreFocus()
    end
    refresh()
  end)
end

function actions.open(m)
  local p = safeSlug(m.slug) and project(m.slug)
  if not p then return end
  M.hide(true)
  openProject(p)
end

-- hammerspoon://project?name=SLUG — the wallpaper shelf (Übersicht
-- projects.jsx) resumes a project through exactly the same path as Enter.
hs.urlevent.bind("project", function(_, params)
  local slug = params and params.name
  if not safeSlug(slug) then return end
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() ~= SELF_ID then prevApp = front end
  local p = project(slug)
  if p then openProject(p); return end
  table.insert(afterRefresh, function()          -- not in the cache yet
    local q = project(slug)
    if q then openProject(q) else say("No project called " .. slug) end
  end)
  refresh()
end)

function actions.shell(m)
  local p = safeSlug(m.slug) and project(m.slug)
  if p then M.hide(true); newWindow(p.path, nil) end
end

function actions.note(m)
  if safeSlug(m.slug) and type(m.text) == "string" then
    local text = m.text:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
    proj({ "note", "-p", m.slug, text })     -- "" clears the note
  end
end

function actions.finish(m)  -- "end" is a Lua keyword
  if safeSlug(m.slug) then proj({ "end", m.slug }) end
end

function actions.new(m)
  local name = type(m.name) == "string" and m.name:match("^[%w][%w._-]*$")
  if not name then say("Project names: letters, digits, . _ -", 2); return end
  M.hide(true)
  newWindow(HOME, ("%s new %s%s; cd %s 2>/dev/null"):format(
    sq(PROJ), sq(name), m.course and " --course" or "", sq(HOME .. "/" .. name)))
end

function actions.close() M.hide() end
function actions.refresh() refresh() end

-- ── Webview ────────────────────────────────────────────────────────
local function build()
  uc = hs.webview.usercontent.new("launcher")
  uc:setCallback(function(msg)
    local body = msg and msg.body
    if type(body) ~= "table" or not actions[body.action] then return end
    -- A double-click or a queued second Enter arrives after we have hidden:
    -- only "note"/"finish"/"refresh" may act while the launcher is closed.
    if not visible and (body.action == "open" or body.action == "shell" or body.action == "new") then return end
    actions[body.action](body)
  end)

  wv = hs.webview.new(hs.screen.mainScreen():fullFrame(), { developerExtrasEnabled = false }, uc)
  wv:windowStyle({ "borderless" })
    :level(hs.drawing.windowLevels.modalPanel)
    :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.fullScreenAuxiliary)
    :transparent(true)
    :shadow(false)
    :allowTextEntry(true)
    :closeOnEscape(false)
    :deleteOnClose(false)

  wv:navigationCallback(function(action, _, _, err)
    if action == "didFinishNavigation" then
      loaded = true
      for _, code in ipairs(pendingJS) do wv:evaluateJavaScript(code) end
      pendingJS = {}
    elseif action == "didFailNavigation" or action == "didFailProvisionalNavigation" then
      loaded = false
      hs.printf("launcher: page failed to load (%s): %s", HTML, hs.inspect(err))
    end
  end)

  -- Clicking another window dismisses the launcher.
  wv:windowCallback(function(action, _, state)
    if action == "focusChange" and state == false and visible then M.hide(true) end
  end)

  wv:url("file://" .. HTML)
end

-- init.lua sets this to close the Hyper+V mode menu, whose modal hotkeys
-- (p/f/d/n/esc) would otherwise eat the letters typed into the search box.
M.beforeShow = nil

function M.show()
  if not wv then build() end
  if visible then return end
  if not loaded then
    say("The launcher page didn't load — see the Hammerspoon console.", 3)
    return
  end
  if M.beforeShow then pcall(M.beforeShow) end
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() ~= SELF_ID then prevApp = front end
  wv:frame(hs.screen.mainScreen():fullFrame())
  visible = true
  wv:show()
  -- Activating Hammerspoon is enough to make the borderless webview key.
  hs.focus()
  js("openLauncher()")
  if cache then js("render(" .. cache .. ")") end
  refresh()
end

-- keepFocus: true when the caller is about to focus something itself.
function M.hide(keepFocus)
  if not visible then return end
  visible = false
  js("closeLauncher()")
  wv:hide()
  if not keepFocus then restoreFocus() end
end

function M.toggle() if visible then M.hide() else M.show() end end

-- For testing from `hs -c`.
M._wv = function() return wv end
M._project = project
M._state = function()
  return { built = wv ~= nil, loaded = loaded, visible = visible, cached = cache ~= nil,
           tasks = (function() local n = 0; for _ in pairs(live) do n = n + 1 end; return n end)() }
end

-- Warm up: build the page and fetch data once, so the first Hyper+J is instant.
build()
refresh()

return M
