{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  anon = import ./zellij/anon { inherit pkgs; };
  keyHints = import ./zellij/key-hints.nix { inherit pkgs; };
  renameSession = pkgs.writeText "zellij-rename-session.fish" /* fish */ ''
    while read --local --prompt-str 'Session name: ' name
      test -z "$name"; and break
      if string match --quiet '*/*' -- "$name"
        echo 'Session names cannot contain /.' >&2
        continue
      end
      if contains -- "$name" (${lib.getExe config.programs.zellij.package} list-sessions -sn)
        echo 'A session by this name already exists.' >&2
        continue
      end
      ${lib.getExe config.programs.zellij.package} action rename-session "$name"; and break
    end
  '';
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
  home.packages = [
    (import ./zellij/anon.nix {
      inherit pkgs;
      zellij = config.programs.zellij.package;
    })
  ];

  programs.zellij = {
    enable = true;
    themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
    # Each tab owns its hints: no cross-tab pane moves, and closing a tab
    # cannot unload the hints in the remaining tabs.
    layouts.compact = /* kdl */ ''
      layout {
        pane
        pane size=1 borderless=true {
          plugin location="compact-bar"
        }
        floating_panes {
          pane {
            plugin location="key-hints"
          }
        }
      }
    '';
    settings = {
      default_mode = "locked";
      default_layout = "compact";
      theme = "rose-pine-dawn";
      show_startup_tips = false;
      show_release_notes = false;
      on_force_close = "detach";
      session_serialization = false;
      plugins.compact-bar._props.location = "zellij:compact-bar";
      plugins.key-hints._props.location = "file:${keyHints}/bin/zellij-key-hints.wasm";
      plugins.key-hints-controller = {
        _props.location = "file:${keyHints}/bin/zellij-key-hints.wasm";
        controller = true;
      };
      load_plugins.key-hints-controller = { };
      # Runs in the server, including after the last client disconnects.
      plugins.anon._props.location = "file:${anon}/bin/zellij-anon.wasm";
      load_plugins.anon = { };
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
          (once "Space" (launch "find-tabs"))
        ];
        session._children = [
          (once "n" (launch "new-session"))
          (once "q" { Quit = { }; })
          (once "f" (launch "find-sessions"))
          (once "r" {
            Run = {
              _args = [
                (lib.getExe config.programs.fish.package)
                "--no-config"
                (toString renameSession)
              ];
              floating = true;
              name = "Rename session";
              width = "60%";
              height = "5";
              close_on_exit = true;
            };
          })
        ];
        tab._children = [
          (bind "r" [
            { TabNameInput = 0; }
            (mode "renametab")
          ])
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
          (once "h" { NewPane = "Right"; })
          (once "v" { NewPane = "Down"; })
          (once "d" { CloseFocus = { }; })
          (bind "r" (mode "resize"))
        ];
        resize._children = map (dir: bind dir { Resize = "Increase ${dir}"; }) [
          "Left"
          "Down"
          "Up"
          "Right"
        ];
        # The navigator forwards Ctrl+arrows to Neovim, otherwise moves panes.
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

  # Named Unix sockets need a short path on macOS (its TMPDIR is long).
  home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    ZELLIJ_SOCKET_DIR = "/tmp/zellij-${config.home.username}";
  };
}
