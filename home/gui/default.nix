# GUI layer: machines with a screen, on any OS, on top of the server layer:
# the terminal (kitty) and its font, disposable or named Zellij sessions, and
# zzh/zosh opening a window of their own from inside Zellij.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  zellijTerminal = pkgs.writeShellApplication {
    name = "zellij-terminal";
    runtimeInputs = [
      config.programs.zellij.package
      pkgs.coreutils
    ];
    text = ''
      unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID
      session="anonymous-$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
      trap 'zellij kill-session "$session" >/dev/null 2>&1 || true' EXIT
      trap 'exit' HUP INT TERM
      zellij --session "$session"
    '';
  };
in
{
  imports = [
    ../. # the server layer
    # The terminal's font size, set per machine (e.g. ubuntu/hubble.nix; the
    # i3 bar's is in the Ubuntu layer).
    {
      options.desktop.fontSize = lib.mkOption {
        type = lib.types.number;
        default = 20;
        description = "Font size of the terminal (kitty), and on Linux the launcher (rofi) and notifications (dunst).";
      };
    }
  ];

  # kitty's config. The app itself is installed outside Nix: on Ubuntu,
  # because a Nix-built kitty can't use its graphics drivers; on the Mac,
  # as a Homebrew cask (darwin/default.nix).
  programs.kitty = {
    enable = true;
    package = null;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = config.desktop.fontSize;
      package = pkgs.nerd-fonts.caskaydia-cove; # installs the font too
    };
    settings.confirm_os_window_close = 0;
    settings.shell = lib.getExe zellijTerminal;
    themeFile = "rose-pine-dawn"; # kitty's official port of the theme
  };

  # Named sessions detach. The launcher cleans up only the anonymous name
  # it created; renaming that session makes it survive window closure.
  programs.zellij.settings = {
    on_force_close = "detach";
    session_serialization = false; # no exited-session resurrection list
  };

  # zzh/zosh (home/shell.nix) from inside zellij, at the machine's own
  # screen (not over ssh): run again in a kitty window of their own,
  # outside zellij, rather than refuse. (On the Mac, `open` starts kitty
  # without this shell's environment, so fish by its full path; it clears
  # zellij's variables itself, as Linux's kitty does inherit them.) In
  # that window, an error (e.g. no zellij on the host) would close it
  # before it could be read: wait for Enter first.
  programs.fish.functions = lib.genAttrs [ "zzh" "zosh" ] (
    name:
    let
      isMac = pkgs.stdenv.hostPlatform.isDarwin;
      atScreen =
        if isMac then "not set -q SSH_CONNECTION" else "set -q DISPLAY; and not set -q SSH_CONNECTION";
      newWindow = if isMac then "open -na kitty --args" else "kitty --detach";
    in
    {
      body = lib.mkMerge [
        (lib.mkBefore /* fish */ ''
          if set -q ZELLIJ; and ${atScreen}
            ${newWindow} ${lib.getExe config.programs.fish.package} -c \
              "set -e ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID; set -gx ZZH_OWN_WINDOW 1; "(string join ' ' -- ${name} (string escape -- $argv))
            return
          end
        '')
        (lib.mkAfter /* fish */ ''
          set -l code $status
          if set -q ZZH_OWN_WINDOW; and test $code -ne 0
            read -P "${name}: exited with status $code; press Enter to close " -l reply
          end
          return $code
        '')
      ];
    }
  );
}
