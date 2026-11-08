-- Editing: text objects, surround and jumping. Keys as in LazyVim.

-- mini.nvim is a library of small independent modules; each does nothing
-- until its setup() is called. (The UI ones are set up in 30_ui.lua.)

-- mini.ai: more a/i text objects, e.g. ciq (inside any quote), dab (around
-- any bracket), via (an argument), cif (a function call's contents). They
-- also work on the next match, so ci" from before the quotes jumps to them.
require('mini.ai').setup({
  n_lines = 500, -- How far to look for a match (default 50)
})

-- mini.pairs (as in LazyVim): typing ( [ { ' " or ` inserts its pair, the
-- closing one steps over an existing one, and backspace between a pair
-- deletes both. Insert mode only.
require('mini.pairs').setup()

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

-- yanky: yank history, and puts that know about it (LazyVim's yanky extra).
-- After a paste, [y ]y swap it for an earlier / later yank; <leader>sy picks
-- one from the history. ]p [p paste on the line below / above, indented
-- like this one, even a word; >p <p paste and indent.
require('yanky').setup({
  -- Clipboard changes join the history, but not over SSH (no clipboard:
  -- 10_options.lua)
  system_clipboard = { sync_with_ring = not vim.env.SSH_CONNECTION },
  -- Pastes flash briefly; yanks already do (15_autocmds.lua)
  highlight = { on_yank = false, timer = 150 },
})
local plug = function(name) return '<Plug>(Yanky' .. name .. ')' end
map({ 'n', 'x' }, 'y', plug('Yank'), { desc = 'Yank' })
map({ 'n', 'x' }, 'p', plug('PutAfter'), { desc = 'Put after' })
map({ 'n', 'x' }, 'P', plug('PutBefore'), { desc = 'Put before' })
map({ 'n', 'x' }, 'gp', plug('GPutAfter'), { desc = 'Put after, cursor after' })
map({ 'n', 'x' }, 'gP', plug('GPutBefore'), { desc = 'Put before, cursor after' })
map('n', '[y', plug('CycleForward'), { desc = 'Earlier yank' })
map('n', ']y', plug('CycleBackward'), { desc = 'Later yank' })
map('n', ']p', plug('PutIndentAfterLinewise'), { desc = 'Put below, indented' })
map('n', '[p', plug('PutIndentBeforeLinewise'), { desc = 'Put above, indented' })
map('n', '>p', plug('PutIndentAfterShiftRight'), { desc = 'Put below, indent right' })
map('n', '<p', plug('PutIndentAfterShiftLeft'), { desc = 'Put below, indent left' })
map('n', '>P', plug('PutIndentBeforeShiftRight'), { desc = 'Put above, indent right' })
map('n', '<P', plug('PutIndentBeforeShiftLeft'), { desc = 'Put above, indent left' })
