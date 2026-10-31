-- nixd tweaks (merged over nvim-lspconfig's lsp/nixd.lua). There are no
-- channels here, so point it at this repo's flake: nixpkgs for package and
-- lib completion, and the Home Manager options for completing settings.
local flake = '(builtins.getFlake "' .. vim.env.HOME .. '/nix")'

return {
  settings = {
    nixd = {
      nixpkgs = { expr = 'import ' .. flake .. '.inputs.nixpkgs { }' },
      options = {
        -- Any one config will do; they all share the same options.
        home_manager = { expr = flake .. '.homeConfigurations."conix@luna".options' },
      },
    },
  },
}
