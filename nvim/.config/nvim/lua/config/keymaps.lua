-- Loaded on VeryLazy. Carry-overs from the old config that LazyVim doesn't
-- already provide. (Old <leader>w / <leader>q / <leader>d are LazyVim groups
-- now — windows / quit+session / debug; save is <C-s> or :w.)
local map = vim.keymap.set

map("i", "jk", "<Esc>", { desc = "Leave insert mode" })

-- Keep the cursor centred when jumping.
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centred)" })
map("n", "n", "nzzzv", { desc = "Next match (centred)" })
map("n", "N", "Nzzzv", { desc = "Previous match (centred)" })

map("n", "J", "mzJ`z", { desc = "Join lines, keep cursor" })
map("x", "<leader>p", [["_dP]], { desc = "Paste over, keep register" })
map("n", "<C-a>", "ggVG", { desc = "Select all" })

-- Move the selected lines (old config). LazyVim's own <A-j>/<A-k> never
-- arrive: Zellij uses Alt+j/k to move between panes.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })
