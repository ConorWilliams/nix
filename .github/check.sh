#!/usr/bin/env bash
# Every CI check, runnable locally (CI calls this too):
#   .github/check.sh              all of them
#   .github/check.sh lint rust    just those groups (check, lint, rust, nvim)
# Runs in the flake's dev shell (entering it if needed), keeps going after a
# failure, and ends with a summary. The secret scan is CI-only.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "${root}"
# With CHECK_GC_ROOTS (CI sets it), what's built is kept there as GC roots,
# so the Nix store cache's garbage collection keeps it.
# keep FLAG NAME [DEFAULT]: kept is FLAG and the root's path, else DEFAULT.
keep() {
  kept=("${@:3}")
  if [[ -n ${CHECK_GC_ROOTS:-} ]]; then
    mkdir -p "${CHECK_GC_ROOTS}"
    kept=("$1" "${CHECK_GC_ROOTS}/$2")
  fi
}
if [[ -z ${CHECK_SH_IN_DEV_SHELL:-} ]]; then
  keep --profile dev-shell
  CHECK_SH_IN_DEV_SHELL=1 exec nix develop "${kept[@]}" "${root}" -c "$0" "$@"
fi

failed=()
nvim_tmp=
trap 'if [[ -n ${nvim_tmp} ]]; then rm -rf "${nvim_tmp}"; fi' EXIT
step() {
  printf '\n\033[1m==> %s\033[0m\n' "$1"
  if ! "${@:2}"; then failed+=("$1"); fi
}
each() { git ls-files -z "$1" | xargs -0 "${@:2}"; }

check() {
  # Every config evaluates, for every system (the Mac included).
  step "flake check" nix flake check --all-systems --no-build
  # Every file formatted: Nix, shell, Lua, Rust and Markdown.
  step "fmt" nix fmt -- --ci
}

lint() {
  # Nix: statix's and deadnix's lints, and nixd's own diagnostics.
  step "statix" statix check .
  step "deadnix" deadnix --fail .
  step "nixf-diagnose" each '*.nix' nixf-diagnose
  # Every optional check. (The flake check doesn't build, so the one
  # writeShellApplication runs on statusline.sh never happens there.)
  step "shellcheck" each '*.sh' shellcheck -o all
  # Markdown lint, beyond what `rumdl fmt` fixes.
  step "rumdl" each '*.md' rumdl check
  step "actionlint" actionlint
}

# The Zellij plugins: clippy (pedantic, warnings fail) and tests.
rust() {
  local crate
  for crate in anon finder hints; do
    step "clippy ${crate}" cargo clippy --manifest-path "home/zellij/${crate}/Cargo.toml" \
      --all-targets -- -W clippy::pedantic -D warnings
    step "test ${crate}" cargo test --manifest-path "home/zellij/${crate}/Cargo.toml"
  done
}

# Neovim with this checkout's home/nvim and a Home Manager config's plugins
# (this machine's, else the server's) starts without errors, and lua_ls finds
# no problems with the editor's settings. Building the home files builds the
# Zellij plugins for WASI too.
nvim() {
  local user host config
  user=$(id -un)
  host=$(hostname -s)
  config=$(nix eval --raw ".#homeConfigurations" --apply \
    "c: if c ? \"${user}@${host}\" then \"${user}@${host}\" else \"conix\"")
  step "nvim startup (${config})" nvim_startup "${config}"
  step "lua_ls" lua_ls
}

# (Steps run as conditions, where set -e is off: each failure returns.)
nvim_startup() {
  local cfg=".#homeConfigurations.\"$1\".config" home_files package
  keep --out-link home-files --no-link
  home_files=$(nix build "${kept[@]}" --print-out-paths "${cfg}.home-files") || return
  keep --out-link neovim --no-link
  package=$(nix build "${kept[@]}" --print-out-paths "${cfg}.programs.neovim.finalPackage") || return
  nvim_tmp=$(mktemp -d) || return
  # The plugins as the switch would install them. The config itself is this
  # checkout's: the home files link ~/.config/nvim to ~/nix/home/nvim, which
  # needn't exist (CI's checkout is elsewhere).
  mkdir -p "${nvim_tmp}/config" && ln -s "${root}/home/nvim" "${nvim_tmp}/config/nvim" || return
  export XDG_CONFIG_HOME=${nvim_tmp}/config XDG_DATA_HOME=${home_files}/.local/share
  export XDG_STATE_HOME=${nvim_tmp}/state XDG_CACHE_HOME=${nvim_tmp}/cache
  # The login session's variable nixd's config needs (after/lsp/nixd.lua).
  export NH_FLAKE=${root}
  # Fails, too, if the config didn't load.
  "${package}/bin/nvim" --headless -i NONE \
    +'lua if not vim.lsp.config.lua_ls.settings.Lua.workspace then error("config not loaded") end' \
    +qa 2>"${nvim_tmp}/errors"
  if [[ -s ${nvim_tmp}/errors ]]; then
    echo "Neovim reported errors at startup:"
    cat "${nvim_tmp}/errors"
    return 1
  fi
  echo "Neovim starts cleanly."
  nvim_bin=${package}/bin/nvim
}

# lua_ls's settings as the editor resolves them (after/lsp/lua_ls.lua merged
# over nvim-lspconfig's), runtime files included.
lua_ls() {
  [[ -n ${nvim_bin:-} ]] || return 1 # the startup step didn't get far enough
  "${nvim_bin}" --headless -i NONE -c "lua
    local settings = vim.lsp.config.lua_ls.settings.Lua
    local f = assert(io.open('${nvim_tmp}/luarc.json', 'w'))
    f:write(vim.json.encode(settings))
    f:close()
    io.stdout:write(#settings.workspace.library .. ' library folders\n')" +qa || return
  if ! grep -q '"library":\["' "${nvim_tmp}/luarc.json"; then
    echo "lua_ls's settings have no library:"
    cat "${nvim_tmp}/luarc.json"
    return 1
  fi
  if ! lua-language-server --check="${root}/home/nvim" --configpath="${nvim_tmp}/luarc.json" \
    --checklevel=Hint --check_format=pretty --logpath="${nvim_tmp}/lua_ls"; then
    echo "lua_ls's log:"
    tail -n 40 "${nvim_tmp}"/lua_ls/*.log
    return 1
  fi
}

groups=("$@")
[[ ${#groups[@]} -gt 0 ]] || groups=(check lint rust nvim)
for group in "${groups[@]}"; do
  case ${group} in
  check | lint | rust | nvim) "${group}" ;;
  *)
    echo "Unknown group: ${group} (check, lint, rust, nvim)" >&2
    exit 2
    ;;
  esac
done

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n\033[1;31mFailed:\033[0m %s\n' "${failed[*]}"
  exit 1
fi
printf '\n\033[1;32mAll passed:\033[0m %s\n' "${groups[*]}"
