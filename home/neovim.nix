# Neovim: plain Lua config in ./nvim; plugins, language servers and tools
# from Nix, so `nix flake update` updates them with everything else.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # A plugin nixpkgs doesn't package, from its flake input.
  fromInput =
    name: input:
    pkgs.vimUtils.buildVimPlugin {
      pname = name;
      version = input.shortRev;
      src = input;
    };
in

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

    # All loaded at startup, before nvim/plugin/*.lua (which set them up).
    plugins = with pkgs.vimPlugins; [
      rose-pine # (30_ui.lua)
      mini-nvim
      which-key-nvim
      (fromInput "go-up.nvim" inputs.go-up-nvim)
      smart-splits-nvim # (20_keymaps.lua)
      (fromInput "smart-splits-zellij" inputs.smart-splits-zellij)
      flash-nvim # (50_editing.lua)
      snacks-nvim # (55_picker.lua)
      nvim-lspconfig # (60_lsp.lua)
      conform-nvim # (61_format.lua)
      blink-cmp # (65_completion.lua; built with its Rust fuzzy matcher)
      friendly-snippets
      render-markdown-nvim # (70_markdown.lua)
      zk-nvim
      gitsigns-nvim # (75_git.lua)
      persistence-nvim # (85_start.lua)
      # Treesitter: the plugin, prebuilt parsers and their matching queries,
      # all from the binary cache (no compiler).
      (nvim-treesitter.withPlugins (
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
  # switch. The repo is where nh
  # expects it (~/nix, home/default.nix).
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.programs.nh.flake}/home/nvim";
}
