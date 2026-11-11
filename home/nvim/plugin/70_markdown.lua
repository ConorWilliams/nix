-- Markdown and notes. Servers (enabled in 60_lsp.lua) come from Nix:
-- marksman for links, headings and references; rumdl for lint and format.

-- Prose filetypes: wrap long lines and check spelling (as in LazyVim).
-- `zg` adds a word to spell/en.utf-8.add, which lives in this repo.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-prose', {}),
  pattern = { 'markdown', 'text', 'gitcommit', 'typst', 'tex' },
  callback = function(ev)
    vim.opt_local.wrap = true
    -- (the others have a treesitter parser, which turns spelling on:
    -- 40_treesitter.lua)
    if ev.match == 'text' then vim.opt_local.spell = true end
  end,
})

-- `zg` saves words to this repo's list (since nvim 0.12 it otherwise uses
-- one under ~/.local/share). The compiled .spl isn't committed: rebuild it
-- when the word list is newer (zg updates both, but a git pull only brings
-- the .add).
local words = vim.fn.stdpath('config') .. '/spell/en.utf-8.add'
vim.o.spellfile = words
if vim.fn.getftime(words) > vim.fn.getftime(words .. '.spl') then
  vim.cmd('silent mkspell! ' .. vim.fn.fnameescape(words))
end
Snacks.toggle.option('spell', { name = 'Spelling' }):map('<leader>us')

-- render-markdown: headings, lists, code blocks and tables drawn in place
-- (raw text comes back on the cursor line). <leader>um toggles it.
require('render-markdown').setup({
  latex = { enabled = false },
  -- Task boxes stay as typed ([ ] / [x]), not swapped for icons (list
  -- dashes do become bullets).
  checkbox = { enabled = false },
  -- Draw a code block's ``` lines as thin edges instead of hiding them
  -- (the default), so its start and end stay visible.
  code = { border = 'thin' },
})
Snacks.toggle({
  name = 'Markdown render',
  get = require('render-markdown').get,
  set = require('render-markdown').set,
}):map('<leader>um')

-- zk: notes. Its language server (links, tags, backlinks) starts in any
-- folder with a .zk notebook.
require('zk').setup({
  picker = 'snacks_picker',
})
-- Inside a notebook: <leader>z makes a note (at its root: the notebook's
-- config says where it goes), and <leader><space> finds notes instead of
-- files (<leader>f always finds files).
local zk_util = require('zk.util')
local in_notebook = function()
  local path = zk_util.resolve_notebook_path(0)
  return path and zk_util.notebook_root(path)
end
vim.keymap.set('n', '<leader>z', function()
  if not in_notebook() then return vim.notify('Not in a zk notebook') end
  local title = vim.fn.input('Title: ')
  if title == '' then return end -- Esc (or no title) cancels
  require('zk').new({ dir = in_notebook(), title = title })
end, { desc = 'New zk note' })
vim.keymap.set('n', '<leader><space>', function()
  if in_notebook() then
    vim.cmd('ZkNotes')
  else
    Snacks.picker.files()
  end
end, { desc = 'Find files (or zk notes)' })
