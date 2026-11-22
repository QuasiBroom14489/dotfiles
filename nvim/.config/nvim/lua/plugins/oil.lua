-- Carried over from the old config: edit the file system like a buffer.
-- `-` opens the parent directory of the current file.
return {
  {
    "stevearc/oil.nvim",
    cmd = "Oil",
    keys = { { "-", "<cmd>Oil<cr>", desc = "Open parent directory (oil)" } },
    opts = { default_file_explorer = false, view_options = { show_hidden = true } },
  },
}
