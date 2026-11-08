-- Picker: snacks.nvim's fuzzy finder for files, grep, buffers, symbols,
-- help, ... and its file explorer, with the custom full-screen layout. snacks is a
-- collection of modules; the picker, explorer, smooth scrolling, bigfile,
-- words and indent guides are switched on here (bufdelete is a plain function), the
-- start screen in 85_start.lua and lazygit's float in 75_git.lua.
-- Inside the picker: type to filter, C-j/C-k move, Enter opens, C-v/C-s
-- split, Tab multi-selects, Esc closes, ? shows all its keys.

-- Hidden files, for files, grep and the explorer alike: dotfiles (.env,
-- .gitignore, ...) are shown, but of the dot-folders only these, so .venv,
-- .cache, .git etc. stay out.
local dot_folders = { ['.claude'] = true, ['.github'] = true }
local hide_dot_folders = function(item, ctx)
  -- Judge the path below the folder being searched, so ~/.config/...
  -- doesn't hide everything. (files/grep give paths relative to the
  -- picker's folder, the explorer absolute ones; util.path makes both
  -- absolute, as relpath would resolve a relative one from nvim's cwd.)
  local abs = Snacks.picker.util.path(item)
  local path = abs and vim.fs.relpath(ctx.filter.cwd, abs) or item.file
  local parts = vim.split(path, '/', { plain = true })
  local last = item.dir and #parts or #parts - 1 -- folders only, not the file name
  for i = 1, last do
    local part = parts[i]
    if part:sub(1, 1) == '.' and part ~= '.' and part ~= '..' and not dot_folders[part] then
      return false -- drop it
    end
  end
end

-- Two full-screen layouts. Pickers use the tall one; the explorer picks
-- by the window's shape each time it opens: terminal cells are about twice
-- as tall as wide, so more than twice as many columns as lines means a
-- landscape window.
local layouts = {
  -- Landscape: search and results on the left, preview on the right.
  wide = {
    layout = {
      backdrop = false,
      width = 0,
      height = 0,
      border = 'none',
      box = 'horizontal',
      {
        box = 'vertical',
        width = 0.4,
        {
          win = 'input',
          height = 1,
          border = 'rounded',
          title = '{title} {live} {flags}',
          title_pos = 'center',
        },
        { win = 'list', border = 'rounded' },
      },
      { win = 'preview', border = 'rounded', title = '{preview}' },
    },
  },
  -- Portrait: results, the search box under them (best match next to it),
  -- then a preview below.
  tall = {
    reverse = true,
    layout = {
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
      -- A top border, though it's never seen: snacks overlaps each window's
      -- top row with the bottom border above, which hid line 1 of every
      -- preview.
      { win = 'preview', height = 0.6, border = 'top' },
    },
  },
}
local shape = function() return vim.o.columns > 2 * vim.o.lines and 'wide' or 'tall' end

require('snacks').setup({
  toggle = { wk_desc = '' }, -- which-key: just the name; the icon shows on/off
  explorer = {}, -- also opens directories (`nvim .`) instead of netrw
  scroll = {}, -- animated C-d, C-u, zz, jumps (as in LazyVim; not the mouse)
  -- Files over 1.5 MB or with very long lines (minified JSON, logs) open
  -- plain: no treesitter, language servers or completion. :set ft=... to
  -- get them back.
  bigfile = {},
  -- Other uses of the name under the cursor are highlighted (via the
  -- language server), as in LazyVim.
  words = {},
  -- Faint guides at each indent level, the current block's highlighted, as
  -- in LazyVim.
  indent = {},
  picker = { -- also takes over vim.ui.select (code actions, zk, ...)
    layouts = layouts,
    layout = { preset = 'tall' }, -- the explorer picks by shape (below)
    matcher = { frecency = true }, -- rank often/recently opened files higher
    win = { input = { keys = { ['<Esc>'] = { 'close', mode = { 'n', 'i' } } } } },
    sources = {
      files = { hidden = true, transform = hide_dot_folders },
      grep = { hidden = true, transform = hide_dot_folders },
      -- Explorer: full screen with a preview (not the sidebar), closes once
      -- a file is opened. a add, d delete (to trash), r rename (tells the
      -- language servers, so imports follow), c copy, m move, y/p yank and
      -- paste, h/l close/open a folder.
      explorer = {
        hidden = true,
        transform = hide_dot_folders,
        auto_close = true,
        -- preview = true undoes the source's preview = false (Snacks types
        -- only allow "main").
        ---@diagnostic disable-next-line: assign-type-mismatch
        layout = { preset = shape, preview = true, reverse = false }, -- tree top-down
      },
    },
  },
})

