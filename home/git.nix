# Git identity. Tool config (delta, lazygit, jj, aliases) comes in the git step.
{ ... }:

let
  # Remote URLs that mark a repo as personal. GitHub ignores case in URLs,
  # but git's matching doesn't, so both spellings are listed.
  personalRemotes = [
    "git@github.com:ConorWilliams/**"
    "git@github.com:conorwilliams/**"
    "https://github.com/ConorWilliams/**"
    "https://github.com/conorwilliams/**"
  ];
in
{
  programs.git = {
    enable = true;

    # Default identity: work.
    settings.user = {
      name = "Conor Williams";
      email = "conor@myrtle.ai";
    };

    # Personal identity for any repo with a personal remote. Git checks
    # each condition when it runs, so this works the same on every machine.
    includes = map (url: {
      condition = "hasconfig:remote.*.url:${url}";
      contents.user.email = "conorwilliams@outlook.com";
    }) personalRemotes;
  };
}
