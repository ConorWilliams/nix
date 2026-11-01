-- Options. Only things that differ from Neovim 0.12's defaults; mostly the
-- LazyVim settings carried over. See :help '<option>' for any of them.

-- General
vim.o.undofile = true -- Persistent undo across sessions
vim.o.confirm = true -- Ask to save instead of failing on :q with changes
vim.o.updatetime = 200 -- Faster CursorHold (diagnostics, highlights)
vim.o.timeoutlen = 300 -- Faster key-sequence timeout
-- System clipboard locally; over SSH keep yanks inside nvim
vim.o.clipboard = vim.env.SSH_CONNECTION and '' or 'unnamedplus'

-- UI
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = 'yes' -- Always show, so text doesn't shift
vim.o.wrap = false
vim.o.linebreak = true -- If wrap is turned on, break at word boundaries
vim.o.breakindent = true -- ...and indent wrapped lines
vim.o.list = true -- Show tabs and trailing spaces
vim.o.listchars = 'tab:> ,trail:·,nbsp:␣,extends:…,precedes:…'
vim.o.fillchars = 'eob: ' -- No ~ on empty lines past the end of the buffer
vim.o.sidescrolloff = 8
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.laststatus = 3 -- One global statusline
vim.o.showmode = false -- The statusline shows the mode
vim.o.winborder = 'rounded' -- Borders on floating windows (hover, etc.)
vim.o.pumheight = 10 -- At most 10 completion items visible
vim.o.mousescroll = 'ver:1,hor:2' -- Touchpad/wheel: 1 line per step (smoother than 3)

-- Editing
vim.o.expandtab = true
vim.o.shiftwidth = 2 -- Overridden per language by ftplugins/editorconfig
vim.o.tabstop = 2
vim.o.shiftround = true -- Round indents to a multiple of shiftwidth
vim.o.smartindent = true
vim.o.virtualedit = 'block' -- Visual block can go past line ends
vim.o.ignorecase = true -- Case-insensitive search...
vim.o.smartcase = true -- ...unless the pattern has capitals
vim.o.inccommand = 'split' -- Live preview of :s substitutions