local pick = Snacks.picker
local map = function(lhs, rhs, desc, mode) vim.keymap.set(mode or 'n', lhs, rhs, { desc = desc }) end

-- Find (<leader><space>, find files, is in 70_markdown.lua: notes in a notebook)
map('<leader>f', pick.files, 'Files')
map('<leader>,', pick.buffers, 'Buffers')

-- Search
map('<leader>sg', pick.grep, 'Grep')
map('<leader>sw', pick.grep_word, 'Word or selection', { 'n', 'x' })
map('<leader>sb', pick.lines, 'Buffer lines')
map('<leader>ss', pick.lsp_symbols, 'Symbols')
map('<leader>sS', pick.lsp_workspace_symbols, 'Workspace symbols')
map('<leader>sk', pick.keymaps, 'Keymaps')
map('<leader>sC', pick.commands, 'Commands')
map('<leader>sq', pick.qflist, 'Quickfix list')
map('<leader>su', pick.undo, 'Undo history')
map('<leader>sR', pick.resume, 'Resume last picker')
map('<leader>sy', function() pick.pick('yanky') end, 'Yank history', { 'n', 'x' })

-- Explorer
map('<leader>e', function() Snacks.explorer() end, 'Explorer')

-- Buffers: a scratch buffer, and delete without closing the window.
-- The scratch buffer: one markdown file per git repo nvim is working in
-- (or per folder outside one), whatever file is open, kept between
-- sessions and named after that path. An ordinary buffer: "Scratch" in the
-- tabline (30_ui.lua), saved whenever it's left.
local scratch_dir = vim.fn.stdpath('data') .. '/scratch'
map('<leader>bs', function()
  -- nvim's own folder, which a worktree switch (75_git.lua) changes; not a
  -- window's or tab's (:lcd, :tcd)
  local cwd = vim.fn.getcwd(-1, -1)
  local root = Snacks.git.get_root(cwd) or cwd
  vim.fn.mkdir(scratch_dir, 'p')
  local file = scratch_dir .. '/' .. root:gsub('/', '%%') .. '.md'
  vim.cmd.edit(vim.fn.fnameescape(file))
end, 'Scratch buffer')
local scratch_group = vim.api.nvim_create_augroup('config-scratch', {})
-- (also when a session brings it back) for the tabline: the name of its
-- repo or folder, the last part of the file name
vim.api.nvim_create_autocmd({ 'BufNewFile', 'BufRead' }, {
  group = scratch_group,
  pattern = scratch_dir .. '/*',
  callback = function(ev)
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ev.buf), ':t:r')
    vim.b[ev.buf].scratch = name:match('[^%%]*$')
  end,
})
vim.api.nvim_create_autocmd('BufHidden', {
  group = scratch_group,
  pattern = scratch_dir .. '/*',
  callback = function(ev)
    -- only when changed (:update would also create a missing file); silent,
    -- but a failed write still shows its error
    if not vim.bo[ev.buf].modified then return end
    vim.api.nvim_buf_call(ev.buf, function() vim.cmd('silent write') end)
  end,
})
map('<leader>bd', function() Snacks.bufdelete() end, 'Delete buffer')
map('<leader>bo', function() Snacks.bufdelete.other() end, 'Delete other buffers')
map('<leader>ba', function() Snacks.bufdelete.all() end, 'Delete all buffers')
