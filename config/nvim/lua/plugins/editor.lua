return {
  {
    "nvim-tree/nvim-web-devicons",
    lazy = true,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      close_if_last_window = false,
      window = {
        position = "left",
        width = 32,
      },
      filesystem = {
        group_empty_dirs = true,
        hijack_netrw_behavior = "open_default",
        follow_current_file = {
          enabled = true,
        },
      },
      default_component_configs = {
        git_status = {
          symbols = {
            added = "✚",
            modified = "➜",
            deleted = "✘",
            renamed = "󰁕",
            untracked = "✚",
            ignored = "",
            unstaged = "",
            staged = "",
            conflict = "",
          },
        },
      },
    },
    config = function(_, opts)
      require("neo-tree").setup(opts)

      local command = require("neo-tree.command")

      vim.keymap.set("n", "<C-e>", function()
        command.execute({
          source = "filesystem",
          position = "left",
          toggle = true,
        })
      end, { desc = "Toggle file tree", silent = true })
    end,
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "✚" },
        change = { text = "➜" },
        delete = { text = "✘" },
        topdelete = { text = "✘" },
        changedelete = { text = "➜" },
        untracked = { text = "✚" },
      },
    },
  },
  {
    "numToStr/Comment.nvim",
    keys = {
      {
        "<S-K>",
        function()
          require("Comment.api").toggle.linewise.current()
        end,
        mode = "n",
        desc = "Toggle comment",
      },
      {
        "<S-K>",
        function()
          local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
          vim.api.nvim_feedkeys(esc, "nx", false)
          require("Comment.api").toggle.linewise(vim.fn.visualmode())
        end,
        mode = "x",
        desc = "Toggle comment",
      },
    },
    opts = {},
  },
  {
    "junegunn/vim-easy-align",
    keys = {
      { "<Enter>", "<Plug>(EasyAlign)", mode = "x", remap = true, desc = "Easy align" },
    },
  },
}
