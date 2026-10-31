# Everything shared by every machine: hubble, luna, mac and the servers.
{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./claude.nix
    ./shell.nix
    ./neovim.nix
    ./ssh.nix
    ./zellij.nix
  ];

  # Compatibility marker for Home Manager's defaults, NOT a version pin.
  # Set once when a user is first created; never bump it casually.
  home.stateVersion = "26.11";

  # Lets Home Manager put its own `home-manager` command on PATH.
  programs.home-manager.enable = true;

  # Plain command-line tools with no config of their own. Tools with config
  # or shell integration get a `programs.<name>` block below or in their own
  # file (git, shells, claude, ssh, zellij).
  home.packages = with pkgs; [
    fd # fast find
    dust # du as a tree
    duf # df as a table
    eza # modern ls, used via `ll` below
    uv # Python packages, projects and interpreters
    mosh # SSH that survives sleep and network changes
    tokei # count lines of code
    rsync
    # rmz / cpz: fast rm and cp for big trees (checkpoints, datasets), built
    # with their progress bars (not in nixpkgs' default build, so each
    # machine compiles this once, ~a minute).
    (fuc.overrideAttrs {
      cargoBuildFeatures = [
        "rmz/progress"
        "cpz/progress"
      ];
    })
    kitty.kitten # kitty's helper (icat etc.), without the 600 MiB GUI app
    kitty.terminfo # lets programs drive kitty properly, including over SSH
  ];

  # Shell aliases, for every shell Home Manager manages (fish, bash).
  home.shellAliases = {
    ll = "eza -l --icons=auto";
    lt = "eza --tree --icons=auto";
    icat = "kitten icat"; # show an image; works over ssh, not over mosh
  };

  home.sessionVariables = {
    # Tell programs the terminal supports 24-bit colour. SSH doesn't forward
    # COLORTERM, so without this, tools over SSH (and inside zellij) fall back
    # to 256 colours and round every theme colour: the "washed out" look.
    # True for every terminal used here (kitty, zellij inside kitty).
    COLORTERM = "truecolor";
    # Find kitty's terminfo (above). The empty entry after ":" keeps each
    # program's own default locations (Nix ncurses only looks in its store).
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:";
  };

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

  # Process viewer.
  programs.htop.enable = true;

  # Terminal file manager. Run `y`; quitting leaves the shell in the
  # directory you were browsing.
  programs.yazi.enable = true;
}
