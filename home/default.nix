# The base layer: every machine gets this, and on its own it's the config
# for servers. All command-line tools live here.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

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
    fd
    dust
    duf
    eza
    uv
    mosh
    tokei
    rsync
    kitty.kitten # kitty's helper (icat etc.), without the GUI app
    kitty.terminfo # lets programs drive kitty properly, including over SSH
    zk
    codex
    # rmz / cpz: fast rm and cp for big trees, built with their progress bars.
    (fuc.overrideAttrs {
      cargoBuildFeatures = [
        "rmz/progress"
        "cpz/progress"
      ];
    })
  ];

  # Shell aliases, for every shell Home Manager manages (fish, bash).
  home.shellAliases = {
    hms = "nh home switch ${config.home.homeDirectory}/nix";
    ls = "eza --icons=auto";
    ll = "eza -l --icons=auto --git"; # with a git status column
    lt = "eza --tree --icons=auto";
    icat = "kitten icat";
    # mosh from Nix would use Nix's own ssh, which lacks GSSAPI and warns
    # about Ubuntu's /etc/ssh/ssh_config; use the system's ssh instead.
    mosh = "mosh --ssh=ssh";
  };

  home.sessionVariables = {
    # Tell programs the terminal supports 24-bit colour.
    COLORTERM = "truecolor";
    # Find kitty's terminfo (above).
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:";
  };

  programs.gh = {
    enable = true;
    settings.git_protocol = "https"; # gh repo clone etc. use HTTPS too
  };

  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" ]; # Case-insensitive unless the pattern has a capital.
  };

  programs.bat = {
    enable = true;
    themes.rose-pine-dawn = {
      src = inputs.rose-pine-tm-theme;
      file = "dist/rose-pine-dawn.tmTheme";
    };
    config.theme = "rose-pine-dawn";
  };

  programs.fzf = {
    enable = true;
    defaultCommand = "fd --type f --hidden --exclude .git";
    fileWidget.command = "fd --type f --hidden --exclude .git";
    changeDirWidget.command = "fd --type d --hidden --exclude .git";
    historyWidget.command = ""; # Ctrl-R belongs to atuin (shell.nix)
    # Rose Pine Dawn.
    defaultOptions =
      let
        port = builtins.readFile "${inputs.rose-pine-fzf}/dist/rose-pine-dawn.sh";
        lines = map lib.trim (lib.splitString "\n" port);
      in
      # (the last line ends with the export's closing quote)
      map (lib.removeSuffix "\"") (lib.filter (lib.hasPrefix "--color") lines);
  };

  # LS_COLORS (fd, plain ls, tree, fish's file completions...)
  programs.vivid = {
    enable = true;
    activeTheme = "rose-pine-dawn";
  };

  # ls colours (eza)
  xdg.configFile."eza/theme.yml".source = "${inputs.rose-pine-eza}/dist/rose-pine-dawn.yml";

  programs.htop.enable = true;

  # Terminal file manager
  programs.yazi = {
    enable = true;
    theme = builtins.fromTOML (builtins.readFile "${inputs.rose-pine-yazi}/themes/rose-pine-dawn.toml");
  };
}
