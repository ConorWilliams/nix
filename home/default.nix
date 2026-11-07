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
    inputs.nix-index-database.homeModules.nix-index
    ./git.nix
    ./shell.nix
    ./zellij.nix
    ./claude.nix
    ./neovim.nix
  ];

  # Rose Pine Dawn's colours by role (base, text, rose, love...), from
  # the official palette, for every module to use as `dawn`
  _module.args.dawn = lib.genAttrs' (lib.importJSON "${inputs.rose-pine-palette}/palette.json").dawn (
    c: lib.nameValuePair c.role "#${c.hex}"
  );

  # Compatibility marker for Home Manager's defaults, not a version pin.
  home.stateVersion = "26.11";

  # Lets Home Manager put its own `home-manager` command on PATH.
  programs.home-manager.enable = true;

  # `, cowsay hi` runs a program from nixpkgs without installing it, and a
  # command that isn't installed says which package has it (in fish too).
  programs.nix-index.enable = true;
  programs.nix-index-database.comma.enable = true;

  # nix commands use our pinned nixpkgs
  nix.registry.nixpkgs.flake = inputs.nixpkgs;

  # nh: a friendlier front end for switching.
  programs.nh = {
    enable = true;
    flake = "${config.home.homeDirectory}/nix";
    clean = {
      # Darwin has its own cleanup
      enable = !pkgs.stdenv.hostPlatform.isDarwin;
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

  # Only the locales in use, not all of them.
  i18n.glibcLocales = pkgs.glibcLocales.override {
    allLocales = false;
    locales = [
      "en_GB.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };

  # Programs installed with `uv tool install` (and the like) land here.
  home.sessionPath = [ "$HOME/.local/bin" ];

  # kitty's terminfo where ncurses looks by default, so programs can drive kitty
  # (over SSH and under sudo too).
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
    tokei # code count
    fend # calculator, with units (`c` in fish: shell.nix)
    rsync
    kitty.kitten # kitty's helper (icat etc.), without the GUI app
    htop
    zk
    # rmz / cpz: fast rm and cp for big trees, built with their progress bars.
    (fuc.overrideAttrs {
      cargoBuildFeatures = [
        "rmz/progress"
        "cpz/progress"
      ];
    })
  ];

  programs.codex = {
    enable = true;
    mutableSettings = true; # preserve settings added by Codex or the user
    settings.tui.vim_mode_default = true;
  };

  # Shell aliases, for every shell Home Manager manages.
  home.shellAliases = {
    hms = "nh home switch"; # the flake comes from NH_FLAKE (programs.nh)
    icat = "kitten icat";
    # mosh from Nix would use Nix's own ssh, which lacks GSSAPI and warns
    # about Ubuntu's /etc/ssh/ssh_config; use the system's ssh instead.
    mosh = "mosh --ssh=ssh";
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # (Home Manager's old defaults, being retired)
    settings."*" = {
      ServerAliveInterval = 60;
      ServerAliveCountMax = 3;
    };
  };

  home.sessionVariables = {
    # Tell programs the terminal supports 24-bit colour.
    COLORTERM = "truecolor";
  };

  programs.gh = {
    enable = true;
    # gh repo clone etc. use HTTPS too
    settings.git_protocol = "https";
    # `gh poi [--dry-run]`: deletes local branches whose PR was merged and their unused worktrees
    # `gh stack`: stacked PRs
    extensions = with pkgs; [
      gh-poi
      gh-stack
    ];
  };

  programs.ripgrep = {
    enable = true;
    arguments = [ "--smart-case" ];
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

  # eza (ls, ll, la, lt, lla), with icons and a git column.
  # Wrapped so it ignores LS_COLORS above.
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
}
