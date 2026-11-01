-- lua_ls tweaks (merged over nvim-lspconfig's lsp/lua_ls.lua). Teach it
-- that this is Neovim Lua: LuaJIT, and the vim.* API from the runtime.
return {
  settings = {
    Lua = {
      runtime = { version = 'LuaJIT' },
      workspace = {
        checkThirdParty = false,
        library = { vim.env.VIMRUNTIME },
      },
    },
  },
}
