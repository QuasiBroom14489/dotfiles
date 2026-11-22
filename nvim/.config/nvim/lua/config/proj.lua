-- Per-project session resume for `proj` (~/dotfiles/bin/proj).
--
-- Every project has its own Zellij session; inside it, Neovim should come
-- back with the files you had open. persistence.nvim (bundled with LazyVim)
-- keeps one session per working directory — this file decides when to load
-- it automatically and keeps it saved as you go.
local M = {}

-- Opened by a proj layout: inside Zellij, with no file arguments (bare `nvim`,
-- or `nvim .` from the first version of the layouts).
function M.is_project_start()
  if not vim.env.ZELLIJ_SESSION_NAME or vim.g.started_with_stdin then return false end
  local argv = vim.fn.argv()
  if #argv == 0 then return true end
  if #argv == 1 and vim.fn.isdirectory(argv[1]) == 1 then
    return vim.fn.fnamemodify(argv[1], ":p"):gsub("/$", "") == vim.fn.getcwd()
  end
  return false
end

function M.session_file()
  local ok, persistence = pcall(require, "persistence")
  if not ok then return nil end
  local file = persistence.current()
  if file and vim.fn.filereadable(file) == 1 then return file end
  -- persistence names sessions per branch; fall back to the branchless one.
  file = persistence.current({ branch = false })
  if file and vim.fn.filereadable(file) == 1 then return file end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("proj_session", { clear = true })

  vim.api.nvim_create_autocmd("StdinReadPre", {
    group = group,
    callback = function() vim.g.started_with_stdin = true end,
  })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true, -- so restored buffers fire their FileType/LSP autocmds
    callback = function()
      if not M.is_project_start() then
        -- An ad-hoc `nvim notes.txt` in another pane of the project must not
        -- overwrite the editor's session with its one file on exit.
        if vim.env.ZELLIJ_SESSION_NAME then pcall(function() require("persistence").stop() end) end
        return
      end
      vim.g.proj_session = true
      local file = M.session_file()
      if not file then return end
      vim.cmd("silent! %bwipeout!") -- drop the directory buffer from `nvim .`
      vim.cmd("silent! source " .. vim.fn.fnameescape(file))
    end,
  })

  -- persistence saves on exit, but a reboot or `proj end` kills Neovim
  -- without one — so save whenever a file is written or focus leaves.
  vim.api.nvim_create_autocmd({ "BufWritePost", "FocusLost", "VimSuspend" }, {
    group = group,
    callback = function()
      if vim.g.proj_session then
        pcall(function() require("persistence").save() end)
      end
    end,
  })
end

return M
