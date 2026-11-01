-- Git: gitsigns for changes in the gutter and hunk actions, lazygit in a
-- float, and snacks' git pickers. Keys as in LazyVim.

local gs = require('gitsigns')
local bar = { text = '▎' }
gs.setup({
  signs = { add = bar, change = bar, changedelete = bar, untracked = bar },
  signs_staged = { add = bar, change = bar, changedelete = bar },
  on_attach = function(buf)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    -- In a diff window, ]c [c move between changes; elsewhere use hunks
    local nav = function(dir, diff_key)
      return function()
        if vim.wo.diff then return vim.cmd.normal({ diff_key, bang = true }) end
        gs.nav_hunk(dir)
      end
    end
    map('n', ']h', nav('next', ']c'), 'Next hunk')
    map('n', '[h', nav('prev', '[c'), 'Prev hunk')
    map('n', ']H', function() gs.nav_hunk('last') end, 'Last hunk')
    map('n', '[H', function() gs.nav_hunk('first') end, 'First hunk')
    map({ 'n', 'x' }, '<leader>ghs', ':Gitsigns stage_hunk<cr>', 'Stage/unstage hunk')
    map({ 'n', 'x' }, '<leader>ghr', ':Gitsigns reset_hunk<cr>', 'Reset hunk')
    map('n', '<leader>ghS', gs.stage_buffer, 'Stage buffer')
    map('n', '<leader>ghR', gs.reset_buffer, 'Reset buffer')
    map('n', '<leader>ghp', gs.preview_hunk_inline, 'Preview hunk')
    map('n', '<leader>ghb', function() gs.blame_line({ full = true }) end, 'Blame line')
    map('n', '<leader>ghB', gs.blame, 'Blame buffer')
    map('n', '<leader>ghd', gs.diffthis, 'Diff against index')
    map('n', '<leader>ghD', function() gs.diffthis('~') end, 'Diff against last commit')
    map({ 'o', 'x' }, 'ih', ':<C-u>Gitsigns select_hunk<cr>', 'Hunk') -- e.g. dih, vih
  end,
})

local map = function(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc }) end

-- lazygit in a float, exactly as in the terminal: its config (home/git.nix)
-- is left alone, rather than snacks recolouring it to the colour scheme.
Snacks.config.lazygit = { configure = false }
map('<leader>gg', function() Snacks.lazygit({ cwd = Snacks.git.get_root() }) end, 'Lazygit')
map('<leader>gG', function() Snacks.lazygit() end, 'Lazygit (cwd)')

-- Pickers
local pick = Snacks.picker
map('<leader>gs', pick.git_status, 'Status')
map('<leader>gd', pick.git_diff, 'Diff (hunks)')
map('<leader>gl', pick.git_log, 'Log')
map('<leader>gf', pick.git_log_file, 'File history')
map('<leader>gb', pick.git_log_line, 'Blame line (log)')
map('<leader>gS', pick.git_stash, 'Stash')

-- Open the file on GitHub (at the cursor line or selection), or copy the URL
map('<leader>gB', function() Snacks.gitbrowse() end, 'Browse on GitHub', { 'n', 'x' })
map('<leader>gY', function()
  Snacks.gitbrowse({ open = function(url) vim.fn.setreg('+', url) end, notify = false })
end, 'Copy GitHub URL', { 'n', 'x' })
