{ lib, pkgs, ... }:

let
  mod = "Mod1"; # Alt.
in
{
  imports = [ ../. ]; # the GUI layer

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

  # i3 from Nix: same version on hubble and luna. Unlike kitty it needs no
  # graphics drivers (plain X11). The login screen's "i3" session runs it.
  # Everything not set here is i3's stock default: mod+arrows to focus,
  # mod+shift+arrows to move, mod+1..0 for workspaces, mod+r to resize...
  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      terminal = "kitty";
      menu = "rofi -show run";

      # mkOptionDefault: add to i3's default keys rather than replace them.
      keybindings = lib.mkOptionDefault {
        "${mod}+o" = "exec kitty yazi";
        "${mod}+n" = "exec i3lock -d -c000000";
        "${mod}+Shift+less" = "move workspace to output left";
        "${mod}+Shift+greater" = "move workspace to output right";
        # Print: drag to select an area (click for one window) -> ~/Pictures.
        # --release: scrot can only grab the mouse once the key is let go.
        "--release Print" =
          "exec --no-startup-id sh -c 'mkdir -p ~/Pictures && scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png'";
      };

      startup = [
        # Apps from the desktop's autostart folders (network applet etc.).
        {
          command = "dex --autostart --environment i3";
          notification = false;
        }
        {
          command = "xss-lock --transfer-sleep-lock -- i3lock --nofork";
          notification = false;
        }
      ];
    };
  };
}
