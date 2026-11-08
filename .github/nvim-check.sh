#!/usr/bin/env bash
# CI's Neovim check, for one Home Manager config (default: conix):
#   .github/nvim-check.sh [config]
# Builds the config's home files (which builds the Zellij plugins too), starts
# its Neovim headless and fails on any startup error, then runs lua_ls over
# home/nvim with the settings and runtime files the editor gives it.
set -euo pipefail

config=${1:-conix}
cfg=".#homeConfigurations.\"${config}\".config"
home_files=$(nix build --no-link --print-out-paths "${cfg}.home-files")
nvim=$(nix build --no-link --print-out-paths "${cfg}.programs.neovim.finalPackage")/bin/nvim
lua_ls=$(nix build --no-link --print-out-paths --inputs-from . nixpkgs#lua-language-server)/bin/lua-language-server

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
# The config and plugins as the switch would install them.
export XDG_CONFIG_HOME=${home_files}/.config XDG_DATA_HOME=${home_files}/.local/share
export XDG_STATE_HOME=${tmp}/state XDG_CACHE_HOME=${tmp}/cache

"${nvim}" --headless -i NONE +qa 2>"${tmp}/errors"
if [[ -s ${tmp}/errors ]]; then
  echo "Neovim reported errors at startup:"
  cat "${tmp}/errors"
  exit 1
fi
echo "Neovim starts cleanly."

# lua_ls's settings as the editor resolves them (after/lsp/lua_ls.lua merged
# over nvim-lspconfig's), runtime files included.
"${nvim}" --headless -i NONE \
  -c "lua io.open('${tmp}/luarc.json', 'w'):write(vim.json.encode(vim.lsp.config.lua_ls.settings.Lua))" +qa
"${lua_ls}" --check=home/nvim --configpath="${tmp}/luarc.json" --checklevel=Hint \
  --check_format=pretty --logpath="${tmp}/lua_ls"
