-- Look and feel. vim.pack.add installs a plugin on first start (asking
-- first), records its exact commit in nvim-pack-lock.json, and loads it.
-- Update later with :lua vim.pack.update(), which shows a diff to accept.

-- Colour scheme: Rose Pine Dawn, always (detecting the terminal's
-- background fails over mosh and inside zellij).
vim.pack.add({ { src = 'https://github.com/rose-pine/neovim', name = 'rose-pine' } })
require('rose-pine').setup({ variant = 'dawn' })
vim.cmd.colorscheme('rose-pine')

-- Command line and messages: Neovim 0.12's built-in redesign (ui2,
-- experimental). The command line row is hidden until : or / is typed,
-- and messages show in a small window that disappears by itself, so
-- there are no "Press ENTER" prompts. Use :messages for the history.
vim.o.cmdheight = 0
require('vim._core.ui2').enable({ msg = { targets = 'msg' } })

-- go-up: scroll above line 1, as is possible below the last line, so zz can
-- centre the top of a file too. As before, it sets scrolloff=0 and
-- splitkeep=topline (overriding 10_options.lua), which it needs to work well.
vim.pack.add({ 'https://github.com/nullromo/go-up.nvim' })
require('go-up').setup()

-- mini.nvim: one repo of small modules (icons here; ai and surround in
-- 50_editing.lua). Icons for file types, used by which-key and others.
vim.pack.add({ 'https://github.com/nvim-mini/mini.nvim' })
require('mini.icons').setup()
MiniIcons.mock_nvim_web_devicons() -- for plugins that expect nvim-web-devicons

-- Statusline at the bottom, kept light: mode, git branch, diagnostics
-- counts, file name (+ [+] when modified), then macro recording (@q; ui2
-- with cmdheight=0 doesn't show it), search count and line:col.
local statusline = require('mini.statusline')
statusline.setup({
  content = {
    active = function()
      local mode, mode_hl = statusline.section_mode({ trunc_width = 120 })
      return statusline.combine_groups({
        { hl = mode_hl, strings = { mode } },
        {
          hl = 'MiniStatuslineDevinfo',
          strings = { statusline.section_git({}), statusline.section_diagnostics({}) },
        },
        '%<', -- truncate from here when narrow
        { hl = 'MiniStatuslineFilename', strings = { '%f%m%r' } }, -- path from cwd
        '%=', -- the rest goes on the right
        {
          hl = mode_hl,
          strings = {
            vim.fn.reg_recording() ~= '' and ('@' .. vim.fn.reg_recording()) or '',
            statusline.section_searchcount({}),
            '%l:%v',
          },
        },
      })
    end,
  },
})

vim.api.nvim_create_autocmd({ 'RecordingEnter', 'RecordingLeave' }, {
  group = vim.api.nvim_create_augroup('config-recording', {}),
  callback = function() vim.schedule(vim.cmd.redrawstatus) end,
})

-- Tabline at the top: open buffers as tabs (Shift-h / Shift-l move
-- between them); tab pages, when there's more than one, show at the right.
require('mini.tabline').setup({ tabpage_section = 'right' })

-- which-key: pause after a prefix (e.g. <Space>) to see what follows
vim.pack.add({ 'https://github.com/folke/which-key.nvim' })
require('which-key').setup({
  preset = 'helix', -- LazyVim's layout: a narrow column in the bottom right
  spec = {
    -- Names for the leader groups, so the popup shows "+buffer" etc.
    { '<leader>b', group = 'buffer' },
    { '<leader>c', group = 'code' },
    { '<leader>f', group = 'file/find' },
    { '<leader>g', group = 'git' },
    { '<leader>gh', group = 'hunks' },
    { '<leader>q', group = 'quit/session' },
    { '<leader>s', group = 'search' },
    { '<leader>u', group = 'ui' },
    { '<leader>w', group = 'windows' },
    { '<leader><tab>', group = 'tabs' },
    { 'gs', group = 'surround' },
    { '[', group = 'prev' },
    { ']', group = 'next' },
    { 'g', group = 'goto' },
  },
})
