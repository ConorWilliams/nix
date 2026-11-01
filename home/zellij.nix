# zellij, the terminal multiplexer. Not started automatically: run
# `zellij`, or `zellij attach -c main` to resume a named session (over ssh,
# `ssh -t host zellij attach -c main`: zellij needs a terminal).
{ inputs, ... }:

let
  # Ctrl-h/j/k/l move between panes, and inside nvim between its splits
  # too (smart-splits in nvim/plugin/20_keymaps.lua hands over at the edge).
  # In every mode, so shell panes lose Ctrl-l (clear) and Ctrl-k (kill line).
  navigation =
    let
      bind = key: dir: ''
        bind "Ctrl ${key}" {
          MessagePlugin "file:${inputs.vim-zellij-navigator}" {
            name "move_focus";
            payload "${dir}";
          };
        }
      '';
    in
    ''
      keybinds {
        shared_among "normal" "locked" {
          ${bind "h" "left"}
          ${bind "j" "down"}
          ${bind "k" "up"}
          ${bind "l" "right"}
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
    # Modal keys with a leader: see the comment at the top of the file.
    # TODO: zellij 0.45.1 can't select this preset by name, so it's copied.
    # The next release can: replace the file with
    #   extraConfig = ''keybinds preset="unlock-first" { }'';
    extraConfig = builtins.readFile ./zellij/keybinds-unlock-first.kdl + navigation;
    settings = {
      default_mode = "locked"; # part of the preset: keys go to the shell
      theme = "rose-pine-dawn";
      # Having a config file at all also skips the first-run setup screen.
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
