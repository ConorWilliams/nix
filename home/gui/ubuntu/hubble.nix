{ lib, pkgs, ... }:

let
  # Called by inputplug (below) as: <event> <device id> <device type> <name>
  usKeyboard = pkgs.writeShellScript "us-keyboard" /* bash */ ''
    if [ "$1 $3" = "XIDeviceEnabled XISlaveKeyboard" ]; then
      setxkbmap -layout us -model pc104
    fi
  '';
in
{
  imports = [ ./. ]; # the Ubuntu layer.

  # Thicker window borders than the Ubuntu layer's 2px: on these 4K screens
  # the focused window's thin outline is easy to miss.
  xsession.windowManager.i3.config = {
    window.border = 5;
    floating.border = 5;
    fonts.size = 16.0; # the bar's, 2 up from the Ubuntu layer's
  };

  # i3 startup list (added to the Ubuntu layer's).
  xsession.windowManager.i3.config.startup = [
    # The three desk monitors, as set up in arandr: all portrait, the 4K in
    # the middle, a 1440p either side (565 px lower), the right one primary.
    {
      command = lib.concatStringsSep " " [
        "xrandr"
        "--output HDMI-1-0 --mode 2560x1440 --pos 0x565 --rotate left"
        "--output HDMI-1-1 --primary --mode 3840x2160 --pos 1440x0 --rotate left"
        "--output DP-1 --mode 2560x1440 --pos 3600x565 --rotate left"
      ];
      notification = false;
    }
    # US keyboard here; the machine's default (for all accounts) is UK, and
    # X gives that to every keyboard it (re)connects, e.g. when the monitors
    # (and their USB hubs) wake from sleep. So inputplug sets US each time a
    # keyboard is enabled, and for those already there at login (-0).
    {
      command = "${pkgs.inputplug}/bin/inputplug -0 -c ${usKeyboard}";
      notification = false;
    }
    # Speed up the Logitech mouse.
    {
      command = /* bash */ ''xinput --set-prop "Logitech USB Receiver Mouse" "libinput Accel Speed" 1'';
      always = true;
      notification = false;
    }
  ];
}
