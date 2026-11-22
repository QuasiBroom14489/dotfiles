-- Completion (blink.cmp) tuned toward how VS Code behaves.
-- LazyVim's defaults stay underneath: Enter accepts, Ctrl-n/p move, docs
-- pop up beside the menu, Noice shows signature help while typing arguments.

-- Python: VS Code lists modules right after `import ` and names right after
-- `from x import `. Pyright doesn't treat space as a trigger character, so
-- blink would wait for the first letter. These patterns (text before the
-- cursor) open the menu at those spots.
local py_import_spots = {
  "^%s*import%s+$", -- import |
  "^%s*import%s+.*,%s*$", -- import os, |
  "^%s*from%s+$", -- from |
  "^%s*from%s+[%w_.]+%s+import%s+$", -- from os import |
  "^%s*from%s+[%w_.]+%s+import%s+.*,%s*$", -- from os import path, |
}

local function at_import_spot()
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local before = vim.api.nvim_get_current_line():sub(1, col)
  for _, pat in ipairs(py_import_spots) do
    if before:find(pat) then return true end
  end
  return false
end

return {
  {
    "saghen/blink.cmp",
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("py_import_completion", { clear = true }),
        pattern = "python",
        callback = function(ev)
          vim.api.nvim_create_autocmd("TextChangedI", {
            group = "py_import_completion",
            buffer = ev.buf,
            callback = function()
              if not at_import_spot() then return end
              -- Deferred: typing the space first makes blink close the menu
              -- that was open for the previous word (`import`), and that
              -- close lands after this autocmd. Showing now would be undone.
              vim.schedule(function()
                local ok, cmp = pcall(require, "blink.cmp")
                if ok and vim.fn.mode() == "i" and at_import_spot() then cmp.show() end
              end)
            end,
          })
        end,
      })
    end,
    opts = function(_, opts)
      -- Tab accepts the highlighted item when the menu is open (VS Code);
      -- otherwise it keeps LazyVim's behavior: jump to the next snippet
      -- field, or insert a real tab. Setting <Tab> here stops LazyVim from
      -- adding its own, so its snippet/AI chain is repeated in full.
      opts.keymap["<Tab>"] = {
        "accept",
        LazyVim.cmp.map({ "snippet_forward", "ai_nes", "ai_accept" }),
        "fallback",
      }

      -- Typing a whole word puts that exact item first (`import` the
      -- keyword above `importlib`), then fuzzy score, then the server's order.
      opts.fuzzy = vim.tbl_deep_extend("force", opts.fuzzy or {}, {
        sorts = { "exact", "score", "sort_text" },
      })

      -- Name each item's kind on the right (Module, Function, Keyword…), so
      -- the menu says what you're picking, not just an icon.
      opts.completion.menu.draw.columns = {
        { "kind_icon" },
        { "label", "label_description", gap = 1 },
        { "kind" },
      }
    end,
  },
}
