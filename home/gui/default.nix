# GUI layer: machines with a screen, on any OS, on top of the server layer:
# the terminal (kitty) and its font, with an anonymous Zellij session per window.
{
  config,
  lib,
  pkgs,
  ...
}:

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
    # A new terminal window is independent, even if launched from a Zellij pane.
    # Clear inherited session/pane identity here; direct calls may intentionally nest.
    settings.shell = "env -u ZELLIJ -u ZELLIJ_SESSION_NAME -u ZELLIJ_PANE_ID ${lib.getExe config.programs.fish.package} -c anon-zellij";
    themeFile = "rose-pine-dawn"; # kitty's official port of the theme
  };
}
