{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

let
  keyHints = import ./zellij/key-hints.nix { inherit pkgs; };

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
      keybinds = {
        _props.clear-defaults = true;
        locked._children = [
          {
            bind = {
              _args = [ "Alt g" ];
              SwitchToMode = "normal";
            };
          }
        ];
        shared_except = {
          _args = [ "locked" ];
          _children = [
            {
              bind = {
                _args = [
                  "Esc"
                  "Ctrl c"
                  "Alt g"
                ];
                SwitchToMode = "locked";
              };
            }
          ];
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
