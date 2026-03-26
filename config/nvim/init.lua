if vim.loader then
  vim.loader.enable()
end

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
