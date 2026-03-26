return {
  {
    "nordtheme/vim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("nord")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        globalstatus = true,
        theme = "nord",
        component_separators = "",
        section_separators = "",
      },
    },
  },
}
