{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  plugins = import ./zellij/plugin.nix {
    inherit lib pkgs;
    zellij = config.programs.zellij.package;
  };
  # The plugins are at fixed paths, linking to the current builds
  # (xdg.dataFile, below): Zellij keys permissions, and saved sessions name
  # plugins, by path. A store path would need a new grant after each
  # rebuild, and pin old builds (soon garbage collected) in saved sessions.
  pluginPath = name: "${config.xdg.dataHome}/zellij/plugins/${name}.wasm";
  fish = lib.getExe config.programs.fish.package;
  # What a resurrected pane runs, a script named after the tool: the tool
  # (with `defaults` if given no arguments) in the folder's direnv
  # environment, as from the shell, unless its .envrc is blocked; then a
  # plain shell. The name is what Zellij reports for the pane (through the
  # discovery hook, below), and vim-zellij-navigator forwards Ctrl+arrows
  # only to nvim.
  resume =
    tool: defaults:
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
      # Suspended (Ctrl-Z)? There is no shell here to suspend to, and going
      # on would leave the tool behind, stopped: resume it. (Recursion, not
      # a loop: bash breaks out of a loop whose job is suspended. fg's
      # stderr stays the terminal: bash hands that to the job.)
      unsuspend() { if [[ -n $(jobs -ps) ]]; then fg >/dev/null; unsuspend; fi; }
      unsuspend
      exec ${fish}
    '';
  # Resume scripts are at fixed paths too (xdg.dataFile, below), which saved
  # sessions name: a store path would soon be garbage collected.
  resumePath = tool: "${config.xdg.dataHome}/zellij/bin/${tool}";
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
    # A Claude conversation's id, from its command line (a resurrected
    # pane's has one). Only a UUID counts, so a prompt's words can't.
    uuid='[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    id=
    if [[ $RESURRECT_COMMAND =~ (^| )(--session-id|--resume|-r)[\ =]($uuid)( |$) ]]; then
      id="--resume ''${BASH_REMATCH[3]}"
    fi
    # Print mode isn't a conversation to come back to.
    if [[ $name == claude && $RESURRECT_COMMAND =~ (^| )(-p|--print)( |$) ]]; then
      name=
    fi
    case $name in
      nvim) echo ${resumePath "nvim"} ;;
      claude) echo ${resumePath "claude"} $id ;;
      codex) echo ${resumePath "codex"} ;;
      *) echo ${fish} ;;
    esac
  '';
  # Claude's SessionStart and SessionEnd hooks: a pane running Claude tells
  # Zellij what to resurrect it with, the conversation it's in now (which
  # /resume and /clear change, and the command line doesn't show). Cleared
  # when Claude exits, so the pane is a shell again; the discovery hook
  # still covers a pane this didn't reach (its Claude killed, say).
  claudeResurrect = pkgs.writeShellApplication {
    name = "zellij-claude-resurrect";
    runtimeInputs = [
      pkgs.jq
      config.programs.zellij.package
    ];
    text = ''
      [[ -n ''${ZELLIJ:-} && -n ''${ZELLIJ_PANE_ID:-} ]] || exit 0
      IFS=$'\t' read -r event id reason < <(jq -r '[.hook_event_name, .session_id, .reason // "-"] | @tsv')
      case $event in
        SessionStart)
          [[ -n $id ]] || exit 0
          zellij action set-resurrect-command -- ${resumePath "claude"} --resume "$id"
          ;;
        # (not between conversations: the next one's start may come first)
        SessionEnd)
          [[ $reason == clear || $reason == resume ]] || zellij action set-resurrect-command --clear
          ;;
      esac
    '';
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
    claude-code.settings.hooks =
      let
        hook = [
          {
            hooks = lib.singleton {
              type = "command";
              command = lib.getExe claudeResurrect;
            };
          }
        ];
      in
      {
        SessionStart = hook;
        SessionEnd = hook;
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
        # Panes start fish itself, not $SHELL's hand-off to it: a pane that's
        # just the shell is then saved as one, not as a command to re-run.
        default_shell = fish;
        # Exited sessions can be resurrected (s m), each pane in its folder;
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
          quit._props.location = "file:${pluginPath "zellij-quit"}";
          # New sessions, and exited ones to resurrect (the finder has only live ones).
          sessions = manager {
            multi_screen = false;
          };
          # Fuzzy finder (zellij/finder) for every session's tabs: each word
          # of the query matches somewhere, so `nix edit` finds the tab edit
          # in the session nix.
          find._props.location = "file:${pluginPath "zellij-finder"}";
        };
        load_plugins = {
          hints-controller = { };
          quit = { };
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
          ];
          session._children = [
            (once "m" (launch "sessions"))
            # s q y: quitting ends the session for every client, so it takes
            # a y to confirm, in a mode of its own (which the hints show).
            (bind "q" (mode "prompt"))
            (once "d" { Detach = { }; })
            # Vim-style: [ back towards the root session, ] forward into the nested one.
            (once "[" { FocusHostSession = { }; })
            (once "]" { FocusGuestSession = { }; })
            (once "z" { ToggleHostFullscreen = { }; })
            # (the mode first: entering it starts the draft that the 0 clears)
            (bind "r" [
              (mode "renamesession")
              { SessionNameInput = 0; }
            ])
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
          # The quit plugin (zellij/quit) saves the session as it is, then
          # ends it: to bring back as restart-zellij's are.
          prompt._children = [
            (once "y" {
              MessagePlugin = {
                _args = [ "quit" ];
                name = "quit";
              };
            })
          ];
          renametab._children = [
            (bind "Enter" (mode "locked"))
            (once [ "Esc" "Ctrl c" "Alt g" ] { UndoRenameTab = { }; })
          ];
          # The name shows in the bar as it's typed, and is checked (no /, not
          # another session's) on Enter.
          renamesession._children = [
            (bind "Enter" (mode "locked"))
            (once [ "Esc" "Ctrl c" "Alt g" ] { UndoRenameSession = { }; })
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
              "renamesession"
            ];
            _children = [ (bind [ "Esc" "Ctrl c" "Alt g" ] (mode "locked")) ];
          };
        };
      };
    };
  };

  xdg.dataFile = {
    # Resume scripts, where saved sessions find them (resumePath)
    "zellij/bin/nvim".source = lib.getExe (resume "nvim" ''-c "lua require('persistence').load()"'');
    "zellij/bin/claude".source = lib.getExe (resume "claude" "--continue");
    "zellij/bin/codex".source = lib.getExe (resume "codex" "resume --last");
    # Plugins, where the config and permissions find them (pluginPath)
    "zellij/plugins/zellij-hints.wasm".source = "${plugins}/bin/zellij-hints.wasm";
    "zellij/plugins/zellij-finder.wasm".source = "${plugins}/bin/zellij-finder.wasm";
    "zellij/plugins/zellij-quit.wasm".source = "${plugins}/bin/zellij-quit.wasm";
    "zellij/plugins/vim-zellij-navigator.wasm".source = pkgs.zellijPlugins.vim-zellij-navigator;
  };

  home = {
    # Grant the plugins what they ask for: their paths are fixed, so these
    # entries are too. Written into Zellij's permissions.kdl (replacing older
    # versions of them); the file stays Zellij's, writable, for anything else
    # it grants.
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
          zellij-quit = [
            "ReadApplicationState"
            "ChangeApplicationState"
          ];
          vim-zellij-navigator = [
            "ReadApplicationState"
            "ChangeApplicationState"
            "WriteToStdin"
          ];
        };
        # Ours as below (replacing any older version), others' as they are.
        keys = pkgs.writeText "zellij-permission-keys" (
          lib.concatMapStrings (name: ''"${pluginPath name}" {'' + "\n") (lib.attrNames grants)
        );
        entries = pkgs.writeText "zellij-permissions.kdl" (
          lib.concatStrings (
            lib.mapAttrsToList (name: permissions: ''
              "${pluginPath name}" {
              ${lib.concatMapStrings (p: "    ${p}\n") permissions}}
            '') grants
          )
        );
      in
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        file=${lib.escapeShellArg file}
        new=$(mktemp)
        if [[ -e $file ]]; then
          ${lib.getExe pkgs.gawk} 'NR == FNR { ours[$0]; next }
            $0 in ours { skip = 1; next }
            skip { if ($0 == "}") skip = 0; next }
            { print }' ${keys} "$file" >"$new"
        fi
        cat ${entries} >>"$new"
        if ! cmp -s "$new" "$file"; then
          run mkdir -p "$(dirname "$file")"
          [[ -e $file ]] && run chmod u+w "$file"
          run cp "$new" "$file"
        fi
        rm -f "$new"
      '';

    # restart-zellij: restart every live session under the current config
    # (after a switch that changes what a running session can't pick up:
    # plugin aliases, options). Each session is saved as Zellij saves it on
    # its own, then ended, to bring back with `zellij attach NAME` (or s m);
    # what ran in a pane waits for Enter. Run it outside Zellij: it ends
    # every session, and whatever runs in them.
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

          # (names can have spaces: drop what follows them, not split on them)
          mapfile -t live < <(zellij list-sessions --no-formatting 2>/dev/null | sed -n '/(EXITED/!s/ \[Created .*//p')
          if ((''${#live[@]} == 0)); then
            echo 'No live sessions.'
            exit 0
          fi

          printf '%s\n' "''${live[@]}"
          read -r -p "Save and end these ''${#live[@]} sessions? [y/N] " answer
          [[ $answer == [yY] ]] || exit 0

          for s in "''${live[@]}"; do
            zellij --session "$s" action save-session
            zellij kill-session "$s"
          done

          echo
          zellij list-sessions --no-formatting
          echo
          echo "Bring one back with: zellij attach NAME (or s m in Zellij)."
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
