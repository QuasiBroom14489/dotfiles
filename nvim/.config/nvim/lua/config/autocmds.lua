-- Loaded on VeryLazy.

-- C/C++: the old config's indentation (course style guides).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("c_style", { clear = true }),
  pattern = { "c", "cpp" },
  callback = function()
    vim.opt_local.cindent = true
    vim.opt_local.cinoptions = "g0,:0,N-s,(0"
  end,
})

-- Resume-where-you-left-off lives in config/proj.lua (needs to run on
-- VimEnter, before VeryLazy), see init in lua/plugins/proj.lua.
