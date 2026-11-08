-- Sessions and the start screen.

-- persistence: on exit, saves the open buffers, windows and tabs as a
-- session for this folder (and git branch). Nothing is restored unless
-- asked for, from the start screen.
local persistence = require('persistence')
persistence.setup()
-- Not terminals (restoring would re-run e.g. a hidden lazygit) or empty
-- windows; as in LazyVim.
vim.opt.sessionoptions:remove({ 'terminal', 'blank' })

-- Start screen (snacks dashboard, LazyVim's look): shown when nvim starts
-- without files. Snacks reads this at startup, so it can be set here rather
-- than in the setup() call in 55_picker.lua.
-- The header is Neovim's own logo, from its intro screen
-- (src/nvim/version.c), coloured the same way: Special up to the first
-- diagonal, String from there on.
local logo_line = function(left, right)
  return { align = 'center', text = { { left, hl = 'Special' }, { right, hl = 'String' } } }
end
Snacks.config.dashboard = {
  enabled = true,
  sections = {
    logo_line('│ ', '╲ ││'),
    logo_line('││', '╲╲││'),
    logo_line('││ ', '╲ │'),
    { padding = 1 },
    { section = 'keys', gap = 1 },
  },
  preset = {
    keys = {
      {
        icon = vim.fn.nr2char(0xf002) .. ' ',
        key = 'f',
        desc = 'Find File',
        action = function() Snacks.picker.files() end,
      },
      {
        icon = vim.fn.nr2char(0xf1da) .. ' ',
        key = 's',
        desc = 'Restore Session',
        action = persistence.load,
        -- only when this folder has a saved session (for this branch, or
        -- the folder's own, which load() falls back to); checked each time
        -- the screen opens, as a worktree switch changes the folder
        enabled = function()
          return vim.fn.filereadable(persistence.current()) == 1
            or vim.fn.filereadable(persistence.current({ branch = false })) == 1
        end,
      },
      { icon = vim.fn.nr2char(0xf426) .. ' ', key = 'q', desc = 'Quit', action = ':qa' },
    },
  },
}
