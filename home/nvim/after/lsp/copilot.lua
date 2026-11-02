-- GitHub Copilot's language server (nvim-lspconfig's config, plus this).
-- Its inline suggestions and keys are in plugin/80_ai.lua.
return {
  -- Only code, only inside git repos, and never secrets (.env*, ~/.ssh):
  -- copilot is sent the whole buffer.
  filetypes = {
    'python',
    'lua',
    'nix',
    'sh',
    'bash',
    'fish',
    'c',
    'cpp',
    'rust',
    'cmake',
    'toml',
    'yaml',
    'json',
  },
  root_dir = function(bufnr, on_dir)
    local file = vim.api.nvim_buf_get_name(bufnr)
    if vim.fs.basename(file):match('^%.env') or file:match('/%.ssh/') then return end
    local root = vim.fs.root(bufnr, '.git')
    if root then on_dir(root) end
  end,
  settings = { telemetry = { telemetryLevel = 'off' } }, -- (lspconfig's: 'all')
  handlers = {
    -- The server reports problems such as not being signed in
    didChangeStatus = function(err, res)
      if not err and res.kind == 'Error' then
        vim.notify('Copilot: ' .. res.message .. ' (try :LspCopilotSignIn)', vim.log.levels.WARN)
      end
    end,
  },
}
