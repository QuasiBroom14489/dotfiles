-- Python tests and debugging, matched to how VS Code runs them.
-- Interpreter, runner and environment come from lua/config/pytools.lua —
-- the same file `ut` uses, so editor and terminal agree.
local pytools = require("config.pytools")
-- debugpy lives in its own uv venv: Mason builds it with Homebrew's newest
-- Python, whose ensurepip is broken here (python@3.14). bootstrap.sh makes it.
local debugpy = vim.fn.stdpath("data") .. "/debugpy/bin/python"

return {
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
