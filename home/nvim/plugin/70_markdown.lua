-- Markdown and notes. Servers (enabled in 60_lsp.lua) come from Nix:
-- marksman for links, headings and references; rumdl for lint and format.

-- Prose filetypes: wrap long lines and check spelling (as in LazyVim).
-- `zg` adds a word to spell/en.utf-8.add, which lives in this repo.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('config-prose', {}),
  pattern = { 'markdown', 'text', 'gitcommit', 'typst', 'tex' },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

-- The compiled .spl isn't committed: rebuild it when the word list is newer
-- (zg updates both, but a git pull only brings the .add).
local words = vim.fn.stdpath('config') .. '/spell/en.utf-8.add'
if vim.fn.getftime(words) > vim.fn.getftime(words .. '.spl') then
  vim.cmd('silent mkspell! ' .. vim.fn.fnameescape(words))
end

-- render-markdown: headings, lists, code blocks and tables drawn in place
-- (raw text comes back on the cursor line). <leader>um toggles it.
require('render-markdown').setup({
  latex = { enabled = false },
  -- Lists and tasks stay as typed (- and [ ] / [x]), not swapped for icons.
  checkbox = { enabled = false },
  -- Draw a code block's ``` lines as thin edges instead of hiding them
  -- (the default), so its start and end stay visible.
  code = { border = 'thin' },
})
vim.keymap.set(
  'n',
  '<leader>um',
  '<cmd>RenderMarkdown toggle<cr>',
  { desc = 'Toggle markdown render' }
)

-- zk: notes. Its language server (links, tags, backlinks) starts in any
-- folder with a .zk notebook (if zk is installed).
if vim.fn.executable('zk') == 1 then
  require('zk').setup({
    picker = 'snacks_picker',
  })
  -- Inside a notebook: <leader>n makes a note (in the current file's
  -- folder), and <leader><space> finds notes instead of files
  -- (55_picker.lua; <leader>ff always finds files).
  local zk_util = require('zk.util')
  local in_notebook = function() return zk_util.notebook_root(zk_util.resolve_notebook_path(0)) end
  vim.keymap.set('n', '<leader>n', function()
    if not in_notebook() then return vim.notify('Not in a zk notebook') end
    local dir = vim.fn.expand('%:p:h')
    require('zk').new({
      dir = dir ~= '' and dir or vim.fn.getcwd(),
      title = vim.fn.input('Title: '),
    })
  end, { desc = 'New note (zk notebook)' })
  vim.keymap.set('n', '<leader><space>', function()
    if in_notebook() then
      vim.cmd('ZkNotes')
    else
      Snacks.picker.files()
    end
  end, { desc = 'Find files (notes in a zk notebook)' })
end
