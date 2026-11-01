-- Completion with blink.cmp. Pinned to 1.x releases: a release tag lets it
-- download its prebuilt Rust fuzzy matcher (nothing to compile). It also
-- tells every language server what it supports, so no LSP glue is needed.

vim.pack.add({
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.*') },
  'https://github.com/rafamadriz/friendly-snippets', -- snippet collection blink reads
})

require('blink.cmp').setup({
  -- Tab accepts (or jumps through a snippet), as you had it. C-n/C-p or
  -- Up/Down move, C-e closes, C-space opens it or toggles the docs.
  keymap = {
    preset = 'super-tab',
    -- super-tab's Tab, plus accepting a Copilot suggestion (80_ai.lua) when
    -- there's no menu or snippet; otherwise a plain Tab.
    ['<Tab>'] = {
      function(cmp)
        if cmp.snippet_active() then return cmp.accept() end
        return cmp.select_and_accept()
      end,
      'snippet_forward',
      function() return vim.lsp.inline_completion.get() end,
      'fallback',
    },
  },
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    accept = { auto_brackets = { enabled = true } }, -- add () after functions
    menu = { draw = { treesitter = { 'lsp' } } }, -- highlight items like code
  },
  signature = { enabled = true }, -- parameter hints while typing a call
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  cmdline = {
    keymap = { preset = 'cmdline' },
    completion = { menu = { auto_show = true } },
  },
})
