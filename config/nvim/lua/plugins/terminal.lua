local split_term
local float_term

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      {
        "vs",
        function()
          local Terminal = require("toggleterm.terminal").Terminal
          split_term = split_term or Terminal:new({
            direction = "horizontal",
            hidden = true,
          })
          split_term:toggle()
        end,
        mode = "n",
        desc = "Toggle terminal split",
      },
      {
        "vp",
        function()
          local Terminal = require("toggleterm.terminal").Terminal
          float_term = float_term or Terminal:new({
            direction = "float",
            hidden = true,
            float_opts = {
              border = "rounded",
            },
          })
          float_term:toggle()
        end,
        mode = "n",
        desc = "Toggle terminal popup",
      },
    },
    opts = {
      direction = "horizontal",
      persist_size = false,
      shade_terminals = false,
      size = 15,
      float_opts = {
        border = "rounded",
      },
    },
  },
}
