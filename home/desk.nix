# Extras for machines you sit at, on any OS (hubble, luna, mac).
# Never imported on servers. OS-specific bits go in desk-linux.nix / desk-mac.nix.
{ pkgs, ... }:

{
  home.packages = [
    # OpenAI's coding CLI, from nixpkgs: a few days behind, but prebuilt.
    # Desk only: it pulls in ~1 GiB (GStreamer, for voice features).
    pkgs.codex
  ];

  # kitty's config. The app itself is installed outside Nix (kitty's own
  # installer; see README), because a Nix-built kitty can't use Ubuntu's
  # graphics drivers.
  programs.kitty = {
    enable = true;
    package = null;
    font = {
      name = "CaskaydiaCove Nerd Font";
      size = 20;
      package = pkgs.nerd-fonts.caskaydia-cove; # installs the font too
    };
    themeFile = "rose-pine-dawn"; # kitty's official port of the theme
    settings.hide_window_decorations = "titlebar-only";
  };

  # Lets every app (not just Nix ones) find fonts installed by Nix.
  fonts.fontconfig.enable = true;
}
