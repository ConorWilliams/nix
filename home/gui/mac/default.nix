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
  imports = [
    ../. # the GUI layer
    ./bar.nix # SketchyBar, at the bottom
  ];

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
            ${key k.close} = "close";
            ${key k.fullscreen} = "fullscreen";
            ${key k.floating} = "layout floating tiling";
            ${key k.resize} = "mode resize";
            ${key k.flipSplit} = "layout tiles horizontal vertical";
            # Puts the screens to sleep, which locks when a password is
            # required right after sleep (System Settings, Lock Screen).
            ${key k.lock} = "exec-and-forget pmset displaysleepnow";
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

  # These two 18.24.4 integration tests mistake unreadable interpreter
  # processes for a live Pi session under macOS build-user isolation. Keep the
  # rest of the package's tests, and stop skipping them on the next version.
  programs.atuin.package = pkgs.atuin.overrideAttrs (old: {
    checkFlags =
      (old.checkFlags or [ ])
      ++ lib.optionals (old.version == "18.24.4") [
        "--skip=a_diverged_copy_resumes_only_as_chosen::agent_4_Agent__Pi"
        "--skip=a_session_gone_on_with_elsewhere_catches_up_where_it_came_from::agent_3_Agent__Pi"
      ];
  });

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
