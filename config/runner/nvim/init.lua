-- Small, plugin-free Neovim profile for the interactive build runner.
-- No plugin manager, background updater, Treesitter download, or LSP bootstrap.

local opt = vim.opt

vim.g.mapleader = " "
vim.g.maplocalleader = " "

opt.number = true
opt.relativenumber = false
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.laststatus = 2
opt.showmode = false
opt.scrolloff = 4
opt.sidescrolloff = 4

opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true
opt.wrap = false

opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true
opt.updatetime = 250
opt.timeoutlen = 400
opt.ttimeoutlen = 10

opt.splitright = true
opt.splitbelow = true
opt.completeopt = "menuone,noselect"
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.swapfile = true
opt.backup = false
opt.writebackup = true
opt.undofile = true

local undodir = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undodir, "p")
opt.undodir = undodir

vim.g.netrw_banner = 0
vim.g.netrw_liststyle = 3

vim.cmd("filetype plugin indent on")
vim.cmd("syntax enable")
opt.shortmess:append("I")

vim.keymap.set("n", "<leader>w", "<cmd>write<cr>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quit" })
vim.keymap.set("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File browser" })
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
