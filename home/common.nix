# Everything shared by every machine: desks (hubble, laptop) and servers.
{ pkgs, ... }:

{
  imports = [ ./git.nix ];

  # Compatibility marker for Home Manager's defaults, NOT a version pin.
  # Set once when a user is first created; never bump it casually.
  home.stateVersion = "26.05";

  # Lets Home Manager put its own `home-manager` command on PATH.
  programs.home-manager.enable = true;

  # Plain command-line tools with no config of their own.
  # Tools that need config or shell integration (git, fish, zellij, atuin,
  # zoxide, fzf...) get their own `programs.<name>` block in later steps.
  home.packages = with pkgs; [
    ripgrep # rg
    fd
    eza # ls replacement
    bat # cat replacement
    dust # du replacement
    btop
    jq
    tree
    gh
    uv
  ];
}
