{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  plugin = import ./zellij/plugin.nix { inherit pkgs; };
  anon = plugin ./zellij/anon;
  hints = plugin ./zellij/hints;
  finder = scope: {
    _props.location = "file:${plugin ./zellij/finder}/bin/zellij-finder.wasm";
    inherit scope;
  };
  zellij = lib.getExe config.programs.zellij.package;
  # Shells keep the ZELLIJ_SESSION_NAME they started with, so a rename
  # leaves a forwarding note: old name -> new name.
  renamed = "${config.xdg.stateHome}/zellij/renamed";
  renameSession = pkgs.writeText "zellij-rename-session.fish" /* fish */ ''
    while read --local --prompt-str 'Session name: ' name
      test -z "$name"; and break
      if string match --quiet '*/*' -- "$name"
        echo 'Session names cannot contain /.' >&2
        continue
      end
      if contains -- "$name" (${zellij} list-sessions -sn)
        echo 'A session by this name already exists.' >&2
        continue
      end
      ${zellij} action rename-session "$name"; or continue
      mkdir -p ${renamed}
      echo $name >${renamed}/$ZELLIJ_SESSION_NAME
      rm -f ${renamed}/$name # no forwarding loops
      break
    end
  '';
  # Quitting ends the session for every client: named sessions ask first,
  # anonymous ones (anon-*, which go away on detach anyway) don't.
  quitSession = pkgs.writeText "zellij-quit-session.fish" /* fish */ ''
    if not string match --quiet 'anon-*' -- $ZELLIJ_SESSION_NAME
      read --local --nchars 1 --prompt-str "Quit session $ZELLIJ_SESSION_NAME? [y/N] " answer
      or exit
      contains -- "$answer" y Y; or exit
    end
    ${zellij} kill-session $ZELLIJ_SESSION_NAME
  '';
  # A fish script in a small floating pane, for a prompt.
  prompt = name: script: {
    Run = {
      _args = [
        (lib.getExe config.programs.fish.package)
        "--no-config"
        (toString script)
      ];
      floating = true;
      inherit name;
      width = "60%";
      height = "5";
      close_on_exit = true;
    };
  };
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
  programs = {
    # Naming only: the background plugin owns cleanup when the last client leaves.
    fish.functions.anon-zellij = {
      description = "Start an anonymous Zellij session";
      wraps = "zellij";
      body = /* fish */ ''
        ${zellij} --session "anon-$(${lib.getExe pkgs.rust-petname} --words 2)" $argv
      '';
    };

    # `zellij action` hangs on a missing session, so check first and follow
    # renames. Fails if this shell's session is gone.
    fish.functions.__zellij_session = /* fish */ ''
      set -l sessions (${zellij} list-sessions -sn 2>/dev/null)
      while not contains -- "$ZELLIJ_SESSION_NAME" $sessions
        test -r ${renamed}/$ZELLIJ_SESSION_NAME; or return 1
        set -gx ZELLIJ_SESSION_NAME (cat ${renamed}/$ZELLIJ_SESSION_NAME)
      end
    '';

    zellij = {
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
              plugin location="hints"
            }
          }
        }
      '';
      settings = {
        default_mode = "locked";
        nested_session_handling = "descend";
        default_layout = "compact";
        theme = "rose-pine-dawn";
        show_startup_tips = false;
        show_release_notes = false;
        on_force_close = "detach";
        session_serialization = false;
        plugins = {
          compact-bar._props.location = "zellij:compact-bar";
          hints._props.location = "file:${hints}/bin/zellij-hints.wasm";
          hints-controller = {
            _props.location = "file:${hints}/bin/zellij-hints.wasm";
            controller = true;
          };
          anon._props.location = "file:${anon}/bin/zellij-anon.wasm";
          new-session = manager {
            multi_screen = false;
          };
          # Fuzzy finders (zellij/finder): each word of the query matches
          # somewhere, so `nix edit` finds the tab edit in the session nix.
          find = finder "all"; # every session's tabs
          find-sessions = finder "sessions";
          find-tabs = finder "tabs"; # this session's
        };
        load_plugins = {
          hints-controller = { };
          # Runs in the server, including after the last client disconnects.
          anon = { };
        };
        keybinds = {
          _props.clear-defaults = true;
          locked._children = [ (bind "Alt g" (mode "normal")) ];
          normal._children = [
            (bind "s" (mode "session"))
            (bind "t" (mode "tab"))
            (bind "p" (mode "pane"))
            (once "Space" (launch "find"))
          ];
          session._children = [
            (once "n" (launch "new-session"))
            (once "q" (prompt "Quit session" quitSession))
            (once "d" { Detach = { }; })
            # Vim-style: [ back towards the root session, ] forward into the nested one.
            (once "[" { FocusHostSession = { }; })
            (once "]" { FocusGuestSession = { }; })
            (once "z" { ToggleHostFullscreen = { }; })
            (once "f" (launch "find-sessions"))
            (once "r" (prompt "Rename session" renameSession))
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
            (once "f" (launch "find-tabs"))
          ];
          renametab._children = [
            (bind "Enter" (mode "locked"))
            (once [ "Esc" "Ctrl c" "Alt g" ] { UndoRenameTab = { }; })
          ];
          pane._children = [
            (once "h" { NewPane = "Right"; })
            (once "v" { NewPane = "Down"; })
            (once "d" { CloseFocus = { }; })
            (once "e" { EditScrollback = { }; })
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
  };

  # Socket paths max out at 104 bytes, and macOS's long TMPDIR leaves ~24
  # for the session name.
  home.sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    ZELLIJ_SOCKET_DIR = "${config.xdg.cacheHome}/zellij-sockets";
  };
}
