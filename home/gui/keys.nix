# The window manager's keys, the same on Linux  and the Mac
{
  keys = {
    terminal = "Return"; # kitty, in its own zellij session
    launcher = "space"; # rofi; on the Mac, Spotlight's own Cmd+Space
    close = "Shift+q";
    fullscreen = "Shift+f";
    resize = "r"; # a mode: arrows resize, Esc or Enter leaves
    reload = "Shift+r"; # the window manager's config
    flipSplit = "e"; # the focused group: side by side <-> stacked
    lock = "n";
    screenshot = "p"; # of a region, into ~/Pictures
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

  # Workspaces 0-9; Shift+number moves the window there.
  workspaces = builtins.genList (i: toString (i + 1)) 9 ++ [ "0" ];
}
