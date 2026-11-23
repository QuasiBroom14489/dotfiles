-- Python tests and debugging, matched to how VS Code runs them.
-- Interpreter, runner and environment come from lua/config/pytools.lua —
-- the same file `ut` uses, so editor and terminal agree.
local pytools = require("config.pytools")
-- debugpy lives in its own uv venv: Mason builds it with Homebrew's newest
-- Python, whose ensurepip is broken here (python@3.14). bootstrap.sh makes it.
local debugpy = vim.fn.stdpath("data") .. "/debugpy/bin/python"

-- Python 3.13+ colours tracebacks whenever it sees a terminal, and neotest
-- runs tests under a pty, so failure messages and Trouble showed raw escape
-- codes (^[[35m…). Programs Neovim starts get plain output; `ut` in a Zellij
-- pane is not affected.
if vim.env.PYTHON_COLORS == nil then vim.env.PYTHON_COLORS = "0" end

return {
  -- LazyVim's dap extra asks mason-nvim-dap to install a debugger for every
  -- adapter. The python adapter comes from dap-python + the uv venv above,
  -- so skip it (otherwise: "automatically installing debugpy" on every load).
  {
    "jay-babu/mason-nvim-dap.nvim",
    optional = true,
    opts = { automatic_installation = { exclude = { "python" } } },
  },
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["neotest-python"] = {
          python = function(root) return { pytools.python(pytools.root(root)) } end,
          -- VS Code's python.testing.*Enabled wins; a venv that merely has
          -- pytest installed must not switch a unittest project to pytest.
          runner = function() return pytools.runner(pytools.root()) end,
        },
      },
    },
  },
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      if vim.fn.executable(debugpy) ~= 1 then
        vim.notify("Python debugging needs: uv venv " .. vim.fn.fnamemodify(debugpy, ":h:h")
          .. " && uv pip install --python " .. debugpy .. " debugpy", vim.log.levels.WARN)
        return
      end
      local dap_python = require("dap-python")
      dap_python.setup(debugpy)
      -- The program being debugged runs on the project's interpreter.
      dap_python.resolve_python = function() return pytools.python(pytools.root()) end
    end,
  },
}
