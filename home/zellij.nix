# zellij, the terminal multiplexer. Not started automatically: run
# `zellij`, or `zellij attach -c main` to resume a named session (over ssh,
# `ssh -t host zellij attach -c main`: zellij needs a terminal).
{ inputs, ... }:

{
  programs.zellij = {
    enable = true;
    # Named explicitly: zellij can't ask the terminal whether it's light or
    # dark through mosh, and then falls back to a dark theme.
    themes.rose-pine-dawn = "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
    # Modal keys with a leader: see the comment at the top of the file.
    # TODO: zellij 0.45.1 can't select this preset by name, so it's copied.
    # The next release can: replace the file with
    #   extraConfig = ''keybinds preset="unlock-first" { }'';
    extraConfig = builtins.readFile ./zellij/keybinds-unlock-first.kdl;
    settings = {
      default_mode = "locked"; # part of the preset: keys go to the shell
      theme = "rose-pine-dawn";
      # Having a config file at all also skips the first-run setup screen.
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
