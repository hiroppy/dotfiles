return {
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      require("lspsaga").setup({
        ui = {
          border = "rounded",
        },
      })

      vim.keymap.set("n", "K", "<cmd>Lspsaga hover_doc<CR>", {
        desc = "LSP hover",
        silent = true,
      })
    end,
  },
}
