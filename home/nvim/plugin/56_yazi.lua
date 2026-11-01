-- yazi (the same file manager as Alt+o) full screen inside nvim, in place
-- of LazyVim's explorer. Pick a file and it opens in nvim; C-v / C-x open
-- it in a split, F1 lists the keys. Opening a directory (`nvim .`) uses
-- yazi too, instead of the built-in netrw.

vim.g.loaded_netrwPlugin = 1 -- don't load netrw at all

vim.pack.add({
  'https://github.com/nvim-lua/plenary.nvim', -- yazi.nvim uses it for paths
  'https://github.com/mikavilpas/yazi.nvim',
})
require('yazi').setup({
  open_for_directories = true,
  floating_window_scaling_factor = 1, -- full screen
})

vim.keymap.set('n', '<leader>e', '<cmd>Yazi<cr>', { desc = 'Yazi (current file)' })
vim.keymap.set('n', '<leader>E', '<cmd>Yazi cwd<cr>', { desc = 'Yazi (cwd)' })
