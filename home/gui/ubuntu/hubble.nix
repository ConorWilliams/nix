{ lib, ... }:

{
  imports = [ ./. ]; # the Ubuntu layer.

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
    # US keyboard here; the machine's default (for all accounts) is UK.
    {
      command = "setxkbmap -layout us -model pc104";
      always = true;
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
