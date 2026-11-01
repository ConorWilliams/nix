-- Keymaps that need no plugins: the LazyVim defaults worth keeping.
-- Plugin keymaps live next to their plugin. 0.11+ already provides [b ]b
-- (buffers), [q ]q (quickfix), [d ]d (diagnostics) and gc (comments).

local map = vim.keymap.set

-- Move by screen line when wrapped, unless given a count (5j)
map({ 'n', 'x' }, 'j', "v:count == 0 ? 'gj' : 'j'", { expr = true })
map({ 'n', 'x' }, 'k', "v:count == 0 ? 'gk' : 'k'", { expr = true })

-- Windows
map('n', '<C-h>', '<C-w>h', { desc = 'Go to left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Go to lower window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Go to upper window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Go to right window' })
map('n', '<C-Up>', '<cmd>resize +2<cr>', { desc = 'Taller window' })
map('n', '<C-Down>', '<cmd>resize -2<cr>', { desc = 'Shorter window' })
map('n', '<C-Left>', '<cmd>vertical resize -2<cr>', { desc = 'Narrower window' })
map('n', '<C-Right>', '<cmd>vertical resize +2<cr>', { desc = 'Wider window' })
map('n', '<leader>-', '<C-w>s', { desc = 'Split below' })
map('n', '<leader>|', '<C-w>v', { desc = 'Split right' })
map('n', '<leader>wd', '<C-w>c', { desc = 'Delete window' })

-- Buffers
map('n', '<S-h>', '<cmd>bprevious<cr>', { desc = 'Prev buffer' })
map('n', '<S-l>', '<cmd>bnext<cr>', { desc = 'Next buffer' })
map('n', '<leader>bb', '<cmd>e #<cr>', { desc = 'Other buffer' })
map('n', '<leader>bD', '<cmd>bd<cr>', { desc = 'Delete buffer and window' })
map('n', '<leader>fn', '<cmd>enew<cr>', { desc = 'New file' })

-- Move lines with Alt-j/k
map('n', '<A-j>', "<cmd>execute 'move .+' . v:count1<cr>==", { desc = 'Move down' })
map('n', '<A-k>', "<cmd>execute 'move .-' . (v:count1 + 1)<cr>==", { desc = 'Move up' })
map('i', '<A-j>', '<esc><cmd>m .+1<cr>==gi', { desc = 'Move down' })
map('i', '<A-k>', '<esc><cmd>m .-2<cr>==gi', { desc = 'Move up' })
map('x', '<A-j>', ":<C-u>execute \"'<,'>move '>+\" . v:count1<cr>gv=gv", { desc = 'Move down' })
map('x', '<A-k>', ":<C-u>execute \"'<,'>move '<-\" . (v:count1 + 1)<cr>gv=gv", { desc = 'Move up' })

-- Editing
map({ 'i', 'n', 'x', 's' }, '<C-s>', '<cmd>w<cr><esc>', { desc = 'Save file' })
map('n', '<esc>', '<cmd>nohlsearch<cr><esc>', { desc = 'Clear search highlight' })
map('x', '<', '<gv') -- Keep the selection after indenting
map('x', '>', '>gv')
for _, c in ipairs({ ',', '.', ';' }) do
  map('i', c, c .. '<C-g>u') -- Undo breakpoints, so u doesn't undo a whole paragraph
end
map('n', 'gco', 'o<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', { desc = 'Add comment below' })
map('n', 'gcO', 'O<esc>Vcx<esc><cmd>normal gcc<cr>fxa<bs>', { desc = 'Add comment above' })

-- n always searches forward and N backward, whether the search began with / or ?
map({ 'n', 'x', 'o' }, 'n', "'Nn'[v:searchforward]", { expr = true, desc = 'Next match' })
map({ 'n', 'x', 'o' }, 'N', "'nN'[v:searchforward]", { expr = true, desc = 'Prev match' })

-- Diagnostics by severity ([d ]d for all of them are built in)
local jump = function(count, severity)
  return function() vim.diagnostic.jump({ count = count, severity = severity, float = true }) end
end
map('n', ']e', jump(1, 'ERROR'), { desc = 'Next error' })
map('n', '[e', jump(-1, 'ERROR'), { desc = 'Prev error' })
map('n', ']w', jump(1, 'WARN'), { desc = 'Next warning' })
map('n', '[w', jump(-1, 'WARN'), { desc = 'Prev warning' })
map('n', '<leader>cd', vim.diagnostic.open_float, { desc = 'Line diagnostics' })

-- Tabs
map('n', '<leader><tab><tab>', '<cmd>tabnew<cr>', { desc = 'New tab' })
map('n', '<leader><tab>]', '<cmd>tabnext<cr>', { desc = 'Next tab' })
map('n', '<leader><tab>[', '<cmd>tabprevious<cr>', { desc = 'Prev tab' })
map('n', '<leader><tab>d', '<cmd>tabclose<cr>', { desc = 'Close tab' })
map('n', '<leader><tab>o', '<cmd>tabonly<cr>', { desc = 'Close other tabs' })

-- Misc
map('n', '<leader>qq', '<cmd>qa<cr>', { desc = 'Quit all' })
map('n', '<leader>ui', vim.show_pos, { desc = 'Inspect highlight under cursor' })
map('n', '<leader>uI', '<cmd>InspectTree<cr>', { desc = 'Inspect syntax tree' })
