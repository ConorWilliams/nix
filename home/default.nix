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
    ./shell.nix
    ./zellij.nix
    ./claude.nix
    ./neovim.nix
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

  # Only the locales in use, not all of them (~220 MB less in every
  # closure).
  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = [
      "en_GB.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };

  # Programs installed with `uv tool install` (and the like) land here.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # kitty's terminfo where ncurses looks by default, so programs (incl.
  # over SSH, and under sudo with a preserved HOME) can drive kitty.
  home.file.".terminfo".source = "${pkgs.kitty.terminfo}/share/terminfo";

  # Plain command-line tools with no config of their own. Tools with config
  # or shell integration get a `programs.<name>` block below or in their own
  # file.
  home.packages = with pkgs; [
    fd
    dust
    duf
    uv
    mosh
    tokei
    rsync
    kitty.kitten # kitty's helper (icat etc.), without the GUI app
    htop
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
    hms = "nh home switch"; # the flake comes from NH_FLAKE (programs.nh)
    icat = "kitten icat";
    # mosh from Nix would use Nix's own ssh, which lacks GSSAPI and warns
    # about Ubuntu's /etc/ssh/ssh_config; use the system's ssh instead.
    mosh = "mosh --ssh=ssh";
  };

  home.sessionVariables = {
    # Tell programs the terminal supports 24-bit colour.
    COLORTERM = "truecolor";
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

  programs.fzf =
    let
      fd = "fd --hidden --exclude .git";
    in
    {
      enable = true;
      defaultCommand = "${fd} --type f";
      fileWidget.command = "${fd} --type f";
      changeDirWidget.command = "${fd} --type d";
      historyWidget.command = ""; # Ctrl-R belongs to atuin (shell.nix)
      # Rose Pine Dawn.
      defaultOptions =
        let
          port = builtins.readFile "${inputs.rose-pine-fzf}/dist/rose-pine-dawn.sh";
          lines = map lib.trim (lib.splitString "\n" port);
          # (the last line ends with the export's closing quote)
          colors = map (lib.removeSuffix "\"") (lib.filter (lib.hasPrefix "--color") lines);
        in
        # Fail the build rather than silently losing the colours if the port
        # ever changes its file's layout.
        assert lib.assertMsg (colors != [ ]) "rose-pine-fzf: no --color lines found";
        colors;
    };

  # LS_COLORS (fd, plain ls, tree, fish's file completions...)
  programs.vivid = {
    enable = true;
    activeTheme = "rose-pine-dawn";
  };

  # eza (ls, ll, la, lt, lla), with icons and a git column. Wrapped so it
  # always reads its theme from ~/.config/eza (macOS would look in
  # ~/Library) and ignores LS_COLORS (vivid's), which would otherwise
  # override the official Rose Pine port below.
  programs.eza = {
    enable = true;
    icons = "auto";
    git = true;
    package = pkgs.symlinkJoin {
      name = "eza";
      paths = [ pkgs.eza ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/eza --unset LS_COLORS \
          --set EZA_CONFIG_DIR "${config.xdg.configHome}/eza"
      '';
    };
  };
  xdg.configFile."eza/theme.yml".source = "${inputs.rose-pine-eza}/dist/rose-pine-dawn.yml";

  # Rose Pine Dawn: the port's flavor (UI colours and the code-preview
  # theme), named for light and dark alike (detection fails over mosh and
  # inside zellij), plus its icon colours.
  programs.yazi = {
    enable = true;
    flavors.rose-pine-dawn = "${inputs.rose-pine-yazi}/flavors/rose-pine-dawn.yazi";
    theme = fromTOML (builtins.readFile "${inputs.rose-pine-yazi}/themes/rose-pine-dawn.toml") // {
      flavor = {
        light = "rose-pine-dawn";
        dark = "rose-pine-dawn";
      };
    };
  };
}
