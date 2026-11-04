# The window manager's keys, the same on Linux (i3, leader Alt) and the Mac
# (AeroSpace, leader Cmd): which key each action uses after the leader,
# spelled as i3 spells it. Each layer binds them to its own commands
# (gui/ubuntu/default.nix, gui/mac/default.nix), so a key changes here once.
# On the Mac they leave copy, paste, save, find, quit, Cmd+W/T/Tab and
# Spotlight's Cmd+Space alone, but take over some of macOS's: Cmd+arrows in
# text (line and document start/end), Cmd+number (tabs), Cmd+Shift+3/4/5
# (screenshots: the screenshot key below instead), Cmd+N, Cmd+P, Cmd+Enter.
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
    # The whole workspace to the screen on the left/right (the arrows: plain
    # focuses, Shift moves the window, Ctrl+Shift moves the workspace).
    monitorLeft = "Ctrl+Shift+Left";
    monitorRight = "Ctrl+Shift+Right";
  };

  # Focus with the arrows; Shift+arrows moves the window.
  arrows = [
    "Left"
    "Down"
    "Up"
    "Right"
  ];

  # Workspaces 1-9 and 0 (the tenth); Shift+number moves the window there.
  workspaces = builtins.genList (i: toString (i + 1)) 9 ++ [ "0" ];
}
