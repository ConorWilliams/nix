{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../. ]; # the GUI layer

  programs = {
    # The window manager, AeroSpace, from Nix. Home Manager starts it at login
    aerospace = {
      enable = true;
      launchd.enable = true;
      settings =
        let
          wm = import ../keys.nix;
          # A key as AeroSpace spells it, with Cmd as the leader
          key = k: "cmd-" + lib.toLower (builtins.replaceStrings [ "+" "Return" ] [ "-" "enter" ] k);
          k = wm.keys;

          # TODO: Workaround AeroSpace #1097.
          closeWindow = pkgs.writeShellScript "aerospace-close" ''
            aerospace=${lib.getExe config.programs.aerospace.package}
            workspace="$($aerospace list-workspaces --focused)" || exit
            $aerospace close --quit-if-last-window || exit
            ${lib.getExe' pkgs.coreutils "sleep"} 0.1
            $aerospace workspace "$workspace"
          '';

          # Lock first (Ctrl+Cmd+Q), then turn off the display.
          lock = pkgs.writeShellScript "lock" ''
            /usr/bin/osascript <<'EOF'
              tell app "System Events" to keystroke "q" using {control down, command down}
            EOF
            /usr/bin/pmset displaysleepnow
          '';

          screenshot = pkgs.writeShellScript "screenshot" ''
            mkdir -p ~/Pictures
            /usr/sbin/screencapture -i ~/Pictures/$(date +%Y-%m-%d_%H%M%S).png
          '';
        in
        {
          # The mouse follows focus to another screen, as in i3.
          on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
          mode.main.binding =
            lib.mergeAttrsList (
              map (n: {
                ${key n} = "workspace ${n}";
                ${key "Shift+${n}"} = "move-node-to-workspace ${n}";
              }) wm.workspaces
              ++ map (a: {
                ${key a} = "focus ${lib.toLower a}";
                ${key "Shift+${a}"} = "move ${lib.toLower a}";
                ${key "Ctrl+${a}"} = "join-with ${lib.toLower a}";
              }) wm.arrows
            )
            // {
              ${key k.terminal} = "exec-and-forget open -n -a kitty";
              # (k.launcher: Spotlight's own Cmd+Space, nothing to bind)
              ${key k.close} = "exec-and-forget ${closeWindow}";
              ${key k.fullscreen} = "fullscreen";
              ${key k.resize} = "mode resize";
              ${key k.flipSplit} = "layout tiles horizontal vertical";
              ${key k.lock} = "exec-and-forget ${lock}";
              ${key k.screenshot} = "exec-and-forget ${screenshot}";
              ${key k.reload} = "reload-config";
              ${key k.monitorLeft} = "move-workspace-to-monitor --wrap-around prev";
              ${key k.monitorRight} = "move-workspace-to-monitor --wrap-around next";
            };
          # As i3's: arrows resize the focused window, Esc or Enter leaves.
          mode.resize.binding = {
            left = "resize width -50";
            right = "resize width +50";
            up = "resize height -50";
            down = "resize height +50";
            esc = "mode main";
            enter = "mode main";
          };
        };
    };

    # Finder-launched terminals must use the same socket directory as shells.
    kitty.environment.ZELLIJ_SOCKET_DIR = config.home.sessionVariables.ZELLIJ_SOCKET_DIR;

    kitty.settings = {
      # Quit when the last window closes, as on Linux.
      macos_quit_when_last_window_closed = true;
      # Not the right one: on the British layout it types #, etc
      macos_option_as_alt = "left";
      # No title bar and square corners.
      hide_window_decorations = "titlebar-and-corners";
    };

    # Homebrew's command-line helpers (the casks')
    fish.shellInit = "fish_add_path --append --path /opt/homebrew/bin /opt/homebrew/sbin";
  };

  # AeroSpace's menu bar icon shows the workspaces as i3's bar does
  targets.darwin.defaults."bobko.aerospace".displayStyle = "i3Ordered";

  # Everything on the Mac: system settings, then home, then the Homebrew
  # apps (activation installs and removes casks, but doesn't upgrade them).
  home.shellAliases.dms = "nh darwin switch && nh home switch && brew upgrade";
}
