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
vim.pack.add({ 'https://github.com/MeanderingProgrammer/render-markdown.nvim' })
require('render-markdown').setup({
  latex = { enabled = false },
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
  vim.pack.add({ 'https://github.com/zk-org/zk-nvim' })
  require('zk').setup({
    picker = 'snacks_picker',
  })
  vim.keymap.set('n', '<leader>z', '<cmd>ZkNotes<cr>', { desc = 'Find note' })
  vim.keymap.set(
    'n',
    '<leader>Z',
    "<cmd>ZkNew { dir = vim.fn.expand('%:p:h'), title = vim.fn.input('Title: ') }<cr>",
    { desc = 'New note (in this dir)' }
  )
end
