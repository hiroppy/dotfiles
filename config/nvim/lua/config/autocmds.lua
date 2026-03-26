local group = vim.api.nvim_create_augroup("hiroppy", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "go",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = "html",
  callback = function(event)
    vim.keymap.set("i", "</", "</<C-x><C-o>", { buffer = event.buf })
  end,
})
