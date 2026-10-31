# Linux desks only (hubble, luna): window manager and GUI app config.
# GUI apps themselves come from apt/snap (see README): Nix-built GUI apps
# can't use Ubuntu's graphics drivers.
{ lib, pkgs, ... }:

let
  mod = "Mod1"; # Alt. AeroSpace on the Mac mirrors these keys.
in
{
  # kitty comes from its own installer (see README), into ~/.local/kitty.app.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

  # Locks the screen on suspend (lid close), via the startup line below.
  home.packages = [ pkgs.xss-lock ];

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
