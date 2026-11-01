-- Formatting with conform: runs the formatter listed for the filetype,
-- falling back to the language server's own formatting. Formats on save;
-- <leader>uf toggles that (globally) if a file shouldn't be touched.

vim.pack.add({ 'https://github.com/stevearc/conform.nvim' })
local conform = require('conform')

conform.setup({
  formatters_by_ft = {
    lua = { 'stylua' }, -- reads nvim/.stylua.toml
    nix = { 'nixfmt' },
    sh = { 'shfmt' },
    bash = { 'shfmt' },
    fish = { 'fish_indent' },
  },
  formatters = {
    shfmt = { prepend_args = { '-i', '2' } }, -- 2-space indent, not tabs
  },
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = function()
    if vim.g.autoformat == false then return end
    return { timeout_ms = 1000 }
  end,
})

-- Trailing whitespace goes on save in every filetype, formatter or not.
-- Separate from conform: listing a formatter for all filetypes there would
-- stop its fallback to the language server (ruff, rumdl).
vim.api.nvim_create_autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('config-trim', {}),
  callback = function(ev)
    if vim.g.autoformat == false or not vim.bo[ev.buf].modifiable then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns silent! %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- gq uses conform too
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set({ 'n', 'x' }, '<leader>cf', conform.format, { desc = 'Format' })
vim.keymap.set('n', '<leader>uf', function()
  vim.g.autoformat = vim.g.autoformat == false
  vim.notify('Format on save: ' .. (vim.g.autoformat and 'on' or 'off'))
end, { desc = 'Toggle format on save' })
