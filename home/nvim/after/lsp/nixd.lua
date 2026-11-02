-- nixd tweaks (merged over nvim-lspconfig's lsp/nixd.lua). There are no
-- channels here, so point it at this repo's flake (wherever NH_FLAKE says
-- it is): nixpkgs for package and lib completion, and the Home Manager
-- options for completing settings.
local flake = '(builtins.getFlake "'
  .. assert(vim.env.NH_FLAKE, 'nixd: NH_FLAKE is unset (Home Manager sets it; log in again?)')
  .. '")'

return {
  settings = {
    nixd = {
      nixpkgs = { expr = 'import ' .. flake .. '.inputs.nixpkgs { }' },
      options = {
        -- Any one config will do (they share the same options): the first.
        home_manager = {
          expr = '(builtins.head (builtins.attrValues ' .. flake .. '.homeConfigurations)).options',
        },
      },
    },
  },
}
