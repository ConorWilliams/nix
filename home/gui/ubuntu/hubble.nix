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
  imports = [ ./. ];

  desktop.fontSize = 16;
  desktop.barFontSize = 16;

  xsession.windowManager.i3.config = {
    # Thicker window borders than i3's default 2px
    window.border = 5;
    floating.border = 5;

    startup = [
      # Set up the monitors
      {
        command = lib.concatStringsSep " " [
          "xrandr"
          "--output HDMI-1-0 --mode 2560x1440 --pos 0x565 --rotate left"
          "--output HDMI-1-1 --primary --mode 3840x2160 --pos 1440x0 --rotate left"
          "--output DP-1 --mode 2560x1440 --pos 3600x565 --rotate left"
        ];
        notification = false;
      }

      # Set US keyboard on plug
      {
        command = "${lib.getExe pkgs.inputplug} -0 -c ${usKeyboard}";
        notification = false;
      }

      # Speed up the Logitech mouse.
      {
        command = /* bash */ ''xinput --set-prop "Logitech USB Receiver Mouse" "libinput Accel Speed" 1'';
        always = true;
        notification = false;
      }
    ];
  };
}
