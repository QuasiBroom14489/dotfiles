-- keys.lua — Hyper+/ controls reference overlay.
--
-- The cheat sheet itself (every binding, grouped) is keys/keys.html; this
-- file only shows and hides it. Same pattern as launcher.lua: one webview,
-- built at load, only shown/hidden — and no wv:hswindow() (2.2 s here).
--
-- Also reachable from a shell: `keys` runs `open -g hammerspoon://keys`
-- (a URL event, not `hs -c`, which can hang when stdin isn't a terminal).

local M = {}

local HTML    = hs.configdir .. "/keys/keys.html"
local SELF_ID = "org.hammerspoon.Hammerspoon"

local wv, uc
local loaded, visible = false, false
local prevApp

local function js(code) if wv and loaded then wv:evaluateJavaScript(code) end end

local function build()
  uc = hs.webview.usercontent.new("keys")
  uc:setCallback(function(msg)
    if type(msg.body) == "table" and msg.body.action == "close" then M.hide() end
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
    if action == "didFinishNavigation" then loaded = true
    elseif action == "didFailNavigation" or action == "didFailProvisionalNavigation" then
      loaded = false
      hs.printf("keys: page failed to load (%s): %s", HTML, hs.inspect(err))
    end
  end)
  wv:windowCallback(function(action, _, state)
    if action == "focusChange" and state == false and visible then M.hide(true) end
  end)
  wv:url("file://" .. HTML)
end

M.beforeShow = nil   -- init.lua: disarm the Hyper+V modal (it eats letters)

function M.show()
  if not wv then build() end
  if visible then return end
  if not loaded then hs.alert.show("The controls page didn't load — see the Hammerspoon console.", 3); return end
  if M.beforeShow then pcall(M.beforeShow) end
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() ~= SELF_ID then prevApp = front end
  wv:frame(hs.screen.mainScreen():fullFrame())
  visible = true
  wv:show()
  hs.focus()
  js("openKeys()")
end

function M.hide(keepFocus)
  if not visible then return end
  visible = false
  js("closeKeys()")
  wv:hide()
  if not keepFocus and prevApp and prevApp:isRunning() then
    -- Only hand focus back if that app is on this desktop; activating an
    -- app on another Space would switch desktops.
    local w = prevApp:focusedWindow()
    local ok, spaces = pcall(function() return w and hs.spaces.windowSpaces(w) end)
    if ok and spaces and hs.fnutils.contains(spaces, hs.spaces.focusedSpace()) then prevApp:activate() end
  end
end

function M.toggle() if visible then M.hide() else M.show() end end

M._state = function() return { built = wv ~= nil, loaded = loaded, visible = visible } end
M._wv = function() return wv end

hs.urlevent.bind("keys", function() M.show() end)   -- `keys` in a shell

build()
return M
