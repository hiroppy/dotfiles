local map = vim.keymap.set
local plain_modes = { "n", "x", "o" }

map("n", "j", "gj")
map("n", "k", "gk")
map("n", "gj", "j")
map("n", "gk", "k")
map("n", "x", [["_x]])
map("n", "D", [["_D]])

map("i", "jj", "<Esc>")
map("i", "{<CR>", "{}<Left><CR><Esc><S-o>")
map("i", "[<CR>", "[]<Left><CR><Esc><S-o>")
map("i", "(<CR>", "()<Left><CR><Esc><S-o>")

map("n", "<CR>", function()
  local line = vim.api.nvim_win_get_cursor(0)[1]

  for _ = 1, vim.v.count1 do
    vim.fn.append(line, "")
    line = line + 1
  end
end, { silent = true })

map(plain_modes, "<Space>h", "0")
map(plain_modes, "<Space>l", "$")
map("n", "n", "nzz")
map(plain_modes, ";", ":")
map(plain_modes, ":", ";")

map("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { silent = true })

map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

map("n", "st", "<cmd>split<CR>")
map("n", "sd", "<cmd>vsplit<CR>")

map("t", "jj", "<C-\\><C-n>", { silent = true })
map("n", "<ScrollWheelUp>", ":!<CR>")

map("n", "ff", vim.lsp.buf.definition, { desc = "LSP definition" })
map("n", "fff", vim.lsp.buf.references, { desc = "LSP references" })
