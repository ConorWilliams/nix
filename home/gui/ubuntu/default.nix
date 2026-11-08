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

  # The desktop finds apps, icons and cursors installed by Nix: the parts of
  # targets.genericLinux wanted here (the rest sources nix.sh a second time).
  # TODO: once https://github.com/nix-community/home-manager/pull/9925 is
  # merged, replace these two with:
  #   targets.genericLinux.enable = true;
  #   targets.genericLinux.gpu.enable = false;
  #   systemd.user.sessionVariables.NIX_PATH = lib.mkForce "nixpkgs=flake:nixpkgs";
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

  # Skip GNOME's first-login wizard for a new account
  xdg.configFile."gnome-initial-setup-done".text = "yes";

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

  # kitty comes from its own installer.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

  # Run by gdm before i3. The systemd user manager outlives logouts and keeps
  # a GNOME login's variables (a dead SESSION_MANAGER, GNOME's desktop name,
  # Home Manager's and Nix's "already loaded" marks): clear them, then give
  # it this desktop's name. Only those: importing everything would carry
  # this login's marks to the next.
  home.file.".xprofile".text = /* bash */ ''
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

  # No geoclue demo agent: it outlives logouts, keeping the user manager
  # (and the stale variables above) alive.
  xdg.configFile."autostart/geoclue-demo-agent.desktop".text = /* ini */ ''
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
        in
        lib.mergeAttrsList (
          map (n: {
            ${key n} = "workspace number ${ws n}";
            ${key "Shift+${n}"} = "move container to workspace number ${ws n}";
          }) wm.workspaces
          ++ map (a: {
            ${key a} = "focus ${lib.toLower a}";
            ${key "Shift+${a}"} = "move ${lib.toLower a}";
            # As AeroSpace's join-with: wrap the neighbour in a split of the
            # other orientation, come back, and move into it.
            ${key "Ctrl+${a}"} =
              let
                d = lib.toLower a;
                back =
                  {
                    left = "right";
                    right = "left";
                    up = "down";
                    down = "up";
                  }
                  .${d};
              in
              "focus ${d}, split toggle, focus ${back}, move ${d}";
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
          "--release ${key k.screenshot}" =
            "exec --no-startup-id sh -c 'mkdir -p ~/Pictures && scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png'";
          ${key k.reload} = "restart"; # (reloads the config too)
          ${key k.monitorLeft} = "move workspace to output left";
          ${key k.monitorRight} = "move workspace to output right";

          # i3's own, with no AeroSpace counterpart.
          ${key "a"} = "focus parent";
          ${key "minus"} = "scratchpad show";
          ${key "Shift+minus"} = "move scratchpad";
          ${key "Shift+e"} = "exec i3-nagbar -t warning -m 'Do you want to exit i3?' -b 'Yes' 'i3-msg exit'";

          # Volume, mute and brightness keys
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
