local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Languages across ~/ projects and coursework. Each extra brings its
    -- LSP (installed by Mason), formatter and treesitter parsers.
    { import = "lazyvim.plugins.extras.lang.clangd" },     -- C/C++: CSE courses
    { import = "lazyvim.plugins.extras.lang.python" },     -- alphalab, ResaleClassifier
    { import = "lazyvim.plugins.extras.lang.typescript" }, -- web projects
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.rust" },
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "tokyonight", "habamax" } },
  -- Check for plugin updates quietly; :Lazy shows them, no popups.
  checker = { enabled = true, notify = false },
  change_detection = { notify = false },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})
