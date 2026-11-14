-- Formatting with conform: runs the formatter listed for the filetype,
-- falling back to the language server's own formatting. Formats on save;
-- <leader>uf toggles that (globally) if a file shouldn't be touched.

local conform = require('conform')

conform.setup({
  formatters_by_ft = {
    lua = { 'stylua' }, -- reads nvim/.stylua.toml
    nix = { 'nixfmt' },
    sh = { 'shfmt' },
    fish = { 'fish_indent' },
    markdown = { 'rumdl' },
  },
  -- rumdl formats code blocks (a .rumdl.toml's code-block-tools) only when
  -- given a file, not stdin, nor as a language server: conform writes a
  -- temporary one next to the buffer's.
  formatters = {
    rumdl = { args = { 'fmt', '$FILENAME' }, stdin = false },
  },
  default_format_opts = { lsp_format = 'fallback' },
  format_on_save = function()
    if vim.g.autoformat == false then return end
    return { timeout_ms = 1000 }
  end,
})

-- Trailing whitespace goes on save in every filetype, formatter or not.
-- Separate from conform: listing a formatter for all filetypes there would
-- stop its fallback to the language server (ruff).
vim.api.nvim_create_autocmd('BufWritePre', {
  group = vim.api.nvim_create_augroup('config-trim', {}),
  callback = function(ev)
    if vim.g.autoformat == false or not vim.bo[ev.buf].modifiable then return end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns silent! %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

vim.keymap.set({ 'n', 'x' }, '<leader>cf', conform.format, { desc = 'Format' })
Snacks.toggle({
  name = 'Format on save',
  get = function() return vim.g.autoformat ~= false end,
  set = function(on) vim.g.autoformat = on end,
}):map('<leader>uf')
