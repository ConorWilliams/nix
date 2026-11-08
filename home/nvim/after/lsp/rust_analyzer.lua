-- rust_analyzer tweaks (merged over nvim-lspconfig's lsp/rust_analyzer.lua):
-- check with clippy, pedantic lints included (as CI does).
return {
  settings = {
    ['rust-analyzer'] = {
      check = {
        command = 'clippy',
        extraArgs = { '--', '-W', 'clippy::pedantic' },
      },
    },
  },
}
