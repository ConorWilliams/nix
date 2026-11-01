# GUI layer: machines you sit at, on any OS (hubble, luna, mac). Adds the
# terminal's config and fonts on top of the server layer.
# OS-specific bits go in ubuntu/ and mac/.
{ lib, pkgs, ... }:

{
  imports = [ ../. ]; # the server layer

  # kitty's config. The app itself is installed outside Nix (kitty's own
  # installer; see README), because a Nix-built kitty can't use Ubuntu's
  # graphics drivers.
  programs.kitty = {
    enable = true;
    package = null;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = lib.mkDefault 20; # ubuntu/luna.nix overrides it
      package = pkgs.nerd-fonts.caskaydia-cove; # installs the font too
    };
    themeFile = "rose-pine-dawn"; # kitty's official port of the theme
    settings.hide_window_decorations = "titlebar-only";
  };

  # Lets every app (not just Nix ones) find fonts installed by Nix.
  fonts.fontconfig.enable = true;
}
