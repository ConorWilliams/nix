# Neovim: plain Lua config in ./nvim, plugins via vim.pack (pinned by the
# committed nvim-pack-lock.json), language servers and tools from Nix.
{ config, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets EDITOR=nvim

    # HM always generates a little init.lua (provider settings); load it via
    # the wrapper instead so ~/.config/nvim can be this repo's nvim/.
    sideloadInitLua = true;

    # Language servers and formatters, on nvim's PATH only.
    extraPackages = with pkgs; [
      lua-language-server
      stylua
      nixd
      nixfmt
      bash-language-server
      shfmt
      # Python: fallbacks; a project's .venv/bin versions are preferred
      ruff
      ty
      # Markdown (zk's server comes with zk, in default.nix)
      marksman
      rumdl
      # GitHub Copilot
      copilot-language-server
    ];

    # Treesitter from Nix rather than vim.pack: the plugin, prebuilt parsers
    # and their matching queries, all from the binary cache (no compiler).
    plugins = [
      # Completion (nvim/plugin/65_completion.lua): built by nixpkgs with its
      # Rust fuzzy matcher, rather than downloaded on each machine.
      pkgs.vimPlugins.blink-cmp
      (pkgs.vimPlugins.nvim-treesitter.withPlugins (
        p: with p; [
          # Neovim's own languages (it ships some parsers, but these match the queries)
          lua
          vim
          vimdoc
          query
          markdown
          markdown_inline
          # This repo and the shell
          nix
          bash
          fish
          kdl # zellij
          # Python and data
          python
          toml
          yaml
          json
          # C++
          c
          cpp
          cmake
          make
          dockerfile
          # Git
          diff
          gitcommit
          git_rebase
          gitignore
          # Misc
          regex
          latex
          typst
          html
        ]
      ))
    ];
  };

  # rumdl (Markdown lint, in nvim): its list-item-spacing rule would
  # insist on one blank-line style per list.
  xdg.configFile."rumdl/rumdl.toml".text = ''
    [global]
    disable = ["MD076"]
  '';

  # Live symlink into the repo (not a store copy): edits apply without a
  # switch, and vim.pack can write its lockfile. Assumes the repo is at ~/nix.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/home/nvim";
}
