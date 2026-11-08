_:

let
  # i3 doesn't apply GNOME's touchpad settings, so set them with xinput.
  touchpad = prop: value: {
    command = /* bash */ ''xinput --set-prop "ELAN0676:00 04F3:3195 Touchpad" "libinput ${prop}" ${value}'';
    always = true;
    notification = false;
  };
in
{
  imports = [ ./. ];

  desktop.fontSize = 18;

  xsession.windowManager.i3.config.startup = [
    # Trackpad settings
    (touchpad "Scrolling Pixel Distance" "30")
    (touchpad "Natural Scrolling Enabled" "1")
    (touchpad "Tapping Enabled" "1")
    # Caps Lock is Escape
    {
      command = "setxkbmap -option caps:escape";
      always = true;
      notification = false;
    }
  ];
}
