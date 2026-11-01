-- Language servers. The servers themselves come from Nix (extraPackages in
-- home/neovim.nix). nvim-lspconfig only supplies default configs (command,
-- filetypes, root markers) as lsp/<name>.lua files; per-server tweaks
-- live in after/lsp/<name>.lua and are merged on top.

vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })

vim.lsp.enable({
  'lua_ls', -- lua-language-server
  'nixd',
  'bashls', -- bash-language-server (sh and bash)
  'ty', -- Python types
  'ruff', -- Python lint and format
  'marksman', -- Markdown links, headings, references
  'rumdl', -- Markdown lint and format
})

-- Keys for buffers with a server attached, as in LazyVim. Built in already:
-- K hover, [d ]d diagnostics, gO document symbols.
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('config-lsp', {}),
  callback = function(ev)
    local map = function(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = ev.buf, desc = desc, nowait = true })
    end
    -- Through the picker (55_picker.lua): jumps straight there if there's
    -- only one result, else lists them with a preview.
    map('n', 'gd', Snacks.picker.lsp_definitions, 'Goto definition')
    map('n', 'gD', Snacks.picker.lsp_declarations, 'Goto declaration')
    map('n', 'gr', Snacks.picker.lsp_references, 'References') -- nowait: skips the built-in gr* keys
    map('n', 'gI', Snacks.picker.lsp_implementations, 'Goto implementation')
    map('n', 'gy', Snacks.picker.lsp_type_definitions, 'Goto type definition')
    map('n', 'gK', vim.lsp.buf.signature_help, 'Signature help')
    map('i', '<C-k>', vim.lsp.buf.signature_help, 'Signature help')
    map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('n', '<leader>cr', vim.lsp.buf.rename, 'Rename')
  end,
})

-- How diagnostics are shown
vim.diagnostic.config({
  severity_sort = true, -- Errors above warnings when several share a line
  virtual_text = { spacing = 4, source = 'if_many', prefix = '●' },
  float = { source = 'if_many' },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = ' ',
      [vim.diagnostic.severity.WARN] = ' ',
      [vim.diagnostic.severity.HINT] = ' ',
      [vim.diagnostic.severity.INFO] = ' ',
    },
  },
})
