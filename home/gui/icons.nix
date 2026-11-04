# The bars' icons, shared by i3status (ubuntu/) and SketchyBar (mac/bar.nix):
# Nerd Font glyphs (Material Design), which the terminal's font includes.
# Each is named as in Nerd Fonts' cheat sheet (nerdfonts.com/cheat-sheet).
{
  volume = "󰕾"; # nf-md-volume_high
  volumeMedium = "󰖀"; # nf-md-volume_medium
  volumeLow = "󰕿"; # nf-md-volume_low
  muted = "󰖁"; # nf-md-volume_off
  charging = "󰂄"; # nf-md-battery_charging
  plugged = "󰚥"; # nf-md-power_plug: on power, not charging (full)
  battery = "󰁹"; # nf-md-battery
  # By charge, 10% to 90% (nf-md-battery_10 ... _90), for bars that can
  # show the level.
  batteryLevels = [
    "󰁺"
    "󰁻"
    "󰁼"
    "󰁽"
    "󰁾"
    "󰁿"
    "󰂀"
    "󰂁"
    "󰂂"
  ];
}
