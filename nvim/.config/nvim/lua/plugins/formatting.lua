-- Space c f (and format-on-save) for Python. LazyVim's python extra only adds
-- Ruff as a linter/LSP, which left Python with "No formatter available".
-- ruff (Mason) sorts imports, then formats — the same as `ruff check --select I
-- --fix` + `ruff format`. It cannot format a file that doesn't parse (e.g. an
-- indentation error): fix the line it points to first.
return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        python = { "ruff_organize_imports", "ruff_format" },
      },
    },
  },
}
