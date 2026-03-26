return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    cmd = "Mason",
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "folke/lazydev.nvim",
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local servers = {
        bashls = {},
        jsonls = {},
        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = "Replace",
              },
              diagnostics = {
                globals = { "vim" },
              },
              telemetry = {
                enable = false,
              },
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        },
        ts_ls = {},
        yamlls = {},
      }

      vim.diagnostic.config({
        severity_sort = true,
        float = {
          border = "rounded",
          source = "if_many",
        },
        signs = true,
        underline = true,
        update_in_insert = false,
        virtual_text = {
          source = "if_many",
          spacing = 2,
        },
      })

      for server, config in pairs(servers) do
        vim.lsp.config(server, vim.tbl_deep_extend("force", {
          capabilities = capabilities,
        }, config))
      end

      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_enable = true,
      })
    end,
  },
}
