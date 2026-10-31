# hubble only: tweaks for this machine's hardware.
{ ... }:

{
  # Speed up hubble's Logitech mouse (added to the i3 startup list).
  xsession.windowManager.i3.config.startup = [
    {
      command = ''xinput --set-prop "Logitech USB Receiver Mouse" "libinput Accel Speed" 1'';
      always = true;
      notification = false;
    }
  ];
}
