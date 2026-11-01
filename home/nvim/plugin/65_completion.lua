-- Completion with blink.cmp. Pinned to 1.x releases: a release tag lets it
-- download its prebuilt Rust fuzzy matcher (nothing to compile). It also
-- tells every language server what it supports, so no LSP glue is needed.

vim.pack.add({
  { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.*') },
  'https://github.com/rafamadriz/friendly-snippets', -- snippet collection blink reads
})

require('blink.cmp').setup({
  -- Tab accepts (or jumps through a snippet), as in the old config. C-n/C-p or
  -- Up/Down move, C-e closes, C-space opens it or toggles the docs.
  keymap = { preset = 'super-tab' }, -- (Copilot has its own key: 80_ai.lua)
  completion = {
    documentation = { auto_show = true, auto_show_delay_ms = 200 },
    accept = { auto_brackets = { enabled = true } }, -- add () after functions
    menu = { draw = { treesitter = { 'lsp' } } }, -- highlight items like code
  },
  signature = { enabled = true }, -- parameter hints while typing a call
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  -- Completion in the : command line, like insert mode: the first match is
  -- selected and Tab accepts it. Up / Down move through the menu (and still
  -- walk the command history when no menu is open), C-e closes it.
  cmdline = {
    keymap = {
      preset = 'cmdline',
      ['<Tab>'] = { 'select_and_accept', 'show' },
      ['<Down>'] = { 'select_next', 'fallback' },
      ['<Up>'] = { 'select_prev', 'fallback' },
      ['<Right>'] = false, -- arrows left / right move the cursor, as usual
      ['<Left>'] = false,
    },
    completion = {
      list = { selection = { preselect = true } },
      -- pop up by itself for : commands, not for / searches
      menu = { auto_show = function() return vim.fn.getcmdtype() == ':' end },
      ghost_text = { enabled = true }, -- the top match shown faintly
    },
  },
})
