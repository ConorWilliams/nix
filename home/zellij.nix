# zellij, the terminal multiplexer. Not started automatically: run
# `zellij`, or `zellij attach -c main` to resume a named session (over ssh,
# `ssh -t host zellij attach -c main`: zellij needs a terminal).
{ inputs, ... }:

let
  # Ctrl+arrows move between panes, and inside nvim between its splits too
  # (smart-splits in nvim/plugin/20_keymaps.lua hands over at the edge).
  # Bound in normal and locked mode, so shell panes lose Ctrl+Left/Right
  # word jumps (Alt+Left/Right still do that in fish).
  navigation =
    let
      bind = key: dir: ''
        bind "Ctrl ${key}" {
          MessagePlugin "file:${inputs.vim-zellij-navigator}" {
            name "move_focus";
            payload "${dir}";
            use_arrow_keys "true"; // hand nvim Ctrl+arrows, not Ctrl-h/j/k/l
          };
        }
      '';
    in
    bind "Left" "left" + bind "Down" "down" + bind "Up" "up" + bind "Right" "right";

  # The keybinding preset (copied; see the comment at the top of the file),
  # with the navigation bindings placed inside its normal/locked block:
  # zellij only reads the first top-level keybinds block.
  keybinds = builtins.replaceStrings [ "// NAVIGATION" ] [ navigation ] (
    builtins.readFile ./zellij/keybinds-unlock-first.kdl
  );

  # The compact bar's key-hint tooltip (F1 also toggles it by hand). This
  # adds to zellij's default plugin list rather than replacing it.
  compactBar = ''
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
    # Named explicitly: zellij can't ask the terminal whether it's light or
    # dark through mosh, and then falls back to a dark theme.
    # (the contents: a path string would be written out as text)
    themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
    # Modal keys with a leader: see the comment at the top of
    # zellij/keybinds-unlock-first.kdl.
    # TODO: zellij 0.45.1 can't select this preset by name, so it's copied.
    # A later release may: then keybinds preset="unlock-first" plus the
    # navigation bindings.
    extraConfig = keybinds + compactBar;
    settings = {
      default_mode = "locked"; # part of the preset: keys go to the shell
      # One slim bar (tabs and mode) instead of the tab bar + hints bar;
      # the key hints pop up as a tooltip outside locked mode (after Ctrl-g).
      default_layout = "compact";
      theme = "rose-pine-dawn";
      # Having a config file at all also skips the first-run setup screen.
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
