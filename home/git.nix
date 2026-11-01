# Git: identity, settings, and the tools around it (delta, lazygit, lfs).
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Remote URLs that mark a repo as work. GitHub ignores case in URLs,
  # but git's matching doesn't, so both spellings are listed.
  myrtleRemotes = [
    "https://github.com/MyrtleSoftware/**"
    "https://github.com/myrtlesoftware/**"
  ];
in
{
  programs.git = {
    enable = true;
    lfs.enable = true;

    # Myrtle identity for any repo with a myrtle remote.
    includes = map (url: {
      condition = "hasconfig:remote.*.url:${url}";
      contents.user.email = "conor@myrtle.ai";
    }) myrtleRemotes;

    settings = {
      # Default identity: personal.
      user = {
        name = "Conor Williams";
        email = "conorwilliams@outlook.com";
      };

      init.defaultBranch = "main";

      diff = {
        algorithm = "histogram"; # clearer diffs when code moves around
        colorMoved = "default"; # moved lines get their own colour...
        colorMovedWS = "allow-indentation-change"; # ...even if re-indented
      };

      # Conflict markers also show the original (common ancestor) version.
      merge.conflictStyle = "zdiff3";

      pull.rebase = true; # `git pull` replays local commits, no merge commits
      push.autoSetupRemote = true; # first push of a new branch needs no -u
      fetch.prune = true; # drop refs to branches deleted on the remote

      branch.sort = "-committerdate"; # `git branch`: most recent first
      tag.sort = "version:refname"; # v1.10 sorts after v1.9
      column.ui = "auto"; # list branches/tags in columns
      help.autocorrect = "prompt"; # `git stauts` -> "did you mean status?"
    };
  };

  # Pager for git diff/log/show/blame and `git add -p`.
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n / N jump between files
      # All terminals use the light Rosé Pine Dawn theme. Declared because
      # detection fails inside lazygit/zellij.
      light = true;
      # Lines git marks as moved (diff.colorMoved) arrive in git's own bold
      # magenta / cyan, which delta would show unstyled; give them soft
      # backgrounds instead: lavender where they left, light blue where
      # they arrived.
      map-styles = "bold purple => syntax #efe0ff, bold cyan => syntax #dff0ff";
    };
  };

  # Git TUI, showing diffs through delta.
  programs.lazygit = {
    enable = true;
    # Rose Pine Dawn: lazygit merges every file in LG_CONFIG_FILE, so the
    # command is wrapped to read its config (settings below) and then the
    # official port's theme.
    package =
      let
        configDir =
          if pkgs.stdenv.hostPlatform.isDarwin && !config.xdg.enable then
            "${config.home.homeDirectory}/Library/Application Support"
          else
            config.xdg.configHome;
      in
      pkgs.symlinkJoin {
        name = "lazygit";
        paths = [ pkgs.lazygit ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/lazygit --set LG_CONFIG_FILE \
            "${configDir}/lazygit/config.yml,${inputs.rose-pine-lazygit}/themes/rose-pine-dawn.yml"
        '';
      };
    settings = {
      git.diffRenderers = [
        {
          command = "delta --paging=never";
          colorArg = "always";
        }
      ];
      os.editPreset = "nvim-remote";
      gui.nerdFontsVersion = "3"; # file icons
    };
  };
}
