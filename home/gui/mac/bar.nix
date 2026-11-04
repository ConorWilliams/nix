# The Mac's bar (SketchyBar), at the bottom of every screen like i3's:
# AeroSpace's workspaces on the left, and on the right what i3status shows
# on Linux (volume, the battery, the date and time) with the same icons
# (../icons.nix), in Rose Pine Dawn like the terminals.
{
  config,
  lib,
  pkgs,
  dawn,
  ...
}:

let
  sketchybar = lib.getExe config.programs.sketchybar.finalPackage;
  icons = import ../icons.nix;
  height = config.desktop.barFontSize * 2;
  font = "${config.programs.kitty.font.name}:Regular:${toString (config.desktop.barFontSize * 1.0)}";

  # Rose Pine Dawn (../default.nix) as SketchyBar spells colours: 0xAARRGGBB.
  argb = lib.mapAttrs (_: hex: "0xff" + lib.removePrefix "#" hex) dawn;
  colours = {
    bar = argb.base;
    inherit (argb) text;
    # The workspaces: the focused one outlined in rose (as the official i3
    # port outlines the focused window), one shown on another screen
    # raised, any other muted.
    focused = {
      border = argb.rose;
      background = argb.overlay;
      inherit (argb) text;
    };
    visible = {
      border = argb.overlay;
      background = argb.overlay;
      inherit (argb) text;
    };
    other = {
      border = argb.base;
      background = argb.base;
      text = argb.muted;
    };
  };

  # Each workspace's button: shown if it has windows or is on a screen, on
  # its screen, coloured as in i3. (Called on every workspace and focus
  # change, see AeroSpace's settings below.)
  workspaces = pkgs.writeShellScript "bar-workspaces" ''
    nonempty=$(aerospace list-workspaces --monitor all --empty no)
    args=()
    while read -r ws display focused visible; do
      if [ "$focused" = true ]; then
        c=(${colours.focused.border} ${colours.focused.background} ${colours.focused.text})
      elif [ "$visible" = true ]; then
        c=(${colours.visible.border} ${colours.visible.background} ${colours.visible.text})
      elif grep -qx "$ws" <<<"$nonempty"; then
        c=(${colours.other.border} ${colours.other.background} ${colours.other.text})
      else
        args+=(--set "space.$ws" drawing=off)
        continue
      fi
      args+=(--set "space.$ws" drawing=on display="$display"
        background.border_color="''${c[0]}" background.color="''${c[1]}" label.color="''${c[2]}")
    done < <(aerospace list-workspaces --all --format \
      '%{workspace} %{monitor-appkit-nsscreen-screens-id} %{workspace-is-focused} %{workspace-is-visible}')
    sketchybar "''${args[@]}"
  '';

  # The volume's icon by level, and its percentage (0 when muted). The
  # first time, before any change, it asks macOS.
  volume = pkgs.writeShellScript "bar-volume" ''
    vol=''${INFO:-$(osascript -e 'output volume of (get volume settings)')}
    case $vol in
    0) icon=${icons.muted} ;;
    [0-9] | [1-2][0-9]) icon=${icons.volumeLow} ;;
    [3-5][0-9]) icon=${icons.volumeMedium} ;;
    *) icon=${icons.volume} ;;
    esac
    sketchybar --set "$NAME" icon="$icon" label="$vol%"
  '';

  # The battery's icon (charging, on power when full, or else its level),
  # and its percentage; nothing without a battery.
  battery = pkgs.writeShellScript "bar-battery" ''
    line=$(pmset -g batt | grep -m1 InternalBattery) || {
      sketchybar --set "$NAME" drawing=off
      exit 0
    }
    percent=$(grep -Eo '[0-9]+%' <<<"$line")
    levels=(${lib.concatStringsSep " " icons.batteryLevels} ${icons.battery})
    case $line in
    *discharging*) icon=''${levels[$(((''${percent%\%} - 1) / 10))]} ;;
    *charged* | *"not charging"*) icon=${icons.plugged} ;;
    *) icon=${icons.charging} ;;
    esac
    sketchybar --set "$NAME" drawing=on icon="$icon" label="$percent"
  '';
in
{
  programs.sketchybar = {
    enable = true; # and started at login (launchd)
    extraPackages = [ config.programs.aerospace.package ];
    config = ''
      sketchybar --bar position=bottom height=${toString height} color=${colours.bar} \
        padding_left=0 padding_right=8 sticky=on

      sketchybar --default icon.font="${font}" label.font="${font}" \
        icon.color=${colours.text} label.color=${colours.text} \
        icon.padding_right=6 padding_left=8 padding_right=8

      # Workspaces, in i3's order (1-9, then 0). One hidden item updates
      # them all when AeroSpace says something changed.
      sketchybar --add event aerospace_workspace_change
      ${lib.concatMapStrings (ws: ''
        sketchybar --add item space.${ws} left --set space.${ws} label=${ws} drawing=off icon.drawing=off \
          padding_left=0 padding_right=0 label.padding_left=8 label.padding_right=8 \
          background.height=${toString height} background.border_width=2 \
          click_script="aerospace workspace ${ws}"
      '') (import ../keys.nix).workspaces}
      sketchybar --add item workspaces left \
        --set workspaces drawing=off updates=on script=${workspaces} \
        --subscribe workspaces aerospace_workspace_change display_change system_woke

      # The status, from the right.
      sketchybar --add item clock right \
        --set clock update_freq=10 icon.drawing=off script='sketchybar --set clock label="$(date "+%Y-%m-%d %a %H:%M")"'
      sketchybar --add item battery right \
        --set battery update_freq=60 script=${battery} \
        --subscribe battery power_source_change system_woke
      sketchybar --add item volume right --set volume script=${volume} \
        --subscribe volume volume_change

      sketchybar --update
      sketchybar --trigger aerospace_workspace_change
    '';
  };

  # Picks up a new config on each switch.
  xdg.configFile."sketchybar/sketchybarrc".onChange = "${sketchybar} --reload 2>/dev/null || true";

  programs.aerospace.settings = {
    # Windows stop above the bar.
    gaps.outer.bottom = height;
    # Tells the bar to redraw the workspaces: on switching workspace, and on
    # focus moving (a window moved or closed, so one may now be empty).
    exec-on-workspace-change = [
      sketchybar
      "--trigger"
      "aerospace_workspace_change"
    ];
    on-focus-changed = [ "exec-and-forget ${sketchybar} --trigger aerospace_workspace_change" ];
  };
}
