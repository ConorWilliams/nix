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
        colorMoved = "blocks"; # moved lines get their own colour (no alternating)...
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

      # Worktrees and their repo point at each other with relative paths, so
      # a project folder still works after it's moved or copied.
      worktree.useRelativePaths = true;
    };
  };

  # `git clone-wt <url> [dir]`: a repo set up for worktrees. The repo itself
  # (bare, no files) goes in <dir>/.bare, and each checkout is a folder
  # beside it, starting with <dir>/<default branch>; lazygit then offers
  # <dir>/<branch> for new ones. (A git subcommand runs as its own process,
  # so it can't cd the shell: it prints where to go.)
  home.packages = [
    (pkgs.writeShellApplication {
      name = "git-clone-wt";
      runtimeInputs = [ config.programs.git.package ];
      text = ''
        if [[ $# -lt 1 ]]; then
          echo "usage: git clone-wt <url> [dir]" >&2
          exit 1
        fi
        url=$1
        name=''${url##*[/:]}
        dir=''${2:-''${name%.git}}

        git clone --bare "$url" "$dir/.bare"
        echo "gitdir: ./.bare" >"$dir/.git" # so git works from <dir> too
        # A bare clone fetches no remote branches (origin/*) by default.
        git -C "$dir" config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
        git -C "$dir" fetch --quiet origin

        # It also copied every remote branch as a local one; keep only the
        # default branch (tracking origin), as a normal clone would. Full ref
        # names throughout: short ones become "heads/x" when a tag is also
        # called x. (One update-ref for all: repos can have thousands.)
        branch=$(git -C "$dir" symbolic-ref HEAD)
        branch=''${branch#refs/heads/}
        git -C "$dir" for-each-ref --format='delete %(refname)' refs/heads |
          grep -vxF "delete refs/heads/$branch" |
          git -C "$dir" update-ref --stdin
        git -C "$dir" branch --quiet --set-upstream-to="origin/$branch" "$branch"

        git -C "$dir" worktree add --quiet "$branch" "$branch"
        echo "Ready: cd $dir/$branch"
      '';
    })
  ];

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
      # backgrounds instead: yellow where they left, light blue where they
      # arrived.
      map-styles = "bold purple => syntax #fff3c4, bold cyan => syntax #dff0ff";
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
