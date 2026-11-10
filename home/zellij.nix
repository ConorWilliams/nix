{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  plugins = import ./zellij/plugin.nix { inherit pkgs; };
  # The plugins are at fixed paths, linking to the current builds
  # (xdg.dataFile, below): Zellij keys permissions, and saved sessions name
  # plugins, by path. A store path would need a new grant after each
  # rebuild, and pin old builds (soon garbage collected) in saved sessions.
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
    # A Claude conversation's id, from its command line (see the claude
    # function, in claude.nix). Only a UUID counts, so a prompt's words can't.
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
  renameSession = pkgs.writeText "zellij-rename-session.fish" /* fish */ ''
    while read --local --prompt-str 'Session name: ' name
      set name (string trim -- "$name")
      test -z "$name"; and break
      # (Zellij's own checks, which renaming skips)
      if string match --quiet '*/*' -- "$name"; or contains -- "$name" . ..
        echo 'Not a session name: no /, and not . or ..' >&2
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
        fish
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

  xdg.dataFile = {
    # Resume scripts, where saved sessions find them (resumePath)
    "zellij/bin/nvim".source = lib.getExe (resume "nvim" ''-c "lua require('persistence').load()"'');
    "zellij/bin/claude".source = lib.getExe (resume "claude" "--continue");
    "zellij/bin/codex".source = lib.getExe (resume "codex" "resume --last");
    # Plugins, where the config and permissions find them (pluginPath)
    "zellij/plugins/zellij-hints.wasm".source = "${plugins}/bin/zellij-hints.wasm";
    "zellij/plugins/zellij-finder.wasm".source = "${plugins}/bin/zellij-finder.wasm";
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
    # its own, then ended, to bring back with `zellij attach NAME` (or s n);
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
          echo "Bring one back with: zellij attach NAME (or s n in Zellij)."
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
