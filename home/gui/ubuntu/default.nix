# Ubuntu layer: Linux desks (hubble, luna). Window manager and GUI app
# config on top of the GUI layer. GUI apps themselves come from apt/snap
# (see README): Nix-built GUI apps can't use Ubuntu's graphics drivers.
{ lib, pkgs, ... }:

let
  mod = "Mod1"; # Alt. AeroSpace on the Mac mirrors these keys.
in
{
  imports = [ ../. ]; # the GUI layer

  # kitty comes from its own installer (see README), into ~/.local/kitty.app.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

  # Helpers i3 uses. None draw with OpenGL, so Nix builds work on Ubuntu.
  # (i3lock stays apt's: a Nix-built screen locker can't use Ubuntu's
  # password checking, so it couldn't unlock.)
  home.packages = with pkgs; [
    rofi # launcher: mod+d
    dex # starts the desktop's autostart apps (startup line below)
    xss-lock # locks the screen on suspend (lid close)
    scrot # screenshots: Print key below, or `scrot` in a terminal
    xclip # terminal <-> X clipboard (also neovim's clipboard on X11)
    arandr # arrange monitors visually (GTK, no OpenGL, so Nix's is fine)
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
