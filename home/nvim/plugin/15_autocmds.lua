-- Small automatic behaviours, from LazyVim's autocmds.

local group = vim.api.nvim_create_augroup('config-autocmds', {})
local autocmd = function(event, opts)
  vim.api.nvim_create_autocmd(event, vim.tbl_extend('force', { group = group }, opts))
end

-- Briefly highlight yanked text
autocmd('TextYankPost', { callback = function() vim.hl.on_yank() end })

-- Reopening a file puts the cursor back where it was (the " mark)
autocmd('BufReadPost', {
  callback = function(ev)
    if vim.bo[ev.buf].filetype == 'gitcommit' then return end -- new message each time
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- q closes help, quickfix and blame windows (man and checkhealth map q
-- themselves, more carefully)
autocmd('FileType', {
  pattern = { 'help', 'qf', 'gitsigns-blame' },
  callback = function(ev)
    vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = ev.buf, desc = 'Close window' })
  end,
})
