-- ruff: Python linting, fixes and formatting (conform falls back to it, as
-- there is no Python entry in formatters_by_ft, so the .venv ruff formats).
return {
  cmd = require('config.venv')('ruff', { 'server' }),
  on_attach = function(client, buf)
    -- Leave hover to ty, which knows the types
    client.server_capabilities.hoverProvider = false
    vim.keymap.set('n', '<leader>co', function()
      vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.organizeImports' } } })
    end, { buffer = buf, desc = 'Organize imports' })
  end,
}
