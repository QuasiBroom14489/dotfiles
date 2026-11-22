-- Python test environment — one definition shared by Neovim (neotest, the
-- debugger) and the `ut` command (~/dotfiles/bin/ut runs this file with
-- `nvim --clean -l … --emit ROOT`). Goal: tests behave the way VS Code runs
-- them, without importing a project's whole .env.
--
--   interpreter  project .venv / venv → workspace python.defaultInterpreterPath
--                → VS Code's user default → `uv python find` → python3
--   runner       VS Code's python.testing.{unittest,pytest}Enabled → pytest
--                config files → unittest
--   environment  ONLY these .env keys: PYTHONPATH, DJANGO_SETTINGS_MODULE,
--                PYTEST_ADDOPTS. A .env holds API keys and could set PATH,
--                NODE_OPTIONS or GIT_CONFIG_* — loading all of it would hand
--                secrets to every LSP and let a cloned repo run code.
--                PYTHONPATH entries are made absolute, the unittest start
--                dir (VS Code's `-s DIR`, else ./tests) is added so tests can
--                import helpers beside them, and the result is PREPENDED to
--                any PYTHONPATH already set — as VS Code does.
local M = {}

M.ALLOW = { PYTHONPATH = true, DJANGO_SETTINGS_MODULE = true, PYTEST_ADDOPTS = true }

local function readable(p) return vim.fn.filereadable(p) == 1 end
local function isdir(p) return vim.fn.isdirectory(p) == 1 end
local function exe(p) return p and vim.fn.executable(p) == 1 end

-- .env parser (python-dotenv-ish): KEY=VALUE, spaces around "=", `export`,
-- quotes (with a trailing comment after them), " #" comments, BOM, CRLF.
function M.parse_env(text)
  local vars = {}
  text = text:gsub("^\239\187\191", "")
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    line = line:gsub("\r$", ""):gsub("^%s*export%s+", "")
    if not line:match("^%s*#") then
      local key, value = line:match("^%s*([%a_][%w_]*)%s*=%s*(.-)%s*$")
      if key then
        local q, inner = value:match("^([\"'])(.-)%1%s*#?.*$")
        if q then
          value = q == '"' and inner:gsub("\\n", "\n") or inner
        elseif value:match("^#") then
          value = ""
        else
          value = value:gsub("%s+#.*$", "")
        end
        vars[key] = value
      end
    end
  end
  return vars
end

-- VS Code settings.json is JSONC: strip comments and trailing commas.
local function read_jsonc(path)
  if not readable(path) then return nil end
  local text = table.concat(vim.fn.readfile(path), "\n")
  text = text:gsub('("[^"\n]*")', function(s) return s:gsub("//", "\1\1") end) -- protect // inside strings
  text = text:gsub("//[^\n]*", ""):gsub("/%*.-%*/", ""):gsub(",(%s*[}%]])", "%1"):gsub("\1\1", "//")
  local ok, data = pcall(vim.json.decode, text)
  return ok and type(data) == "table" and data or nil
end

function M.vscode(root) return read_jsonc(root .. "/.vscode/settings.json") or {} end

local function expand_vscode(value, root)
  if type(value) ~= "string" then return nil end
  return (value:gsub("%${workspaceFolder}", root):gsub("^~", vim.env.HOME or "~"))
end

-- Project root: nearest folder (from `dir` up) that looks like a Python project.
M.MARKERS = { ".venv", "venv", ".env", ".vscode", "pyproject.toml", "setup.py", "setup.cfg", ".git" }
function M.root(dir)
  dir = vim.fs.normalize(dir or vim.fn.getcwd())
  return vim.fs.root(dir, M.MARKERS) or dir
end

local uv_python
local function default_python()
  local user = read_jsonc((vim.env.HOME or "") .. "/Library/Application Support/Code/User/settings.json") or {}
  local p = expand_vscode(user["python.defaultInterpreterPath"], vim.fn.getcwd())
  if exe(p) then return p end
  if uv_python == nil then
    uv_python = false
    if vim.fn.executable("uv") == 1 then
      local out = vim.fn.system({ "uv", "python", "find" })
      if vim.v.shell_error == 0 then uv_python = vim.trim(out) end
    end
  end
  if uv_python and exe(uv_python) then return uv_python end
  return "python3"
end

function M.python(root)
  for _, v in ipairs({ ".venv", "venv", "env" }) do
    local p = root .. "/" .. v .. "/bin/python"
    if readable(root .. "/" .. v .. "/pyvenv.cfg") and exe(p) then return p end
  end
  if vim.env.VIRTUAL_ENV and exe(vim.env.VIRTUAL_ENV .. "/bin/python") then return vim.env.VIRTUAL_ENV .. "/bin/python" end
  local ws = expand_vscode(M.vscode(root)["python.defaultInterpreterPath"], root)
  if exe(ws) then return ws end
  return default_python()
end

local function has_pytest_config(root)
  if readable(root .. "/pytest.ini") or readable(root .. "/conftest.py") or readable(root .. "/tests/conftest.py") then return true end
  for _, f in ipairs({ "pyproject.toml", "setup.cfg", "tox.ini" }) do
    local p = root .. "/" .. f
    if readable(p) then
      local text = table.concat(vim.fn.readfile(p), "\n")
      if text:match("%[tool%.pytest") or text:match("%[tool:pytest%]") or text:match("%[pytest%]") then return true end
    end
  end
  return false
end

function M.runner(root)
  local s = M.vscode(root)
  if s["python.testing.unittestEnabled"] == true then return "unittest" end
  if s["python.testing.pytestEnabled"] == true then return "pytest" end
  return has_pytest_config(root) and "pytest" or "unittest"
end

-- VS Code's unittest args, or a sensible default for discovery.
function M.unittest_args(root)
  local a = M.vscode(root)["python.testing.unittestArgs"]
  if type(a) == "table" and #a > 0 then return a end
  if isdir(root .. "/tests") then return { "-v", "-s", "./tests", "-p", "test*.py" } end
  return { "-v" }
end

local function start_dir(root)
  local a = M.unittest_args(root)
  for i, v in ipairs(a) do
    if (v == "-s" or v == "--start-directory") and a[i + 1] then return a[i + 1] end
  end
end

local function abs(root, p)
  if p == "" then return nil end
  if p:sub(1, 1) ~= "/" then p = root .. "/" .. p:gsub("^%./", "") end
  return vim.fs.normalize(p)
end

-- base_pythonpath: what PYTHONPATH was before any project touched it.
function M.env(root, base_pythonpath)
  local vars = {}
  local file = root .. "/.env"
  local s = M.vscode(root)
  local custom = expand_vscode(s["python.envFile"], root)
  if custom and readable(custom) then file = custom end
  if readable(file) then
    local parsed = M.parse_env(table.concat(vim.fn.readfile(file), "\n"))
    for k, v in pairs(parsed) do if M.ALLOW[k] then vars[k] = v end end
  end
  local paths = {}
  local sd = start_dir(root)
  if sd and sd ~= "." and sd ~= "./" then table.insert(paths, abs(root, sd)) end
  for p in (vars.PYTHONPATH or ""):gmatch("[^:]+") do table.insert(paths, abs(root, p)) end
  if base_pythonpath and base_pythonpath ~= "" then table.insert(paths, base_pythonpath) end
  vars.PYTHONPATH = #paths > 0 and table.concat(paths, ":") or nil
  return vars
end

-- Apply to Neovim's own environment (inherited by neotest, dap, :terminal).
local original_pythonpath = vim.env.PYTHONPATH
local applied = {}
function M.apply(dir)
  for k in pairs(applied) do vim.env[k] = nil end
  vim.env.PYTHONPATH = original_pythonpath
  applied = {}
  local root = M.root(dir)
  for k, v in pairs(M.env(root, original_pythonpath)) do
    vim.env[k] = v
    applied[k] = true
  end
  vim.g.pytools = { root = root, vars = vim.tbl_keys(applied) }
end

-- `nvim --clean -l pytools.lua --emit DIR` → lines for bin/ut:
--   ROOT <dir> · PYTHON <path> · RUNNER <name> · ENV <KEY>=<value> · ARG <arg>
if _G.arg and _G.arg[1] == "--emit" then
  local root = M.root(_G.arg[2])
  local out = { "ROOT " .. root, "PYTHON " .. M.python(root), "RUNNER " .. M.runner(root) }
  for k, v in pairs(M.env(root, vim.env.PYTHONPATH)) do table.insert(out, "ENV " .. k .. "=" .. v:gsub("\n", "\\n")) end
  for _, a in ipairs(M.unittest_args(root)) do table.insert(out, "ARG " .. a) end
  io.stdout:write(table.concat(out, "\n") .. "\n")
end

return M
