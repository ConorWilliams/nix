{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  # These only spell KDL nodes; all actions and modes belong to Zellij.
  bind = keys: actions: {
    bind = {
      _args = lib.toList keys;
      _children = lib.toList actions;
    };
  };
  mode = name: { SwitchToMode = name; };
  # Native tooltips inspect the first action, so keep the command before
  # returning to locked mode (attribute sets would sort these by name).
  once =
    keys: actions:
    bind keys [
      actions
      (mode "locked")
    ];
  manager =
    keys:
    once keys {
      LaunchOrFocusPlugin = {
        _args = [ "session-manager" ];
        floating = true;
        move_to_focused_tab = true;
        multi_screen = true; # native fuzzy search includes tabs and panes
      };
    };
in
{
  programs.zellij = {
    enable = true;
    themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
    settings = {
      default_mode = "locked";
      default_layout = "compact";
      theme = "rose-pine-dawn";
      show_startup_tips = false;
      show_release_notes = false;
      plugins.compact-bar._props.location = "zellij:compact-bar";
      keybinds = {
        _props.clear-defaults = true;
        locked._children = [ (bind "Alt g" (mode "normal")) ];
        normal._children = [
          (bind "b" (mode "tab"))
          (bind "q" (mode "session"))
          (bind "w" (mode "pane"))
          (bind "r" (mode "resize"))
          (bind "s" (mode "scroll"))
          (manager ",")
          (once "-" { NewPane = "Down"; })
          (once "|" { NewPane = "Right"; })
        ];
        tab._children = [
          (bind "n" (
            {
              NewTab = { };
              TabNameInput = 0;
            }
            // mode "renametab"
          ))
          (bind "r" ({ TabNameInput = 0; } // mode "renametab"))
          (manager "f")
          (once "b" { ToggleTab = { }; })
          (once [ "h" "Left" "[" ] { GoToPreviousTab = { }; })
          (once [ "l" "Right" "]" ] { GoToNextTab = { }; })
          (once "d" { CloseTab = { }; })
        ]
        ++ map (n: once (toString n) { GoToTab = n; }) (lib.range 1 9);
        renametab._children = [
          (bind "Enter" (mode "locked"))
          (once [ "Esc" "Ctrl c" "Alt g" ] { UndoRenameTab = { }; })
        ];
        session._children = [
          (manager [
            "s"
            "n"
            "r"
          ])
          (once "d" { Detach = { }; })
          (once "q" { Quit = { }; })
        ];
        pane._children = [
          (once "d" { CloseFocus = { }; })
          (once "m" { ToggleFocusFullscreen = { }; })
          (once "w" { FocusLastPane = { }; })
          (once "f" { ToggleFloatingPanes = { }; })
        ];
        resize._children = map (dir: bind dir { Resize = "Increase ${lib.toSentenceCase dir}"; }) [
          "Left"
          "Down"
          "Up"
          "Right"
        ];
        scroll._children = [
          (bind [ "j" "Down" ] { ScrollDown = { }; })
          (bind [ "k" "Up" ] { ScrollUp = { }; })
          (bind "Ctrl d" { HalfPageScrollDown = { }; })
          (bind "Ctrl u" { HalfPageScrollUp = { }; })
          (once "e" { EditScrollback = { }; })
        ];
        # Preserve the existing Ctrl+arrow hand-off between Neovim and Zellij.
        shared._children =
          map
            (
              dir:
              bind "Ctrl ${lib.toSentenceCase dir}" {
                MessagePlugin = {
                  _args = [ "file:${pkgs.zellijPlugins.vim-zellij-navigator}" ];
                  name = "move_focus";
                  payload = dir;
                  use_arrow_keys = "true";
                };
              }
            )
            [
              "left"
              "down"
              "up"
              "right"
            ];
        shared_except = {
          _args = [
            "locked"
            "renametab"
          ];
          _children = [ (bind [ "Esc" "Ctrl c" "Alt g" ] (mode "locked")) ];
        };
      };
    };
  };

  # Only Fish knows whether the command line is empty. Everything after
  # this hand-off is handled by Zellij's native modes.
  programs.fish.functions.__zellij_space = /* fish */ ''
    if set -q ZELLIJ; and test -z "$(commandline)"; and not commandline --paging-mode
      ${lib.getExe config.programs.zellij.package} action switch-mode normal
    else if test "$fish_bind_mode" = default
      commandline -f forward-char
    else
      commandline --insert ' '
      commandline -f expand-abbr
      if test "$(commandline)" = "g "
        commandline ""
        __zoxide_zi
      end
    end
    commandline -f repaint
  '';
  programs.fish.interactiveShellInit = lib.mkAfter /* fish */ ''
    bind -M insert space __zellij_space
    bind -M default space __zellij_space
  '';

  # Named Unix sockets need a short path on macOS (its TMPDIR is long).
  home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    ZELLIJ_SOCKET_DIR = "/tmp/zellij-${config.home.username}";
  };
}
