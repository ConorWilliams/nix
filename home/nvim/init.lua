-- Entry point. Kept tiny: Neovim then sources every plugin/*.lua file
-- in alphabetical order, which is where the actual config lives.

-- Cache compiled Lua modules (faster startup).
vim.loader.enable()

-- Leader keys must be set before any mapping that uses them.
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'
