# Git identity. Tool config (delta, lazygit, jj, aliases) comes in the git step.
{ ... }:

let
  # Remote URLs that mark a repo as work. GitHub ignores case in URLs,
  # but git's matching doesn't, so both spellings are listed.
  myrtleRemotes = [
    "git@github.com:MyrtleSoftware/**"
    "git@github.com:myrtlesoftware/**"
    "https://github.com/MyrtleSoftware/**"
    "https://github.com/myrtlesoftware/**"
  ];
in
{
  programs.git = {
    enable = true;

    # Default identity: personal.
    settings.user = {
      name = "Conor Williams";
      email = "conorwilliams@outlook.com";
    };

    # Myrtle identity for any repo with a myrtle remote.
    includes = map (url: {
      condition = "hasconfig:remote.*.url:${url}";
      contents.user.email = "conor@myrtle.ai";
    }) myrtleRemotes;
  };
}
