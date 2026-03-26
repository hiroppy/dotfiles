local opt = vim.opt

opt.autoindent = true
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2

opt.cursorline = true
opt.number = true
opt.showmatch = true
opt.title = true
opt.wrap = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.laststatus = 3
opt.background = "dark"

opt.backspace = { "indent", "eol", "start" }
opt.clipboard = "unnamedplus"
opt.hlsearch = true
opt.ignorecase = true
opt.incsearch = true
opt.matchpairs:append("<:>")
opt.matchtime = 3
opt.backup = false
opt.swapfile = false
opt.writebackup = false
opt.sessionoptions:remove("options")
opt.smartcase = true
opt.switchbuf = "useopen"
opt.wildmenu = true
opt.undofile = true
opt.undodir = vim.fn.stdpath("config") .. "/undo"
opt.mouse = "a"
opt.splitbelow = true
opt.splitright = true
opt.updatetime = 200
opt.scrolloff = 4

opt.fileencodings = { "utf-8", "sjis", "cp932", "euc-jp" }
opt.fileformats = { "unix", "mac", "dos" }
