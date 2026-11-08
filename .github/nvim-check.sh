#!/usr/bin/env bash
# CI's Neovim check, for one Home Manager config (default: conix):
#   nix develop -c .github/nvim-check.sh [config]
# Builds the config's home files (which builds the Zellij plugins too), starts
# its Neovim headless and fails on any startup error, then runs lua_ls over
# home/nvim with the settings and runtime files the editor gives it.
set -euo pipefail

config=${1:-conix}
cfg=".#homeConfigurations.\"${config}\".config"
home_files=$(nix build --no-link --print-out-paths "${cfg}.home-files")
nvim=$(nix build --no-link --print-out-paths "${cfg}.programs.neovim.finalPackage")/bin/nvim

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
# The plugins as the switch would install them. The config itself is this
# checkout's: the home files link ~/.config/nvim to ~/nix/home/nvim, which
# needn't exist (CI's checkout is elsewhere).
mkdir -p "${tmp}/config"
ln -s "${PWD}/home/nvim" "${tmp}/config/nvim"
export XDG_CONFIG_HOME=${tmp}/config XDG_DATA_HOME=${home_files}/.local/share
export XDG_STATE_HOME=${tmp}/state XDG_CACHE_HOME=${tmp}/cache

# Fails, too, if the config didn't load.
"${nvim}" --headless -i NONE \
  +'lua if not vim.lsp.config.lua_ls.settings.Lua.workspace then error("config not loaded") end' \
  +qa 2>"${tmp}/errors"
if [[ -s ${tmp}/errors ]]; then
  echo "Neovim reported errors at startup:"
  cat "${tmp}/errors"
  exit 1
fi
echo "Neovim starts cleanly."

# lua_ls's settings as the editor resolves them (after/lsp/lua_ls.lua merged
# over nvim-lspconfig's), runtime files included.
"${nvim}" --headless -i NONE -c "lua
  local settings = vim.lsp.config.lua_ls.settings.Lua
  local f = assert(io.open('${tmp}/luarc.json', 'w'))
  f:write(vim.json.encode(settings))
  f:close()
  io.stdout:write(#settings.workspace.library .. ' library folders\n')" +qa
if ! grep -q '"library":\["' "${tmp}/luarc.json"; then
  echo "lua_ls's settings have no library:"
  cat "${tmp}/luarc.json"
  exit 1
fi
if ! lua-language-server --check="${PWD}/home/nvim" --configpath="${tmp}/luarc.json" \
  --checklevel=Hint --check_format=pretty --logpath="${tmp}/lua_ls"; then
  echo "lua_ls's log:"
  tail -n 40 "${tmp}"/lua_ls/*.log
  exit 1
fi
