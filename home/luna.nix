# luna only: tweaks for the laptop.
{ ... }:

let
  # i3 doesn't apply GNOME's touchpad settings, so set them with xinput.
  touchpad = prop: value: {
    command = ''xinput --set-prop "ELAN0676:00 04F3:3195 Touchpad" "libinput ${prop}" ${value}'';
    always = true;
    notification = false;
  };
in
{
  programs.kitty.font.size = 18; # smaller screen than hubble's

  xsession.windowManager.i3.config.startup = [
    (touchpad "Scrolling Pixel Distance" "30") # half the default scroll speed
    (touchpad "Natural Scrolling Enabled" "1")
    (touchpad "Tapping Enabled" "1")
  ];
}
