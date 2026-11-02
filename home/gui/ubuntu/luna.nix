{ ... }:

let
  # i3 doesn't apply GNOME's touchpad settings, so set them with xinput.
  touchpad = prop: value: {
    command = /* bash */ ''xinput --set-prop "ELAN0676:00 04F3:3195 Touchpad" "libinput ${prop}" ${value}'';
    always = true;
    notification = false;
  };
in
{
  imports = [ ./. ]; # the Ubuntu layer.

  desktop.fontSize = 18; # smaller screen (home/gui/default.nix)

  xsession.windowManager.i3.config.startup = [
    (touchpad "Scrolling Pixel Distance" "30") # half the default scroll speed
    (touchpad "Natural Scrolling Enabled" "1")
    (touchpad "Tapping Enabled" "1")
  ];
}
