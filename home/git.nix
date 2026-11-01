# Git: identity, settings, and the tools around it (delta, lazygit, lfs).
{ ... }:

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

    # Large files (model weights, datasets) stored outside git history.
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
      # All terminals use the light Rosé Pine Dawn theme. Declared rather
      # than auto-detected, because detection fails inside lazygit/zellij.
      light = true;
    };
  };

  # Git TUI, showing diffs through delta.
  programs.lazygit = {
    enable = true;
    settings = {
      git.diffRenderers = [
        {
          command = "delta --paging=never";
          colorArg = "always";
        }
      ];
      # `e` on a file: inside nvim (<leader>gg) it opens in that nvim,
      # elsewhere in a new one.
      os.editPreset = "nvim-remote";
      gui.nerdFontsVersion = "3"; # file icons
    };
  };
}
