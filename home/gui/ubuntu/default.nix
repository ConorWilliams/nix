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
  key = k: "${mod}+${k}"; # a key after the leader, as i3 spells it
  lock = "i3lock -c 000000"; # black screen
  refreshBar = "pkill -USR1 -x i3status";
  wm = import ../keys.nix;
  icons = {
    volume = "󰕾";
    muted = "󰖁";
    charging = "󰂄";
    plugged = "󱟢";
    battery = "󰁾";
  };
  font = "${config.programs.kitty.font.name} ${toString config.desktop.fontSize}";
in
{
  imports = [
    ../.
    {
      options.desktop.barFontSize = lib.mkOption {
        type = lib.types.number;
        default = 14;
        description = "Font size of the i3 bar.";
      };
    }
  ];

  # Lets every app (not just Nix ones) find fonts installed by Nix.
  fonts.fontconfig.enable = true;

  xdg = {
    # The desktop finds apps, icons and cursors installed by Nix: the parts of
    # targets.genericLinux wanted here (the rest sources nix.sh a second time).
    # TODO: once https://github.com/nix-community/home-manager/pull/9925 is
    # merged, replace this and home.sessionSearchVariables below with:
    #   targets.genericLinux.enable = true;
    #   targets.genericLinux.gpu.enable = false;
    #   systemd.user.sessionVariables.NIX_PATH = lib.mkForce "nixpkgs=flake:nixpkgs";
    systemDirs.data = [
      "\${NIX_STATE_DIR:-/nix/var/nix}/profiles/default/share"
      "${config.home.profileDirectory}/share"
      "/usr/share/ubuntu"
      "/usr/local/share"
      "/usr/share"
      "/var/lib/snapd/desktop"
    ];

    # Skip GNOME's first-login wizard for a new account
    configFile."gnome-initial-setup-done".text = "yes";

    # No geoclue demo agent: it outlives logouts, keeping the user manager
    # (and the stale variables .xprofile clears) alive.
    configFile."autostart/geoclue-demo-agent.desktop".text = /* ini */ ''
      [Desktop Entry]
      Type=Application
      Name=Geoclue Demo agent
      Hidden=true
    '';
  };

  home = {
    # Cursors too (see the TODO above).
    sessionSearchVariables.XCURSOR_PATH = [
      "${config.home.profileDirectory}/share/icons"
      "/usr/share/icons"
      "/usr/share/pixmaps"
    ];

    # kitty comes from its own installer.
    sessionPath = [ "$HOME/.local/kitty.app/bin" ];

    # Run by gdm before i3. The systemd user manager outlives logouts and keeps
    # a GNOME login's variables (a dead SESSION_MANAGER, GNOME's desktop name,
    # Home Manager's and Nix's "already loaded" marks): clear them, then give
    # it this desktop's name. Only those: importing everything would carry
    # this login's marks to the next.
    file.".xprofile".text = /* bash */ ''
      unset SESSION_MANAGER SYSTEMD_EXEC_PID GNOME_DESKTOP_SESSION_ID GNOME_SHELL_SESSION_MODE
      systemctl --user unset-environment SESSION_MANAGER SYSTEMD_EXEC_PID GNOME_DESKTOP_SESSION_ID \
        GNOME_SHELL_SESSION_MODE __HM_SESS_VARS_SOURCED __ETC_PROFILE_NIX_SOURCED
      dbus-update-activation-environment --systemd XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP \
        XDG_SESSION_TYPE DESKTOP_SESSION GDMSESSION
      # Inherited marks made ~/.profile skip Nix and Home Manager: load them.
      if [ -z "''${NH_FLAKE-}" ]; then
        unset __HM_SESS_VARS_SOURCED __ETC_PROFILE_NIX_SOURCED
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
        . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
      fi
    '';

    # Helpers i3 uses. None draw with OpenGL, so Nix builds work on Ubuntu.
    packages = with pkgs; [
      dex # starts the desktop's autostart apps (startup line below)
      xss-lock # locks the screen on suspend (lid close)
      scrot
      xclip
      arandr
    ];
  };

  # Desktop notifications
  services.dunst =
    let
      # Rose Pine Dawn, following the official mako port.
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
          frame_color = dawn.highlight-high;
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

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      modifier = mod;
      fonts = {
        names = [ config.programs.kitty.font.name ];
        size = config.desktop.barFontSize * 1.0; # (i3 wants a decimal)
      };
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

      keybindings =
        let
          k = wm.keys;
          ws = n: if n == "0" then "10" else n; # key 0 is workspace 10
          dir = lib.toLower;
          opposite =
            d:
            lib.getAttr d {
              left = "right";
              right = "left";
              up = "down";
              down = "up";
            };
          # As AeroSpace's join-with: wrap the neighbour in a split of the
          # other orientation, come back, and move into it.
          join = d: "focus ${d}, split toggle, focus ${opposite d}, move ${d}";
          run = cmd: "exec --no-startup-id ${cmd}";
          # The volume keys also refresh the bar at once, not at its next update.
          pactl = args: run "pactl ${args} && ${refreshBar}";
          brightness = step: run "${lib.getExe pkgs.brightnessctl} set ${step}";
          screenshot = pkgs.writeShellScript "screenshot" ''
            mkdir -p ~/Pictures
            scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png
          '';
        in
        lib.mergeAttrsList (
          map (n: {
            ${key n} = "workspace number ${ws n}";
            ${key "Shift+${n}"} = "move container to workspace number ${ws n}";
          }) wm.workspaces
          ++ map (a: {
            ${key a} = "focus ${dir a}";
            ${key "Shift+${a}"} = "move ${dir a}";
            ${key "Ctrl+${a}"} = join (dir a);
          }) wm.arrows
        )
        // {
          ${key k.terminal} = "exec kitty";
          ${key k.launcher} = "exec rofi -show run";
          ${key k.close} = "kill";
          ${key k.fullscreen} = "fullscreen toggle";
          ${key k.resize} = "mode resize";
          ${key k.flipSplit} = "layout toggle split";
          ${key k.lock} = "exec ${lock}";
          "--release ${key k.screenshot}" = run screenshot;
          ${key k.reload} = "restart"; # (reloads the config too)
          ${key k.monitorLeft} = "move workspace to output left";
          ${key k.monitorRight} = "move workspace to output right";

          # i3's own, with no AeroSpace counterpart.
          ${key "Shift+e"} = "exec i3-nagbar -t warning -m 'Exit i3?' -b Yes 'i3-msg exit'";

          # Volume, mute and brightness keys
          XF86AudioRaiseVolume = pactl "set-sink-volume @DEFAULT_SINK@ +5%";
          XF86AudioLowerVolume = pactl "set-sink-volume @DEFAULT_SINK@ -5%";
          XF86AudioMute = pactl "set-sink-mute @DEFAULT_SINK@ toggle";
          XF86AudioMicMute = run "pactl set-source-mute @DEFAULT_SOURCE@ toggle";
          XF86MonBrightnessUp = brightness "5%+";
          XF86MonBrightnessDown = brightness "5%-";
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
        # Password prompts for programs asking for admin rights.
        {
          command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
          notification = false;
        }
      ];
    };
    # Rose Pine Dawn window borders and titles: the official port
    extraConfig = builtins.readFile "${inputs.rose-pine-i3}/themes/rose-pine-dawn.theme";
  };

  # The bar's status line
  programs.i3status = {
    enable = true;
    enableDefault = false;
    general.interval = 5; # seconds between updates.
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
        settings.format = "%Y-%m-%d %a %H:%M";
      };
    };
  };

  # rofi (Alt+Space), in Rose Pine Dawn: the official port
  programs.rofi = {
    enable = true;
    theme = {
      "@import" = "${inputs.rose-pine-rofi}/rose-pine-dawn.rasi";
      "*".font = font;
    };
  };
}
