-- ruff: Python linting, fixes and formatting (conform falls back to it, as
-- there is no Python entry in formatters_by_ft, so the project's ruff formats).
local organize_imports = function()
  vim.lsp.buf.code_action({ apply = true, context = { only = { 'source.organizeImports' } } })
end

return {
  -- As in ty.lua: a uv workspace's top first, so one ruff serves every member
  -- (the defaults would root at each member's pyproject.toml).
  root_markers = { 'uv.lock', 'pyproject.toml', 'ruff.toml', '.ruff.toml', '.git' },
  on_attach = function(client, buf)
    -- Leave hover to ty, which knows the types
    client.server_capabilities.hoverProvider = false
    vim.keymap.set('n', '<leader>co', organize_imports, { buffer = buf, desc = 'Organize imports' })
  end,
}
