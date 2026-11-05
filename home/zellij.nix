{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # Ctrl+arrows move between panes, and inside nvim between its splits too.
  navigation =
    lib.concatMapStrings
      (dir: /* kdl */ ''
        bind "Ctrl ${lib.toSentenceCase dir}" {
          MessagePlugin "file:${pkgs.zellijPlugins.vim-zellij-navigator}" {
            name "move_focus";
            payload "${dir}";
            use_arrow_keys "true"; // hand nvim Ctrl+arrows, not Ctrl-h/j/k/l
          };
        }
      '')
      [
        "left"
        "down"
        "up"
        "right"
      ];

  keybinds = builtins.replaceStrings [ "// NAVIGATION" ] [ navigation ] (
    builtins.readFile ./zellij/keybinds-unlock-first.kdl
  );

  compactBar = /* kdl */ ''
    plugins {
      compact-bar location="zellij:compact-bar" {
        tooltip "F1"
      }
    }
  '';
in
{
  programs.zellij = {
    enable = true;
    themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
    # Modal keys with a leader: see the comment at the top of
    # zellij/keybinds-unlock-first.kdl.
    # TODO: zellij 0.45.1 can't select this preset by name, so it's copied.
    # A later release may: then keybinds preset="unlock-first" plus the
    # navigation bindings.
    extraConfig = keybinds + compactBar;
    settings = {
      default_mode = "locked"; # part of the preset: keys go to the shell
      default_layout = "compact";
      theme = "rose-pine-dawn";
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
