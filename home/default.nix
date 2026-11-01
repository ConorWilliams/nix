# The base layer: every machine gets this, and on its own it's the config
# for servers. All command-line tools live here.
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

  # Compatibility marker for Home Manager's defaults, not a version pin.
  home.stateVersion = "26.11";

  # Lets Home Manager put its own `home-manager` command on PATH.
  programs.home-manager.enable = true;

  # nh: a friendlier front end for switching.
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nix";
    clean = {
      enable = true;
      extraArgs = [
        "--keep"
        "5"
        "--keep-since"
        "7d"
      ];
    };
  };

  # No "unread news" reminder on each switch.
  news.display = "silent";

  # Plain command-line tools with no config of their own. Tools with config
  # or shell integration get a `programs.<name>` block below or in their own
  # file.
  home.packages = with pkgs; [
    fd # fast find
    dust # du as a tree
    duf # df as a table
    eza # modern ls
    uv # Python packages, projects and interpreters
    mosh # SSH that survives sleep and network changes
    tokei # count lines of code
    rsync # remote copy, with progress bar
    # rmz / cpz: fast rm and cp for big trees, built with their progress bars.
    (fuc.overrideAttrs {
      cargoBuildFeatures = [
        "rmz/progress"
        "cpz/progress"
      ];
    })
    kitty.kitten # kitty's helper (icat etc.), without the GUI app
    kitty.terminfo # lets programs drive kitty properly, including over SSH
    zk # Markdown notes (zettelkasten)
    codex
  ];

  # Shell aliases, for every shell Home Manager manages (fish, bash).
  home.shellAliases = {
    hms = "nh home switch ${config.home.homeDirectory}/nix"; # path given: works before NH_FLAKE reaches the shell
    ll = "eza -l --icons=auto";
    lt = "eza --tree --icons=auto";
    icat = "kitten icat"; # show an image; works over ssh, not over mosh
    # mosh from Nix would use Nix's own ssh, which lacks GSSAPI and warns
    # about Ubuntu's /etc/ssh/ssh_config; use the system's ssh instead.
    mosh = "mosh --ssh=ssh";
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

  # GitHub CLI. Login (`gh auth login`) is per machine and never in Nix
  # (bootstrap.sh offers it). git authenticates to GitHub through gh's
  # token: Home Manager makes gh git's credential helper for github.com,
  # so remotes are https://github.com/... (no SSH keys on GitHub).
  programs.gh = {
    enable = true;
    settings.git_protocol = "https"; # gh repo clone etc. use HTTPS too
  };

  # Fast grep. Smart case: case-insensitive unless the pattern has a capital.
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
  # directory last browsed.
  programs.yazi.enable = true;
}
