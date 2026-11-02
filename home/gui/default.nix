# GUI layer: machines with a screen, on any OS. Adds the
# terminal's config and font on top of the server layer.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../. ]; # the server layer

  # Each machine's font sizes, set in its own file (e.g. ubuntu/hubble.nix;
  # the i3 bar's is in the Ubuntu layer).
  options.desktop = {
    fontSize = lib.mkOption {
      type = lib.types.number;
      default = 20;
      description = "Font size of the terminal (kitty), and on Linux the launcher (rofi) and notifications (dunst).";
    };
  };

  config = {
    # kitty's config. The app itself is installed outside Nix, because a
    # Nix-built kitty can't use Ubuntu's graphics drivers.
    programs.kitty = {
      enable = true;
      package = null;
      font = {
        name = "CaskaydiaCove Nerd Font";
        size = config.desktop.fontSize;
        package = pkgs.nerd-fonts.caskaydia-cove; # installs the font too
      };
      themeFile = "rose-pine-dawn"; # kitty's official port of the theme
      settings.hide_window_decorations = "titlebar-only";
    };
  };
}
