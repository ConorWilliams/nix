-- Git: gitsigns for changes in the gutter and hunk jumps, lazygit in a
-- float, and snacks' log picker for blame. Keys as in LazyVim.

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
    map({ 'o', 'x' }, 'ih', ':<C-u>Gitsigns select_hunk<cr>', 'Hunk') -- e.g. dih, vih
  end,
})

local map = function(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc }) end

-- lazygit in a float, exactly as in the terminal: its config (home/git.nix)
-- is left alone, rather than snacks recolouring it to the colour scheme.
-- The float fills the whole screen, without a border (snacks' is 90%).
Snacks.config.lazygit = { configure = false, win = { width = 0, height = 0, border = 'none' } }

-- Switching worktree in lazygit moves nvim too: on quit, lazygit writes the
-- folder it ended in to LAZYGIT_NEW_DIR_FILE. If that's another worktree,
-- nvim saves this folder's session, closes its buffers, changes into the
-- worktree and restores that one's session (persistence, 85_start.lua), or
-- shows the start screen if it has none.
local new_dir_file = vim.fn.tempname()
local switch_worktree = function(dir)
  if #vim.tbl_filter(function(b) return vim.bo[b].modified end, vim.api.nvim_list_bufs()) > 0 then
    local choice =
      vim.fn.confirm('Unsaved changes. Switch worktree?', '&Save all and switch\n&Stay')
    if choice ~= 1 then return end
    vim.cmd('wall')
  end
  -- Saved as on exit (persistence's own VimLeavePre autocmd), so not with no
  -- files open: the start screen would replace a saved session with an
  -- empty one.
  local persistence = require('persistence')
  if persistence.active() then
    vim.api.nvim_exec_autocmds('VimLeavePre', { group = 'persistence' })
  end
  vim.cmd('silent! %argdelete') -- (sessions save it: `nvim file` would follow along)
  -- ! so a terminal with a running job can't stop the switch halfway (E89,
  -- as in a bare nvim); unsaved files were dealt with above.
  vim.cmd('silent %bwipeout!')
  vim.cmd.cd(dir)
  persistence.load()
  local restored = vim.tbl_filter(
    function(b) return vim.bo[b].buflisted and vim.api.nvim_buf_get_name(b) ~= '' end,
    vim.api.nvim_list_bufs()
  )
  if #restored == 0 then
    Snacks.dashboard.open({
      buf = vim.api.nvim_get_current_buf(),
      win = vim.api.nvim_get_current_win(),
    })
  end
  vim.notify('Worktree: ' .. vim.fn.fnamemodify(dir, ':~'))
end
local lazygit = function(cwd)
  local from = Snacks.git.get_root(cwd)
  vim.fn.delete(new_dir_file)
  Snacks.lazygit({
    cwd = cwd,
    env = { LAZYGIT_NEW_DIR_FILE = new_dir_file },
    win = {
      -- (also runs when the float is only hidden: then there's no file yet)
      on_close = function()
        local ok, lines = pcall(vim.fn.readfile, new_dir_file)
        local dir = ok and lines[1]
        if dir and Snacks.git.get_root(dir) ~= from then
          vim.schedule(function() switch_worktree(dir) end)
        end
      end,
    },
  })
end
-- The current file's repo. Not the scratch buffer's: its file sits under
-- ~/.local/share, so that would be the home folder's repo, if any.
local file_repo = function() return not vim.b.scratch and Snacks.git.get_root() or nil end
-- Or else the folder's (help etc. aren't in a repo: with no repo to
-- compare, quitting would always look like a worktree switch)
map('<leader>g', function()
  lazygit(file_repo() or Snacks.git.get_root(vim.fn.getcwd()))
end, 'Lazygit')
map('<leader>B', function()
  if not file_repo() then
    return vim.notify('Not in a git repo', vim.log.levels.WARN)
  end
  Snacks.picker.git_log_line()
end, 'Blame line (log)')
