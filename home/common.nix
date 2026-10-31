# Everything shared by every machine: desks (hubble, laptop) and servers.
{ pkgs, ... }:

{
  imports = [
    ./git.nix
    ./ai.nix
    ./shell.nix
    ./neovim.nix
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

  # Tell programs the terminal supports 24-bit colour. SSH doesn't forward
  # COLORTERM, so without this, tools over SSH (and inside zellij) fall back
  # to 256 colours and round every theme colour: the "washed out" look.
  # True for every terminal used here (kitty, zellij inside kitty).
  home.sessionVariables.COLORTERM = "truecolor";

  # GitHub CLI. Login (`gh auth login`) is per machine and never in Nix;
  # use "Login with a web browser" and open the printed URL on any machine.
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh"; # clone/push over SSH (key uploaded by gh)
  };

  # Fast grep. Smart case: case-insensitive unless you type a capital.
  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" ];
  };

  # cat with syntax highlighting. "ansi" reuses the terminal's own colours,
  # so it matches kitty's theme everywhere, including over SSH.
  programs.bat = {
    enable = true;
    config.theme = "ansi";
  };

  # Fuzzy finder. Shell keys: Ctrl-T pick a file, Alt-C cd into a dir.
  # Listing via fd means .gitignore'd paths (checkpoints, data/) are skipped.
  programs.fzf = {
    enable = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidget.command = "fd --type f --hidden --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --exclude .git";
    historyWidget.command = ""; # Ctrl-R belongs to atuin (shell.nix)
    defaultOptions = [ "--color=16" ]; # terminal's own colours, like bat
  };

  # Terminal multiplexer, with its default config (no config file).
  # Not started automatically: run `zellij`, or `zellij attach -c main`.
  programs.zellij.enable = true;

  # Process viewer.
  programs.htop.enable = true;

  # Terminal file manager. Run `y`; quitting leaves the shell in the
  # directory you were browsing.
  programs.yazi.enable = true;
}
