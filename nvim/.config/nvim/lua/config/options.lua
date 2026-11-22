-- Loaded before lazy.nvim starts. LazyVim's defaults already cover leader =
-- space, relative numbers, 2-space indent, clipboard, undofile, smartcase.
-- These are the carry-overs from the old config that differ from them.
local opt = vim.opt
opt.colorcolumn = "80"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.swapfile = false
opt.wrap = false

-- Python test environment (allowlisted .env vars, test folder on
-- PYTHONPATH) for neotest / the debugger / :terminal — see config/pytools.lua.
require("config.pytools").apply()
vim.api.nvim_create_autocmd("DirChanged", {
  group = vim.api.nvim_create_augroup("pytools", { clear = true }),
  callback = function() require("config.pytools").apply() end,
})
