-- Options. Only things that differ from Neovim 0.12's defaults; mostly the
-- LazyVim settings carried over. See :help '<option>' for any of them.

-- General
vim.o.undofile = true -- Persistent undo across sessions
vim.o.confirm = true -- Ask to save instead of failing on :q with changes
vim.opt.shortmess:append('W') -- No "written" message on save
vim.o.timeoutlen = 300 -- Faster key-sequence timeout
-- Every yank and delete goes to the system clipboard. Over SSH there's no
-- clipboard to reach, so yanks are sent to the local terminal as OSC 52
-- (kitty accepts it; zellij passes it on), and p pastes the last yank
-- from here: reading the clipboard back that way is mostly blocked (Cmd-V
-- still pastes the Mac's).
vim.o.clipboard = 'unnamedplus'
if vim.env.SSH_CONNECTION then
  local osc52 = require('vim.ui.clipboard.osc52')
  local last = { {}, 'v' }
  local copy = function(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype)
      last = { lines, regtype }
      send(lines)
    end
  end
  local paste = function() return last end
  vim.g.clipboard = {
    name = 'OSC 52 (copy only)',
    copy = { ['+'] = copy('+'), ['*'] = copy('*') },
    paste = { ['+'] = paste, ['*'] = paste },
  }
end

-- UI
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.signcolumn = 'yes' -- Always show, so text doesn't shift
vim.o.wrap = false
vim.o.linebreak = true -- If wrap is turned on, break at word boundaries
vim.o.breakindent = true -- ...and indent wrapped lines
vim.o.list = true -- Show tabs and trailing spaces
vim.o.listchars = 'tab:> ,trail:·,nbsp:␣,extends:…,precedes:…'
vim.o.fillchars = 'eob: ' -- No ~ on empty lines past the end of the buffer
vim.o.sidescrolloff = 8
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.laststatus = 3 -- One global statusline
vim.o.showmode = false -- The statusline shows the mode
vim.o.winborder = 'rounded' -- Borders on floating windows (hover, etc.)
vim.o.mousescroll = 'ver:1,hor:2' -- Touchpad/wheel: 1 line per step (smoother than 3)

-- Editing
vim.o.expandtab = true
vim.o.shiftwidth = 2 -- Overridden per language by ftplugins/editorconfig
vim.o.tabstop = 2
vim.o.shiftround = true -- Round indents to a multiple of shiftwidth
vim.o.virtualedit = 'block' -- Visual block can go past line ends
vim.o.ignorecase = true -- Case-insensitive search...
vim.o.smartcase = true -- ...unless the pattern has capitals
vim.o.inccommand = 'split' -- Live preview of :s substitutions
-- LazyVim's: continue comments on Enter and o/O (r, o), even where the
-- ftplugin doesn't (e.g. nix); ftplugins can still adjust it per language
vim.o.formatoptions = 'jcroqlnt'
