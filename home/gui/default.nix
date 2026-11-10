# GUI layer: machines with a screen, on any OS.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../.
    {
      options.desktop.fontSize = lib.mkOption {
        type = lib.types.number;
        default = 20;
        description = "Font size of the terminal";
      };
    }
  ];

  # kitty's config. The app itself is installed outside Nix
  programs.kitty = {
    enable = true;
    package = null;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = config.desktop.fontSize;
      package = pkgs.nerd-fonts.caskaydia-cove; # installs the font too
    };
    settings.confirm_os_window_close = 0;
    themeFile = "rose-pine-dawn"; # kitty's official port of the theme
  };
}
