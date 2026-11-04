# The Mac's bar (SketchyBar), at the bottom of every screen like i3's:
# AeroSpace's workspaces on the left, and on the right what i3status shows
# on Linux (volume, memory, the battery, the date and time), in Rose Pine
# Dawn like the terminals.
{
  config,
  lib,
  pkgs,
  dawn,
  ...
}:

let
  sketchybar = lib.getExe config.programs.sketchybar.finalPackage;
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
    warning = argb.love; # muted, or memory running out
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

  # "vol 40%", or "muted (40%)" in the warning colour, as i3status shows it.
  volume = pkgs.writeShellScript "bar-volume" ''
    if [ "$SENDER" = volume_change ]; then
      vol=$INFO
    else
      vol=$(osascript -e 'output volume of (get volume settings)')
    fi
    if [ "$(osascript -e 'output muted of (get volume settings)')" = true ]; then
      sketchybar --set "$NAME" label="muted ($vol%)" label.color=${colours.warning}
    else
      sketchybar --set "$NAME" label="vol $vol%" label.color=${colours.text}
    fi
  '';

  # "used | available", as i3status shows it on Linux; under 10% available,
  # a warning instead. Used is what Activity Monitor calls Memory Used: app
  # memory, wired and compressed.
  memory = pkgs.writeShellScript "bar-memory" ''
    page=$(sysctl -n hw.pagesize)
    total=$(sysctl -n hw.memsize)
    vm=$(vm_stat)
    pages() { awk -F: -v k="$1" '$1 == k { gsub(/[ .]/, "", $2); print $2 }' <<<"$vm"; }
    used=$((($(pages 'Anonymous pages') - $(pages 'Pages purgeable') \
      + $(pages 'Pages wired down') + $(pages 'Pages occupied by compressor')) * page))
    available=$((total - used))
    gib() { awk -v b="$1" 'BEGIN { printf "%.1f GiB", b / 1073741824 }'; }
    if ((available * 10 < total)); then
      sketchybar --set "$NAME" label="MEMORY < $(gib "$available")" label.color=${colours.warning}
    else
      sketchybar --set "$NAME" label="$(gib "$used") | $(gib "$available")" label.color=${colours.text}
    fi
  '';

  # "BAT 85% 4:12", as i3status shows it (CHR when charging, FULL when
  # charged); nothing without a battery.
  battery = pkgs.writeShellScript "bar-battery" ''
    line=$(pmset -g batt | grep -m1 InternalBattery) || {
      sketchybar --set "$NAME" drawing=off
      exit 0
    }
    percent=$(grep -Eo '[0-9]+%' <<<"$line")
    case $line in
    *discharging*) status=BAT ;;
    *charged* | *"not charging"*) status=FULL ;;
    *charging* | *"finishing charge"*) status=CHR ;;
    *) status=UNK ;;
    esac
    remaining=$(grep -Eo '[0-9]+:[0-9]+ remaining' <<<"$line" | cut -d' ' -f1)
    [ "$status" = FULL ] && remaining=
    sketchybar --set "$NAME" drawing=on label="$status $percent''${remaining:+ $remaining}"
  '';
in
{
  programs.sketchybar = {
    enable = true; # and started at login (launchd)
    extraPackages = [ config.programs.aerospace.package ];
    config = ''
      sketchybar --bar position=bottom height=${toString height} color=${colours.bar} \
        padding_left=0 padding_right=8 sticky=on

      sketchybar --default icon.drawing=off label.font="${font}" \
        label.color=${colours.text} padding_left=8 padding_right=8

      # Workspaces, in i3's order (1-9, then 0). One hidden item updates
      # them all when AeroSpace says something changed.
      sketchybar --add event aerospace_workspace_change
      ${lib.concatMapStrings (ws: ''
        sketchybar --add item space.${ws} left --set space.${ws} label=${ws} drawing=off \
          padding_left=0 padding_right=0 label.padding_left=8 label.padding_right=8 \
          background.height=${toString height} background.border_width=2 \
          click_script="aerospace workspace ${ws}"
      '') (import ../keys.nix).workspaces}
      sketchybar --add item workspaces left \
        --set workspaces drawing=off updates=on script=${workspaces} \
        --subscribe workspaces aerospace_workspace_change display_change system_woke

      # The status, from the right.
      sketchybar --add item clock right \
        --set clock update_freq=10 script='sketchybar --set clock label="$(date "+%Y-%m-%d %a %H:%M")"'
      sketchybar --add item battery right \
        --set battery update_freq=60 script=${battery} \
        --subscribe battery power_source_change system_woke
      sketchybar --add item memory right --set memory update_freq=5 script=${memory}
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
