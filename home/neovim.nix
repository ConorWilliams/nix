# Neovim: plain Lua config in ../nvim, plugins via vim.pack (pinned by the
# committed nvim-pack-lock.json), language servers and tools from Nix.
{ config, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true; # sets EDITOR=nvim

    # HM always generates a little init.lua (provider settings); load it via
    # the wrapper instead so ~/.config/nvim can be our own directory.
    sideloadInitLua = true;
  };

  # Live symlink into the repo (not a store copy): edits apply without a
  # switch, and vim.pack can write its lockfile. Assumes the repo is at ~/nix.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/nix/nvim";
}
