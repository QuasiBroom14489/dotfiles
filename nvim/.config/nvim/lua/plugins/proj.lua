-- Session resume for proj workspaces (logic in lua/config/proj.lua).
local proj = require("config.proj")
proj.setup()

return {
  -- With a saved session to restore, skip the start screen.
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      if proj.is_project_start() and proj.session_file() then
        opts.dashboard = vim.tbl_extend("force", opts.dashboard or {}, { enabled = false })
      end
    end,
  },
}
