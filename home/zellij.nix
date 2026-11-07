{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  keyHints = import ./zellij/key-hints.nix { inherit pkgs; };
  bind = keys: actions: {
    bind = {
      _args = lib.toList keys;
      _children = lib.toList actions;
    };
  };
  mode = name: { SwitchToMode = name; };
  once =
    keys: action:
    bind keys [
      action
      (mode "locked")
    ];
  manager =
    options:
    {
      _props.location = "zellij:session-manager";
    }
    // options;
  launch = name: {
    LaunchOrFocusPlugin = {
      _args = [ name ];
      floating = true;
      move_to_focused_tab = true;
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
      plugins.key-hints._props.location = "file:${keyHints}/bin/zellij-key-hints.wasm";
      load_plugins.key-hints = { };
      plugins.new-session = manager {
        multi_screen = false;
      };
      plugins.find-tabs = manager { multi_screen = true; };
      plugins.find-sessions = manager { multi_screen = false; };
      keybinds = {
        _props.clear-defaults = true;
        locked._children = [ (bind "Alt g" (mode "normal")) ];
        normal._children = [
          (bind "s" (mode "session"))
          (bind "t" (mode "tab"))
          (bind "p" (mode "pane"))
          # Reuse a native mode for the find prefix; no custom input handling.
          (bind "f" (mode "tmux"))
        ];
        session._children = [
          (once "n" (launch "new-session"))
          (once "d" { Quit = { }; })
        ];
        tab._children = [
          (bind "n" [
            { NewTab = { }; }
            { TabNameInput = 0; }
            (mode "renametab")
          ])
          (once "d" { CloseTab = { }; })
        ];
        renametab._children = [
          (bind "Enter" (mode "locked"))
          (once [ "Esc" "Ctrl c" "Alt g" ] { UndoRenameTab = { }; })
        ];
        pane._children = [
          (once "|" { NewPane = "Right"; })
          (once "-" { NewPane = "Down"; })
          (once "d" { CloseFocus = { }; })
        ];
        tmux._children = [
          (once "t" (launch "find-tabs"))
          (once "s" (launch "find-sessions"))
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
