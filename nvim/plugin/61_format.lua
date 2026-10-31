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

-- gq uses conform too
vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

vim.keymap.set({ 'n', 'x' }, '<leader>cf', conform.format, { desc = 'Format' })
vim.keymap.set('n', '<leader>uf', function()
  vim.g.autoformat = vim.g.autoformat == false
  vim.notify('Format on save: ' .. (vim.g.autoformat and 'on' or 'off'))
end, { desc = 'Toggle format on save' })
