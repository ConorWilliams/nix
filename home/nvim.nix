# Neovim: plain Lua config in ./nvim; plugins, language servers and tools
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

    # Language servers and formatters for editing config and prose anywhere,
    # on nvim's PATH only (after the shell's). Project toolchains, and their
    # servers (rust-analyzer...), come from the project's direnv/devshell.
    extraPackages = with pkgs; [
      lua-language-server
      stylua
      nixd
      nixfmt
      bash-language-server
      shellcheck
      shfmt
      # Markdown (zk's server comes with zk, in default.nix)
      marksman
      rumdl
      # GitHub Copilot
      copilot-language-server
    ];

    # All on the runtime path at startup, so nvim/plugin/*.lua can require()
    # and set them up.
    plugins = with pkgs.vimPlugins; [
      rose-pine
      mini-nvim
      which-key-nvim
      (fromInput "go-up.nvim" inputs.go-up-nvim)
      smart-splits-nvim
      (fromInput "smart-splits-zellij" inputs.smart-splits-zellij)
      flash-nvim
      yanky-nvim
      snacks-nvim
      nvim-lspconfig
      conform-nvim
      blink-cmp
      friendly-snippets
      render-markdown-nvim
      zk-nvim
      gitsigns-nvim
      persistence-nvim
      # Treesitter: the plugin, prebuilt parsers and their matching queries.
      (nvim-treesitter.withPlugins (
        p: with p; [
          lua
          vim
          vimdoc
          query
          markdown
          markdown_inline
          nix
          bash
          fish
          kdl # Zellij
          python
          ini
          toml
          yaml
          json
          rust
          c
          cpp
          cmake
          make
          dockerfile
          diff
          gitcommit
          git_rebase
          gitignore
          regex
          latex
          typst
          html
        ]
      ))
    ];
  };

  # Personal preferences
  xdg.configFile."rumdl/rumdl.toml".text = /* toml */ ''
    [global]
    disable = ["MD076"]

    [MD060]
    enabled = true
    style = "aligned"
  '';

  # Live symlink into the repo (not a store copy): edits apply without a switch.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.programs.nh.flake}/home/nvim";
}
