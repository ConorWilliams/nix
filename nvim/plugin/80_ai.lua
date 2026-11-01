-- GitHub Copilot via Neovim 0.12's built-in inline completion: no plugin,
-- just the copilot language server (see home/server/neovim.nix) and
-- nvim-lspconfig's config for it. Suggestions show as grey ghost text.
-- Tab accepts one (when the completion menu is closed; 65_completion.lua),
-- Alt-] / Alt-[ cycle alternatives. First time: :LspCopilotSignIn.
if vim.fn.executable('copilot-language-server') == 0 then return end

vim.lsp.config('copilot', {
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
