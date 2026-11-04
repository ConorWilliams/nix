-- lua_ls tweaks (merged over nvim-lspconfig's lsp/lua_ls.lua). Teach it
-- that this is Neovim Lua: LuaJIT, the vim.* API from the runtime, and the
-- plugins' own types (Snacks, MiniTabline... rather than "undefined global").
return {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = {
        checkThirdParty = false,
        library = vim.api.nvim_get_runtime_file('', true),
      },
    },
  },
}
