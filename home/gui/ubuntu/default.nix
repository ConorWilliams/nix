{ lib, pkgs, ... }:

let
  mod = "Mod1"; # Alt.
in
{
  imports = [ ../. ]; # the GUI layer

  # Non-NixOS Linux: lets the desktop (e.g. rofi's app list) find apps and
  # icons installed by Nix, and programs find Ubuntu's terminfo too.
  targets.genericLinux.enable = true;
  # ...but not its GPU drivers for Nix programs (GUI apps stay with apt;
  # README), which would also print a setup notice on every switch.
  targets.genericLinux.gpu.enable = false;

  # Desktop notifications (notify-send, Slack...): nothing shows them under
  # i3, so dunst from Nix, started by the first notification.
  services.dunst.enable = true;

  # kitty comes from its own installer.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

  # Helpers i3 uses. None draw with OpenGL, so Nix builds work on Ubuntu.
  home.packages = with pkgs; [
    rofi
    dex # starts the desktop's autostart apps (startup line below)
    xss-lock # locks the screen on suspend (lid close)
    scrot
    xclip
    arandr
  ];

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      terminal = "kitty";
      menu = "rofi -show run";

      # mkOptionDefault: add to i3's default keys rather than replace them.
      keybindings = lib.mkOptionDefault {
        "${mod}+o" = "exec kitty yazi";
        "${mod}+n" = "exec i3lock -c 000000";
        "${mod}+Shift+less" = "move workspace to output left";
        "${mod}+Shift+greater" = "move workspace to output right";
        "--release ${mod}+p" =
          "exec --no-startup-id sh -c 'mkdir -p ~/Pictures && scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png'";
      };

      startup = [
        # Apps from the desktop's autostart folders (network applet etc.).
        {
          command = "dex --autostart --environment i3";
          notification = false;
        }
        {
          command = "xss-lock --transfer-sleep-lock -- i3lock --nofork -c 000000";
          notification = false;
        }
      ];
    };
  };
}
