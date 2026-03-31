return {
  {
    "nordtheme/vim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("nord")
      vim.api.nvim_set_hl(0, "Normal", { bg = "#1e222a" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = "#1e222a" })
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
