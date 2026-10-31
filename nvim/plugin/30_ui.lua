-- Look and feel. vim.pack.add installs a plugin on first start (asking
-- first), records its exact commit in nvim-pack-lock.json, and loads it.
-- Update later with :lua vim.pack.update(), which shows a diff to accept.

-- Colour scheme. Follows 'background', which nvim detects from the
-- terminal, so kitty's light theme gets the Dawn variant.
vim.pack.add({ { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' } })
vim.cmd.colorscheme('rose-pine')

-- mini.nvim: one repo of small modules (icons here; ai and surround in
-- 50_editing.lua). Icons for file types, used by which-key and others.
vim.pack.add({ 'https://github.com/nvim-mini/mini.nvim' })
require('mini.icons').setup()

-- which-key: pause after a prefix (e.g. <Space>) to see what follows
vim.pack.add({ 'https://github.com/folke/which-key.nvim' })
require('which-key').setup({
  preset = 'helix', -- LazyVim's layout: a narrow column in the bottom right
  spec = {
    -- Names for the leader groups, so the popup shows "+buffer" etc.
    { '<leader>b', group = 'buffer' },
    { '<leader>c', group = 'code' },
    { '<leader>f', group = 'file/find' },
    { '<leader>q', group = 'quit/session' },
    { '<leader>u', group = 'ui' },
    { '<leader>w', group = 'windows' },
    { '<leader><tab>', group = 'tabs' },
    { 'gs', group = 'surround' },
    { '[', group = 'prev' },
    { ']', group = 'next' },
    { 'g', group = 'goto' },
  },
})
