-- GitHub Copilot via Neovim 0.12's built-in inline completion: no plugin,
-- just the copilot language server (see home/neovim.nix) and
-- nvim-lspconfig's config for it. Suggestions show as grey ghost text.
-- Right arrow accepts one (like fish's autosuggestions), so Tab stays with
-- the completion menu; Alt-] / Alt-[ cycle alternatives.
-- First time: :LspCopilotSignIn.
if vim.fn.executable('copilot-language-server') == 0 then return end

vim.lsp.config('copilot', {
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
  handlers = {
    -- The server reports problems such as not being signed in
    didChangeStatus = function(err, res)
      if not err and res.kind == 'Error' then
        vim.notify('Copilot: ' .. res.message .. ' (try :LspCopilotSignIn)', vim.log.levels.WARN)
      end
    end,
  },
})
vim.lsp.enable('copilot')
vim.lsp.inline_completion.enable()

local cycle = function(count)
  return function() vim.lsp.inline_completion.select({ count = count }) end
end
vim.keymap.set({ 'i', 'n' }, '<M-]>', cycle(1), { desc = 'Next Copilot suggestion' })
vim.keymap.set({ 'i', 'n' }, '<M-[>', cycle(-1), { desc = 'Prev Copilot suggestion' })

-- Right arrow: take the suggestion if one is showing, else move right
vim.keymap.set('i', '<Right>', function()
  if not vim.lsp.inline_completion.get() then return '<Right>' end
end, { expr = true, desc = 'Accept Copilot suggestion (or move right)' })
