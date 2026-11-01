-- Sessions and the start screen.

-- persistence: on exit, saves the open buffers, windows and tabs as a
-- session for this folder (and git branch). Nothing is restored unless
-- you ask, with these keys (LazyVim's) or from the start screen.
vim.pack.add({ 'https://github.com/folke/persistence.nvim' })
local persistence = require('persistence')
persistence.setup()

local map = function(lhs, rhs, desc) vim.keymap.set('n', lhs, rhs, { desc = desc }) end
map('<leader>qs', persistence.load, 'Restore session (this folder)')
map('<leader>qS', persistence.select, 'Pick a session')
map('<leader>ql', function() persistence.load({ last = true }) end, 'Restore last session')
map('<leader>qd', persistence.stop, "Don't save this session")

-- mini.starter: shown when nvim starts without files. Typing filters items
-- by the start of their name and runs the one left, so each name begins
-- with its key: f finds a file, s restores the session, q quits.
local starter = require('mini.starter')
local restore = function()
  -- Only offered when this folder has a saved session
  if vim.fn.filereadable(persistence.current()) == 0 then return {} end
  return { { section = '', name = 's  Restore session', action = persistence.load } }
end
starter.setup({
  evaluate_single = true,
  items = {
    { section = '', name = 'f  Find file', action = function() Snacks.picker.files() end },
    restore,
    { section = '', name = 'q  Quit', action = 'qall' },
  },
  footer = '', -- no usage hints
  content_hooks = { starter.gen_hook.aligning('center', 'center') },
})
