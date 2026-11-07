# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# Mac GUI apps are Homebrew casks in darwin/ (every Mac's, and each one's),
# except AeroSpace (below).
{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ../. ]; # the GUI layer

  # The window manager, AeroSpace, from Nix. Home Manager starts it at login
  # (a launchd agent, which also restarts it if it stops) and reloads its
  # config on each switch. Anything not set is AeroSpace's default. The keys
  # come from the list shared with i3 (../keys.nix), with Cmd as the leader.
  # (Each new version is a new app to macOS, which may ask again for its
  # Accessibility permission: System Settings, Privacy & Security.)
  programs.aerospace = {
    enable = true;
    launchd.enable = true;
    settings =
      let
        wm = import ../keys.nix;
        # A key as AeroSpace spells it, with Cmd as the leader: cmd-shift-left,
        # cmd-enter...
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
            }) wm.arrows
          )
          // {
            # A terminal in its own zellij session, as on the desks (by its
            # store path: apps started here don't get the shell's PATH).
            ${key k.terminal} =
              "exec-and-forget open -n -a kitty --args ${lib.getExe config.programs.zellij.package}";
            # (k.launcher: Spotlight's own Cmd+Space, nothing to bind)
            # Borderless Kitty has no AX close button; each terminal is a
            # separate app instance, so quit it when closing its last window.
            ${key k.close} = "exec-and-forget ${closeWindow}";
            ${key k.fullscreen} = "fullscreen";
            ${key k.floating} = "layout floating tiling";
            ${key k.resize} = "mode resize";
            ${key k.flipSplit} = "layout tiles horizontal vertical";
            # Lock first (Ctrl+Cmd+Q), then turn off the display.
            ${key k.lock} =
              "exec-and-forget /usr/bin/osascript -e 'tell application \"System Events\" to keystroke \"q\" using {control down, command down}' && /usr/bin/pmset displaysleepnow";
            ${key k.screenshot} =
              "exec-and-forget mkdir -p ~/Pictures && screencapture -i ~/Pictures/$(date +%Y-%m-%d_%H%M%S).png";
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

  programs.kitty.settings = {
    # Left Option is Alt, as on Linux: zellij's Alt-g, fzf's Alt-C, nvim's
    # Alt keys. Not the right one: on the British layout it types # and
    # other characters.
    macos_option_as_alt = "left";
    # No title bar and square corners, as tiled windows on i3 (where i3
    # draws no title bars; this setting does nothing on X11).
    hide_window_decorations = "titlebar-and-corners";
  };

  # AeroSpace's menu bar icon shows the workspaces as i3's bar does: those
  # with windows or on a screen, in order, the focused one filled and one on
  # another screen dimmed. (Its "i3 style ordered", one of the Experimental
  # UI Settings in its menu.)
  targets.darwin.defaults."bobko.aerospace".displayStyle = "i3Ordered";

  # Homebrew's command-line helpers (the casks'), after Nix's tools on PATH
  # so a Homebrew formula never shadows them. (In fish, which every shell
  # here hands over to; home.sessionPath would put them first.)
  programs.fish.shellInit = "fish_add_path --append --path /opt/homebrew/bin /opt/homebrew/sbin";

  # Everything on the Mac: system settings (darwin/<hostname>.nix), then home.
  # `hms` stays home only, like everywhere else. nh picks
  # darwinConfigurations.<hostname> and asks for sudo itself; the flake
  # comes from NH_FLAKE.
  home.shellAliases.dms = "nh darwin switch && nh home switch";
}
