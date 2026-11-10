{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  plugin = import ./zellij/plugin.nix { inherit pkgs; };
  # The plugins, at fixed paths that link to the current builds: Zellij keys
  # permissions, and saved sessions name plugins, by path. A store path
  # would need a new grant after each rebuild, and pin old builds (soon
  # garbage collected) in saved sessions.
  wasm = {
    zellij-hints = "${plugin ./zellij/hints}/bin/zellij-hints.wasm";
    zellij-finder = "${plugin ./zellij/finder}/bin/zellij-finder.wasm";
    vim-zellij-navigator = "${pkgs.zellijPlugins.vim-zellij-navigator}";
  };
  pluginPath = name: "${config.xdg.dataHome}/zellij/plugins/${name}.wasm";
  finder = scope: {
    _props.location = "file:${pluginPath "zellij-finder"}";
    inherit scope;
  };
  zellij = lib.getExe config.programs.zellij.package;
  fish = lib.getExe config.programs.fish.package;
  # What a resurrected pane runs, a script named after the tool: the tool
  # (with `defaults` if given no arguments) in the folder's direnv
  # environment, as from the shell, unless its .envrc is blocked; then a
  # plain shell. The name is what Zellij reports for the pane (through the
  # discovery hook, below), and vim-zellij-navigator forwards Ctrl+arrows
  # only to nvim.
  resume =
    tool: defaults:
    "${
      pkgs.writeShellScriptBin tool /* bash */ ''
        [[ $# -gt 0 ]] || set -- ${defaults}
        direnv=${lib.getExe config.programs.direnv.package}
        # Its own job, the terminal's foreground one, as if typed in the
        # shell: Zellij reports and saves a pane's foreground job through
        # the discovery hook, but not the pane's own process.
        set -m
        if "$direnv" exec . true 2>/dev/null; then
          "$direnv" exec . ${tool} "$@"
        else
          ${tool} "$@"
        fi
        exec ${fish}
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
          hints._props.location = "file:${pluginPath "zellij-hints"}";
          hints-controller = {
            _props.location = "file:${pluginPath "zellij-hints"}";
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
                    _args = [ "file:${pluginPath "vim-zellij-navigator"}" ];
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

  xdg.dataFile = lib.mapAttrs' (
    name: source: lib.nameValuePair "zellij/plugins/${name}.wasm" { inherit source; }
  ) wasm;

  home = {
    # Grant the plugins what they ask for, once: their paths are fixed, so
    # these entries are too. Added to Zellij's permissions.kdl if missing; the
    # file stays Zellij's (writable) for anything else it grants.
    activation.zellijPermissions =
      let
        file =
          if pkgs.stdenv.hostPlatform.isDarwin then
            "${config.home.homeDirectory}/Library/Caches/org.Zellij-Contributors.Zellij/permissions.kdl"
          else
            "${config.xdg.cacheHome}/zellij/permissions.kdl";
        grants = {
          zellij-hints = [
            "ReadApplicationState"
            "ChangeApplicationState"
            "MessageAndLaunchOtherPlugins"
          ];
          zellij-finder = [
            "ReadApplicationState"
            "ChangeApplicationState"
          ];
          vim-zellij-navigator = [
            "ReadApplicationState"
            "ChangeApplicationState"
            "WriteToStdin"
          ];
        };
        add =
          name: permissions:
          let
            entry = pkgs.writeText "zellij-permission-${name}.kdl" ''
              "${pluginPath name}" {
              ${lib.concatMapStrings (p: "    ${p}\n") permissions}}
            '';
          in
          ''
            if ! grep -qF ${lib.escapeShellArg ''"${pluginPath name}"''} ${lib.escapeShellArg file}; then
              run tee -a ${lib.escapeShellArg file} <${entry} >/dev/null
            fi
          '';
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        ''
          run mkdir -p ${lib.escapeShellArg (dirOf file)}
          run touch ${lib.escapeShellArg file}
          run chmod u+w ${lib.escapeShellArg file}
        ''
        + lib.concatStrings (lib.mapAttrsToList add grants)
      );

    # restart-zellij: restart every live session under the current
    # config (after a switch that changes what a running session can't pick up:
    # plugin aliases, options). Each session's layout is saved, the session
    # ended, and the layout put where Zellij keeps exited sessions, to bring
    # back with `zellij attach NAME` (or s n); what ran in a pane waits for
    # Enter. Copies go to ~/zellij-layouts-<date>/. Run it outside Zellij: it
    # ends every session, and whatever runs in them.
    packages = [
      (pkgs.writeShellApplication {
        name = "restart-zellij";
        runtimeInputs = [
          config.programs.zellij.package
        ];
        text = ''
          if [[ -n ''${ZELLIJ:-} ]]; then
            echo 'Run this from a terminal outside Zellij: it ends every session.' >&2
            exit 1
          fi
          sessions=${
            if pkgs.stdenv.hostPlatform.isDarwin then
              "${config.home.homeDirectory}/Library/Caches/org.Zellij-Contributors.Zellij"
            else
              "${config.xdg.cacheHome}/zellij"
          }/contract_version_1/session_info

          mapfile -t live < <(zellij list-sessions --no-formatting 2>/dev/null | grep -v EXITED | cut -d' ' -f1)
          if ((''${#live[@]} == 0)); then
            echo 'No live sessions.'
            exit 0
          fi

          backup=$HOME/zellij-layouts-$(date +%F-%H%M%S)
          mkdir -p "$backup"
          for s in "''${live[@]}"; do
            zellij --session "$s" action dump-layout >"$backup/$s.kdl"
            echo "saved $s ($(grep -c '^    tab ' "$backup/$s.kdl") tabs)"
          done

          read -r -p "End these ''${#live[@]} sessions now? [y/N] " answer
          if [[ $answer != [yY] ]]; then
            echo "Nothing ended; layouts are in $backup"
            exit 0
          fi

          for s in "''${live[@]}"; do
            zellij kill-session "$s"
          done
          # Ending a session clears or rewrites its folder in the cache, so
          # wait for it to end first (it may stay listed, as EXITED, if it
          # saved itself).
          for s in "''${live[@]}"; do
            for _ in $(seq 50); do
              zellij list-sessions --no-formatting 2>/dev/null | grep "^$s " | grep -qv EXITED || break
              sleep 0.2
            done
            sleep 0.5
            mkdir -p "$sessions/$s"
            cp "$backup/$s.kdl" "$sessions/$s/session-layout.kdl"
          done

          echo
          zellij list-sessions --no-formatting
          echo
          echo "Bring one back with: zellij attach NAME (or s n in Zellij)."
          echo "Layouts are also in $backup"
        '';
      })
    ];

    # Socket paths max out at 104 bytes, and macOS's long TMPDIR leaves ~24
    # for the session name.
    sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      ZELLIJ_SOCKET_DIR = "${config.xdg.cacheHome}/zellij-sockets";
    };
  };
}
