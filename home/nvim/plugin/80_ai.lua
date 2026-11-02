-- GitHub Copilot via Neovim 0.12's built-in inline completion: no plugin,
-- just the copilot language server (see home/neovim.nix; enabled in
-- 60_lsp.lua, config in after/lsp/copilot.lua). Suggestions show as grey
-- ghost text.
-- Right arrow accepts one (like fish's autosuggestions), so Tab stays with
-- the completion menu; Alt-] / Alt-[ cycle alternatives.
-- First time: :LspCopilotSignIn.
vim.lsp.inline_completion.enable()

local cycle = function(count)
  return function() vim.lsp.inline_completion.select({ count = count }) end
end
vim.keymap.set('i', '<M-]>', cycle(1), { desc = 'Next Copilot suggestion' })
vim.keymap.set('i', '<M-[>', cycle(-1), { desc = 'Prev Copilot suggestion' })

-- Right arrow: take the suggestion if one is showing, else move right
vim.keymap.set('i', '<Right>', function()
  if not vim.lsp.inline_completion.get() then return '<Right>' end
end, { expr = true, desc = 'Accept Copilot suggestion (or move right)' })
