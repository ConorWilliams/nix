# Everything shared by every machine: desks (hubble, laptop) and servers.
{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./ai.nix
  ];

  # Compatibility marker for Home Manager's defaults, NOT a version pin.
  # Set once when a user is first created; never bump it casually.
  home.stateVersion = "26.11";

  # Lets Home Manager put its own `home-manager` command on PATH.
  programs.home-manager.enable = true;

  # Plain command-line tools with no config of their own.
  # Tools that need config or shell integration (git, fish, zellij, atuin,
  # zoxide, fzf...) get their own `programs.<name>` block in later steps.
  home.packages = with pkgs; [
    ripgrep # rg: fast grep
    fd # fast find
    dust # du as a tree
    duf # df as a table
    eza # modern ls, used via `ll` below
    uv # Python packages, projects and interpreters
    mosh # SSH that survives sleep and network changes
    tokei # count lines of code
  ];

  # Shell aliases, for every shell Home Manager manages (fish, bash).
  home.shellAliases = {
    ll = "eza -l --icons=auto";
    lt = "eza --tree --icons=auto";
  };

  # GitHub CLI. Login (`gh auth login`) is per machine and never in Nix.
  programs.gh.enable = true;

  # cat with syntax highlighting.
  programs.bat.enable = true;

  # Fuzzy finder. Shell keys: Ctrl-T pick a file, Alt-C cd into a dir.
  programs.fzf.enable = true;

  # Process viewer.
  programs.htop.enable = true;

  # Terminal file manager. Run `y`; quitting leaves the shell in the
  # directory you were browsing.
  programs.yazi.enable = true;
}
