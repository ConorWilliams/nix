{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  plugin = import ./zellij/plugin.nix { inherit pkgs; };
  hints = plugin ./zellij/hints;
  finder = scope: {
    _props.location = "file:${plugin ./zellij/finder}/bin/zellij-finder.wasm";
    inherit scope;
  };
  zellij = lib.getExe config.programs.zellij.package;
  fish = lib.getExe config.programs.fish.package;
  # What a resurrected pane runs: the tool, with these arguments if given
  # none, in the folder's direnv environment as from the shell (the
  # project's toolchain), unless its .envrc is blocked. It's named after the
  # tool and replaces itself with it: Zellij reports a pane's command through
  # the discovery hook (below), and vim-zellij-navigator forwards Ctrl+arrows
  # only to nvim.
  resume =
    tool: defaults:
    "${
      pkgs.writeShellScriptBin tool /* bash */ ''
        [[ $# -gt 0 ]] || set -- ${defaults}
        direnv=${lib.getExe config.programs.direnv.package}
        if "$direnv" exec . true 2>/dev/null; then
          exec "$direnv" exec . ${tool} "$@"
        fi
        exec ${tool} "$@"
      ''
    }/bin/${tool}";
  # post_command_discovery_hook: given what a pane is running (its arguments
  # joined by spaces), prints what to resurrect there (split on spaces).
  # Only Neovim (with the folder's persistence session) and the agents (with
  # their conversation, else the folder's latest) come back; any other pane
  # is the default shell.
  discoverCommand = pkgs.writeShellScript "zellij-discover-command" /* bash */ ''
    read -r command _ <<<"$RESURRECT_COMMAND"
    name=''${command##*/}
    name=''${name#.}
    name=''${name%%-wrapped*} # Nix wrappers: .foo-wrapped
    # A Claude conversation's id, from its command line (see the claude
    # function below)
    id=
    if [[ $RESURRECT_COMMAND =~ (^| )(--session-id|--resume|-r)\ ([^ ]+) ]]; then
      id="--resume ''${BASH_REMATCH[3]}"
    fi
    case $name in
      nvim) echo ${resume "nvim" ''-c "lua require('persistence').load()"''} ;;
      claude) echo ${resume "claude" "--continue"} $id ;;
      codex) echo ${resume "codex" "resume --last"} ;;
      *) echo ${fish} ;;
    esac
  '';
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
      break
    end
  '';
  # Quitting ends the session for every client, so it asks first.
  quitSession = pkgs.writeText "zellij-quit-session.fish" /* fish */ ''
    read --local --nchars 1 --prompt-str "Quit session $ZELLIJ_SESSION_NAME? [y/N] " answer
    or exit
    contains -- "$answer" y Y; or exit
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
    # In Zellij, a new Claude conversation gets its id on its command line,
    # where Zellij saves it, so a resurrected pane resumes that one.
    fish.functions.claude = {
      wraps = "claude";
      body = /* fish */ ''
        if set -q ZELLIJ; and test (count $argv) -eq 0
          command claude --session-id (${lib.getExe' pkgs.util-linux "uuidgen"})
        else
          command claude $argv
        end
      '';
    };

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
        # Panes start fish itself, not $SHELL's hand-off to it: a pane that's
        # just the shell is then saved as one, not as a command to re-run.
        default_shell = fish;
        # Exited sessions can be resurrected (s n), each pane in its folder;
        # what ran there waits for Enter (discoverCommand above).
        session_serialization = true;
        post_command_discovery_hook = toString discoverCommand;
        plugins = {
          compact-bar._props.location = "zellij:compact-bar";
          hints._props.location = "file:${hints}/bin/zellij-hints.wasm";
          hints-controller = {
            _props.location = "file:${hints}/bin/zellij-hints.wasm";
            controller = true;
          };
          # New sessions, and exited ones to resurrect (the finder has only live ones).
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
        };
        keybinds = {
          _props.clear-defaults = true;
          # Locked (where you type) is the default
          locked._children = [
            (bind "Alt g" (mode "normal"))
            (bind "Alt h" { GoToPreviousTab = { }; })
            (bind "Alt l" { GoToNextTab = { }; })
            (bind "Alt f" (launch "find"))
          ];
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
