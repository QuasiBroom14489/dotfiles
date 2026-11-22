-- Loaded before lazy.nvim starts. LazyVim's defaults already cover leader =
-- space, relative numbers, 2-space indent, clipboard, undofile, smartcase.
-- These are the carry-overs from the old config that differ from them.
local opt = vim.opt
opt.colorcolumn = "80"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.swapfile = false
opt.wrap = false
