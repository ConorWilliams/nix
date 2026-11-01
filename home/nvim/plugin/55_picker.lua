-- Picker: snacks.nvim's fuzzy finder for files, grep, buffers, symbols,
-- help, ... with your old layout. snacks is a collection of modules; only
-- the picker is switched on here (bufdelete is a plain function).
-- Inside the picker: type to filter, C-j/C-k move, Enter opens, C-v/C-s
-- split, Tab multi-selects, Esc closes, ? shows all its keys.

vim.pack.add({ 'https://github.com/folke/snacks.nvim' })
require('snacks').setup({
  picker = {
    enabled = true, -- also takes over vim.ui.select (code actions, zk, ...)
    layout = {
      cycle = true,
      reverse = true, -- input at the bottom, best match next to it
      layout = { -- full screen: list, input, then a preview below
        backdrop = false,
        width = 0,
        height = 0,
        min_width = 80,
        min_height = 30,
        border = 'none',
        box = 'vertical',
        { win = 'list', border = 'rounded' },
        {
          win = 'input',
          height = 1,
          border = 'rounded',
          title = '{title} {live} {flags}',
          title_pos = 'center',
        },
        { win = 'preview', height = 0.6, border = 'none' },
      },
    },
    matcher = { frecency = true }, -- rank often/recently opened files higher
    win = { input = { keys = { ['<Esc>'] = { 'close', mode = { 'n', 'i' } } } } },
    sources = { -- show dotfiles such as .github (.git stays hidden)
      files = { hidden = true },
      grep = { hidden = true },
    },
  },
})

local pick = Snacks.picker
local map = function(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc }) end
-- The "root" variants search from the top of the git repo instead of cwd
local root = function(source)
  return function() pick[source]({ cwd = Snacks.git.get_root() }) end
end

-- Top level
map('<leader><space>', pick.files, 'Find files')
map('<leader>/', pick.grep, 'Grep')
map('<leader>,', pick.buffers, 'Buffers')
map('<leader>:', pick.command_history, 'Command history')

-- Find
map('<leader>ff', pick.files, 'Files')
map('<leader>fF', root('files'), 'Files (git root)')
map('<leader>fg', pick.git_files, 'Git files')
map('<leader>fr', pick.recent, 'Recent')
map('<leader>fR', function() pick.recent({ filter = { cwd = true } }) end, 'Recent (cwd)')
map('<leader>fb', pick.buffers, 'Buffers')
map('<leader>fc', function() pick.files({ cwd = vim.fn.stdpath('config') }) end, 'Config files')

-- Search
map('<leader>sg', pick.grep, 'Grep')
map('<leader>sG', root('grep'), 'Grep (git root)')
map('<leader>sw', pick.grep_word, 'Word or selection', { 'n', 'x' })
map('<leader>sW', root('grep_word'), 'Word or selection (git root)', { 'n', 'x' })
map('<leader>sb', pick.lines, 'Buffer lines')
map('<leader>sd', pick.diagnostics, 'Diagnostics')
map('<leader>sD', pick.diagnostics_buffer, 'Buffer diagnostics')
map('<leader>ss', pick.lsp_symbols, 'Symbols')
map('<leader>sS', pick.lsp_workspace_symbols, 'Workspace symbols')
map('<leader>sh', pick.help, 'Help pages')
map('<leader>sk', pick.keymaps, 'Keymaps')
map('<leader>sC', pick.commands, 'Commands')
map('<leader>sH', pick.highlights, 'Highlights')
map('<leader>sj', pick.jumps, 'Jumps')
map('<leader>sm', pick.marks, 'Marks')
map('<leader>sq', pick.qflist, 'Quickfix list')
map('<leader>su', pick.undo, 'Undo history')
map('<leader>sR', pick.resume, 'Resume last picker')
map('<leader>uC', pick.colorschemes, 'Colour schemes')

-- Buffers: delete without closing the window
map('<leader>bd', function() Snacks.bufdelete() end, 'Delete buffer')
map('<leader>bo', function() Snacks.bufdelete.other() end, 'Delete other buffers')
