-- Editing: text objects, surround and jumping. Keys as in LazyVim.

-- mini.nvim is a library of small independent modules; each does nothing
-- until its setup() is called. (mini.icons is set up in 30_ui.lua.)

-- mini.ai: more a/i text objects, e.g. ciq (inside any quote), dab (around
-- any bracket), via (an argument), cif (a function call's contents). They
-- also work on the next match, so ci" from before the quotes jumps to them.
require('mini.ai').setup({
  n_lines = 500, -- How far to look for a match (default 50)
})

-- mini.surround under gs (LazyVim's prefix; plain s is flash's).
-- gsa{motion}{char} add, gsd{char} delete, gsr{old}{new} replace.
-- E.g. gsaiw" quotes a word, gsd( strips brackets, gsr'" swaps quotes.
require('mini.surround').setup({
  mappings = {
    add = 'gsa',
    delete = 'gsd',
    find = 'gsf',
    find_left = 'gsF',
    highlight = 'gsh',
    replace = 'gsr',
    update_n_lines = 'gsn',
  },
})

-- flash: s and a couple of characters, then the label shown at the
-- wanted match. S selects a treesitter node (function, block, ...).
local flash = require('flash')
flash.setup()
local map = vim.keymap.set
map({ 'n', 'x', 'o' }, 's', flash.jump, { desc = 'Flash' })
map({ 'n', 'x', 'o' }, 'S', flash.treesitter, { desc = 'Flash treesitter' })
map('o', 'r', flash.remote, { desc = 'Remote flash' }) -- e.g. yr<jump>iw: yank a word elsewhere
map({ 'o', 'x' }, 'R', flash.treesitter_search, { desc = 'Treesitter search' })
map('c', '<C-s>', flash.toggle, { desc = 'Toggle flash in / search' })
