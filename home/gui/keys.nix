# The window manager's keys, the same on Linux (i3, leader Alt) and the Mac
# (AeroSpace, leader Cmd): which key each action uses after the leader,
# spelled as i3 spells it. Each layer binds them to its own commands
# (gui/ubuntu/default.nix, gui/mac/default.nix), so a key changes here once.
# None of them is one the Mac's apps can't do without (copy, save, find,
# tabs, quit, Spotlight's Space, Cmd+Tab...).
{ lib }:

{
  keys = {
    terminal = "Return"; # kitty, in its own zellij session
    launcher = "space"; # rofi; on the Mac, Spotlight's own Cmd+Space
    close = "Shift+q";
    fullscreen = "Shift+f";
    floating = "Shift+space"; # floating on/off
    resize = "Shift+r"; # a mode: arrows resize, Esc or Enter leaves
    flipSplit = "e"; # the focused group: side by side <-> stacked
    lock = "n";
    screenshot = "p"; # of a region, into ~/Pictures
    reload = "Shift+c"; # the window manager's config
    monitorLeft = "Shift+less"; # the workspace to the other screen
    monitorRight = "Shift+greater";
  };

  # Focus with the arrows; Shift+arrows moves the window.
  arrows = [
    "Left"
    "Down"
    "Up"
    "Right"
  ];

  # Workspaces 1-9 and 0 (the tenth); Shift+number moves the window there.
  workspaces = map toString (lib.range 1 9) ++ [ "0" ];

  # The same key as AeroSpace spells it: cmd-shift-left, cmd-enter...
  aerospaceKey =
    key:
    "cmd-"
    + lib.toLower (
      builtins.replaceStrings [ "+" "Return" "less" "greater" ] [ "-" "enter" "comma" "period" ] key
    );
}
