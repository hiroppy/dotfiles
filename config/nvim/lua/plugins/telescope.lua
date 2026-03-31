return {
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    keys = {
      { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<C-g>", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<C-b>", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
    },
    opts = {
      defaults = {
        borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
      },
    },
  },
}
