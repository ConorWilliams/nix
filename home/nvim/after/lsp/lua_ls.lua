-- lua_ls tweaks (merged over nvim-lspconfig's lsp/lua_ls.lua). Teach it
-- that this is Neovim Lua: LuaJIT, the vim.* API from the runtime, and the
-- plugins' own types (Snacks, MiniTabline... rather than "undefined global").
return {
  settings = {
    Lua = {
      -- Modules live under lua/ in each runtime dir. Strict, or
      -- require('zk') also matches nvim-lspconfig's lsp/zk.lua.
      runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' }, pathStrict = true },
      workspace = {
        checkThirdParty = false,
        library = vim.api.nvim_get_runtime_file('', true),
      },
    },
  },
}
