-- Language servers. The servers themselves come from Nix (extraPackages in
-- home/neovim.nix). nvim-lspconfig only supplies default configs (command,
-- filetypes, root markers) as lsp/<name>.lua files; per-server tweaks
-- live in after/lsp/<name>.lua and are merged on top.

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
    -- Not for copilot, which only does inline suggestions (80_ai.lua)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client or client.name == 'copilot' then return end
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
    map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, 'Code action')
    map('n', '<leader>cr', vim.lsp.buf.rename, 'Rename')
  end,
})

-- How diagnostics are shown
vim.diagnostic.config({
  severity_sort = true, -- Errors above warnings when several share a line
  virtual_text = { spacing = 4, source = 'if_many', prefix = '●' },
  float = { source = 'if_many' },
  -- Gutter icons (nerd font), as codepoints so they survive any editor
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = vim.fn.nr2char(0xf057),
      [vim.diagnostic.severity.WARN] = vim.fn.nr2char(0xf071),
      [vim.diagnostic.severity.HINT] = vim.fn.nr2char(0xf0eb),
      [vim.diagnostic.severity.INFO] = vim.fn.nr2char(0xf05a),
    },
  },
  -- Every jump ([d ]d, ]e [e ...) shows the diagnostic in a float
  jump = {
    on_jump = function(diagnostic, bufnr)
      if diagnostic then
        vim.diagnostic.open_float({ bufnr = bufnr, scope = 'cursor', focus = false })
      end
    end,
  },
})
