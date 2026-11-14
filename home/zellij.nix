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
    zellij = {
      enable = true;
      themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-zellij}/dist/rose-pine-dawn.kdl";
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
          # The menu of a mode's keys (zellij/hints): the controller, in the
          # background, opens `hints` as a popup.
          hints._props.location = "file:${pluginPath "zellij-hints"}";
          hints-controller = {
            _props.location = "file:${pluginPath "zellij-hints"}";
            controller = true;
          };
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

    # Socket paths max out at 104 bytes, and macOS's long TMPDIR leaves ~24
    # for the session name.
    sessionVariables = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      ZELLIJ_SOCKET_DIR = "${config.xdg.cacheHome}/zellij-sockets";
    };
  };
}
