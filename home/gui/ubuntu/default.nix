# Ubuntu layer: the desks (i3 and its bar, the launcher, notifications,
# the login session), on top of the GUI layer.
{
  config,
  lib,
  pkgs,
  inputs,
  dawn,
  ...
}:

let
  mod = "Mod1"; # Alt.
  lock = "i3lock -c 000000"; # black screen
  refreshBar = "pkill -USR1 -x i3status"; # makes the bar update now
  # The window manager's keys, shared with the Mac's AeroSpace.
  wm = import ../keys.nix;
  # The bar's icons: Nerd Font glyphs (Material Design), which the
  # terminal's font includes, each named as in Nerd Fonts' cheat sheet.
  icons = {
    volume = "󰕾"; # nf-md-volume_high
    muted = "󰖁"; # nf-md-volume_off
    charging = "󰂄"; # nf-md-battery_charging
    plugged = "󱟢"; # nf-md-battery_check: on power, not charging (full, or held at a limit)
    battery = "󰁾"; # nf-md-battery_50: on battery, at any charge
  };
  font = "${config.programs.kitty.font.name} ${toString config.desktop.fontSize}"; # rofi and notifications
in
{
  imports = [
    ../. # the GUI layer
    # The i3 bar's font size, set per machine like desktop.fontSize.
    {
      options.desktop.barFontSize = lib.mkOption {
        type = lib.types.number;
        default = 14;
        description = "Font size of the i3 bar.";
      };
    }
  ];

  # Lets every app (not just Nix ones) find fonts installed by Nix. (The
  # Mac has its own way: Home Manager links them into ~/Library/Fonts.)
  fonts.fontconfig.enable = true;

  # Non-NixOS Linux: the desktop finds apps, icons and cursors installed by
  # Nix (as well as Ubuntu's own). These are the parts of Home Manager's
  # targets.genericLinux wanted here. Not the rest: it also sources a
  # single-user Nix's nix.sh in every shell, on top of the multi-user one
  # Ubuntu's /etc/profile loads (doubling PATH entries), points <nixpkgs>
  # at unpinned channels, sets a TERMINFO_DIRS for systemd's services that
  # none here use (and that names a folder that doesn't exist), and
  # installs GPU drivers for Nix programs (GUI apps stay with apt; README).
  # TODO: once Home Manager PR #9925 is merged (genericLinux stops sourcing
  # nix.sh: https://github.com/nix-community/home-manager/pull/9925), drop
  # xdg.systemDirs.data and XCURSOR_PATH below for
  # `targets.genericLinux.enable = true`, overriding its NIX_PATH (it can't
  # be unset; the flake's pinned nixpkgs instead:
  # `systemd.user.sessionVariables.NIX_PATH = lib.mkForce "nixpkgs=flake:nixpkgs"`)
  # and turning off its GPU drivers (`targets.genericLinux.gpu.enable = false`).
  xdg.systemDirs.data = [
    "\${NIX_STATE_DIR:-/nix/var/nix}/profiles/default/share"
    "${config.home.profileDirectory}/share"
    "/usr/share/ubuntu"
    "/usr/local/share"
    "/usr/share"
    "/var/lib/snapd/desktop"
  ];
  home.sessionSearchVariables.XCURSOR_PATH = [
    "${config.home.profileDirectory}/share/icons"
    "/usr/share/icons"
    "/usr/share/pixmaps"
  ];

  # Skip GNOME's first-login wizard for a new account: the first login
  # (GNOME, before picking i3) is cut short, leaving it as a failed unit
  # that every switch then reports.
  xdg.configFile."gnome-initial-setup-done".text = "yes";

  # Desktop notifications (notify-send, Slack...): nothing shows them under
  # i3, so dunst from Nix, started by the first notification.
  services.dunst =
    let
      # Rose Pine Dawn (home/default.nix), as the official port for mako (a
      # Wayland dunst) colours notifications, except the frame: muted, as the
      # port's (highlight high) isn't in the palette.
      colours = {
        background = dawn.overlay;
        foreground = dawn.text;
      };
    in
    {
      enable = true;
      settings = {
        global = {
          inherit font;
          frame_width = 2;
          frame_color = dawn.muted;
          separator_color = "frame";
          highlight = dawn.pine; # progress bars
          corner_radius = 8;
          width = "(300, 600)"; # grows with the text, up to 600 px
        };
        urgency_low = colours;
        urgency_normal = colours;
        urgency_critical = colours // {
          frame_color = dawn.love;
        };
      };
    };

  # kitty comes from its own installer.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

  # Desktop login (/etc/gdm3/Xsession reads this after ~/.profile, before
  # i3). Each login starts from the systemd user manager's environment, and
  # the manager outlives logouts, keeping whatever was put there: a GNOME
  # login puts all of its own (a dead SESSION_MANAGER, which programs then
  # try to reach; GNOME's desktop name, which services the manager starts,
  # like dunst and the portals, then act on; and the "already loaded" marks
  # of Home Manager's variables and Nix's setup, which made later logins
  # skip them). So drop GNOME's session here, clear those from the manager,
  # and tell it this desktop's name. (Not everything, as GNOME does: this
  # login's marks would then reach the next.)
  home.file.".xprofile".text = /* bash */ ''
    unset SESSION_MANAGER SYSTEMD_EXEC_PID GNOME_DESKTOP_SESSION_ID GNOME_SHELL_SESSION_MODE
    systemctl --user unset-environment SESSION_MANAGER SYSTEMD_EXEC_PID GNOME_DESKTOP_SESSION_ID \
      GNOME_SHELL_SESSION_MODE __HM_SESS_VARS_SOURCED __ETC_PROFILE_NIX_SOURCED
    dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
      XDG_SESSION_TYPE DESKTOP_SESSION GDMSESSION
    # If this login inherited those marks (the manager had them), ~/.profile
    # skipped Nix's setup and Home Manager's variables: load them now.
    if [ -z "''${NH_FLAKE-}" ]; then
      unset __HM_SESS_VARS_SOURCED __ETC_PROFILE_NIX_SOURCED
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
    fi
  '';

  # Not GNOME's geoclue demo agent (an autostart app outside GNOME): it
  # outlives logouts, so they never finish and the systemd user manager
  # never restarts afresh (the GNOME session left in it above).
  xdg.configFile."autostart/geoclue-demo-agent.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Geoclue Demo agent
    Hidden=true
  '';

  # Helpers i3 uses. None draw with OpenGL, so Nix builds work on Ubuntu.
  home.packages = with pkgs; [
    dex # starts the desktop's autostart apps (startup line below)
    xss-lock # locks the screen on suspend (lid close)
    scrot
    xclip
    arandr
  ];

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      # The bar's (and title bars') font: the terminal's, at the machine's
      # bar size (i3's default, monospace 8, is tiny on 4K).
      fonts = {
        names = [ config.programs.kitty.font.name ];
        size = config.desktop.barFontSize * 1.0; # (i3 wants a decimal)
      };
      # The bar: i3's own defaults (colours, at the bottom...), with that font,
      # i3status (below), and the tray on the primary monitor.
      bars = [
        {
          inherit (config.xsession.windowManager.i3.config) fonts;
          statusCommand = lib.getExe config.programs.i3status.package;
          trayOutput = "primary";
        }
      ];
      # Borders only, no title bar on top of each window.
      window.titlebar = false;
      floating.titlebar = false;

      # Every key, not i3's defaults plus some: the shared ones (../keys.nix,
      # the Mac's AeroSpace uses the same keys) and a few of i3's own.
      keybindings =
        let
          k = wm.keys;
          ws = n: if n == "0" then "10" else n; # key 0 is workspace 10
        in
        lib.mergeAttrsList (
          map (n: {
            "${mod}+${n}" = "workspace number ${ws n}";
            "${mod}+Shift+${n}" = "move container to workspace number ${ws n}";
          }) wm.workspaces
          ++ map (a: {
            "${mod}+${a}" = "focus ${lib.toLower a}";
            "${mod}+Shift+${a}" = "move ${lib.toLower a}";
          }) wm.arrows
        )
        // {
          "${mod}+${k.terminal}" = "exec kitty zellij";
          "${mod}+${k.launcher}" = "exec rofi -show run";
          "${mod}+${k.close}" = "kill";
          "${mod}+${k.fullscreen}" = "fullscreen toggle";
          "${mod}+${k.floating}" = "floating toggle";
          "${mod}+${k.resize}" = "mode resize";
          "${mod}+${k.flipSplit}" = "layout toggle split";
          "${mod}+${k.lock}" = "exec ${lock}";
          "--release ${mod}+${k.screenshot}" =
            "exec --no-startup-id sh -c 'mkdir -p ~/Pictures && scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png'";
          "${mod}+${k.reload}" = "restart"; # (reloads the config too)
          "${mod}+${k.monitorLeft}" = "move workspace to output left";
          "${mod}+${k.monitorRight}" = "move workspace to output right";

          # i3's own, with no AeroSpace counterpart.
          "${mod}+h" = "split h"; # the next window opens beside this one
          "${mod}+v" = "split v"; # ...or below it
          "${mod}+a" = "focus parent";
          "${mod}+minus" = "scratchpad show";
          "${mod}+Shift+minus" = "move scratchpad";
          "${mod}+Shift+e" = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          # Volume, mute and brightness keys (under GNOME its settings daemon
          # handles them; it doesn't run under i3). Brightness asks logind, so
          # no root; on a desk without a backlight it does nothing.
          # The volume ones also refresh the bar at once (USR1), rather than at
          # its next 5-second update.
          "XF86AudioRaiseVolume" =
            "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ +5% && ${refreshBar}";
          "XF86AudioLowerVolume" =
            "exec --no-startup-id pactl set-sink-volume @DEFAULT_SINK@ -5% && ${refreshBar}";
          "XF86AudioMute" = "exec --no-startup-id pactl set-sink-mute @DEFAULT_SINK@ toggle && ${refreshBar}";
          "XF86AudioMicMute" = "exec --no-startup-id pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          "XF86MonBrightnessUp" = "exec --no-startup-id ${lib.getExe pkgs.brightnessctl} set 5%+";
          "XF86MonBrightnessDown" = "exec --no-startup-id ${lib.getExe pkgs.brightnessctl} set 5%-";
        };

      startup = [
        # Apps from the desktop's autostart folders (network applet etc.).
        {
          command = "dex --autostart --environment i3";
          notification = false;
        }
        {
          command = "xss-lock --transfer-sleep-lock -- ${lock} --nofork";
          notification = false;
        }
        # Password prompts for programs asking for admin rights (updates,
        # mounting disks...): GNOME starts this agent, i3 doesn't.
        {
          command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          notification = false;
        }
      ];
    };
    # Rose Pine Dawn window borders and titles: the official port (i3
    # config lines; later lines win over Home Manager's default colours).
    extraConfig = builtins.readFile "${inputs.rose-pine-i3}/themes/rose-pine-dawn.theme";
  };

  # The bar's status line: volume, the battery (where there is one) and the
  # time, with icons. (Ubuntu's default, for laptops, also shows Wi-Fi,
  # IPv6, network, disk, load and memory.)
  programs.i3status = {
    enable = true;
    enableDefault = false;
    general.interval = 5; # seconds between updates (i3status's default is 1)
    modules = {
      # The default output's volume (PulseAudio, or PipeWire's stand-in).
      "volume master" = {
        position = 0;
        settings = {
          device = "pulse";
          format = "${icons.volume} %volume";
          format_muted = "${icons.muted} %volume";
        };
      };
      # The icon says charging, on power (full), or on battery. Nothing at
      # all without a battery: i3bar skips a block with no text.
      "battery all" = {
        position = 1;
        settings = {
          format = "%status %percentage";
          status_chr = icons.charging;
          status_full = icons.plugged;
          status_bat = icons.battery;
          integer_battery_capacity = true; # 85%, not 85.12%
          last_full_capacity = true; # of what it holds now, as macOS shows it
          format_down = "";
        };
      };
      "tztime local" = {
        position = 2;
        settings.format = "%Y-%m-%d %a %H:%M"; # 2026-11-02 Mon 14:52
      };
    };
  };

  # rofi (Alt+Space), in Rose Pine Dawn: the official port, with the terminal's
  # font instead of the port's (which isn't installed).
  programs.rofi = {
    enable = true;
    theme = {
      "@import" = "${inputs.rose-pine-rofi}/rose-pine-dawn.rasi";
      "*".font = font;
    };
  };
}
