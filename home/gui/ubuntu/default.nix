{
  config,
  options,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  mod = "Mod1"; # Alt.
  lock = "i3lock -c 000000"; # black screen
  refreshBar = "pkill -USR1 -x i3status"; # makes the bar update now
  font = "${config.programs.kitty.font.name} ${toString config.desktop.fontSize}"; # rofi and notifications

  # Rose Pine Dawn notification colours from the official mako port (mako
  # is Wayland-only; dunst has only a community port): its key=value
  # lines, normal ones first, then those for [urgency=high].
  mako =
    let
      port = builtins.readFile "${inputs.rose-pine-mako}/theme/rose-pine-dawn.theme";
      parse =
        text:
        lib.listToAttrs (
          map (
            line:
            let
              kv = lib.splitString "=" line;
            in
            lib.nameValuePair (lib.head kv) (lib.last kv)
          ) (lib.filter (lib.hasInfix "=") (lib.splitString "\n" text))
        );
      sections = lib.splitString "[urgency=high]" port;
      normal = parse (lib.head sections);
    in
    # Fail the build rather than silently losing colours if the port
    # ever changes its layout.
    assert lib.assertMsg (
      lib.length sections == 2 && normal ? background-color
    ) "rose-pine-mako: unexpected theme layout";
    {
      inherit normal;
      urgent = parse (lib.last sections);
    };
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

  # Non-NixOS Linux: the desktop finds apps and icons installed by Nix (as
  # well as Ubuntu's own), and cursors and terminfo too. These are the
  # parts of Home Manager's targets.genericLinux wanted here. Not the rest:
  # it also sources a single-user Nix's nix.sh in every shell, on top of
  # the multi-user one Ubuntu's /etc/profile loads (doubling PATH entries),
  # points <nixpkgs> at unpinned channels, and installs GPU drivers for Nix
  # programs (GUI apps stay with apt; README).
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
  # (for programs systemd starts; ncurses stops looking in the system's
  # folders once this is set, so they're listed too)
  systemd.user.sessionVariables.TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:$TERMINFO_DIRS\${TERMINFO_DIRS:+:}/etc/terminfo:/lib/terminfo:/usr/share/terminfo";

  # Skip GNOME's first-login wizard for a new account: the first login
  # (GNOME, before picking i3) is cut short, leaving it as a failed unit
  # that every switch then reports.
  xdg.configFile."gnome-initial-setup-done".text = "yes";

  # Desktop notifications (notify-send, Slack...): nothing shows them under
  # i3, so dunst from Nix, started by the first notification.
  services.dunst =
    let
      colours = {
        background = mako.normal.background-color;
        foreground = mako.normal.text-color;
      };
    in
    {
      enable = true;
      settings = {
        global = {
          inherit font;
          frame_width = 2;
          frame_color = mako.normal.border-color;
          separator_color = "frame";
          highlight = lib.removePrefix "over " mako.normal.progress-color; # progress bars
          corner_radius = 8;
          width = "(300, 600)"; # grows with the text, up to 600 px
        };
        urgency_low = colours;
        urgency_normal = colours;
        urgency_critical = colours // {
          frame_color = mako.urgent.border-color;
        };
      };
    };

  # Each Alt+Enter terminal is its own zellij session (i3, below), so on the
  # desks closing the window ends the session, and ended ones aren't kept
  # to resurrect: no pile of sessions. (Not on servers, where a dropped ssh
  # connection must leave the session running.)
  programs.zellij.settings = {
    on_force_close = "quit";
    session_serialization = false;
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
      # The bar has its own font setting: Home Manager's default bar, with
      # that font.
      bars =
        map (bar: bar // { fonts = config.xsession.windowManager.i3.config.fonts; })
          (options.xsession.windowManager.i3.config.type.getSubOptions [ ]).bars.default;
      terminal = "kitty zellij"; # Alt+Enter: a terminal in its own zellij session (below)
      menu = "rofi -show run";
      # Borders only, no title bar on top of each window.
      window.titlebar = false;
      floating.titlebar = false;

      # mkOptionDefault: add to i3's default keys rather than replace them.
      keybindings = lib.mkOptionDefault {
        "${mod}+o" = "exec kitty yazi";
        "${mod}+n" = "exec ${lock}";
        "${mod}+Shift+less" = "move workspace to output left";
        "${mod}+Shift+greater" = "move workspace to output right";
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
        "XF86MonBrightnessUp" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        "XF86MonBrightnessDown" = "exec --no-startup-id ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
        "--release ${mod}+p" =
          "exec --no-startup-id sh -c 'mkdir -p ~/Pictures && scrot -s ~/Pictures/%Y-%m-%d_%H%M%S.png'";
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

  # The bar's status line: volume, memory, the battery (where there is
  # one) and the time. (Ubuntu's default, for laptops, also shows Wi-Fi, IPv6,
  # network, disk and load.)
  programs.i3status = {
    enable = true;
    enableDefault = false;
    general = {
      colors = true;
      interval = 5;
    };
    modules = {
      # The default output's volume (PulseAudio, or PipeWire's stand-in).
      "volume master" = {
        position = 0;
        settings = {
          device = "pulse";
          format = "vol %volume";
          format_muted = "muted (%volume)";
        };
      };
      memory = {
        position = 1;
        settings = {
          format = "%used | %available";
          # used = total - available. The default also counts the kernel's
          # reclaimable cache as used (60 of "71 GiB used" when 15 really were).
          memory_used_method = "memavailable";
          threshold_degraded = "10%"; # of total memory: under 10% available
          format_degraded = "MEMORY < %available";
        };
      };
      # Nothing at all without a battery: i3bar skips a block with no text.
      "battery all" = {
        position = 2;
        settings = {
          format = "%status %percentage %remaining";
          format_down = "";
        };
      };
      "tztime local" = {
        position = 3;
        settings.format = "%Y-%m-%d %a %H:%M"; # 2026-11-02 Mon 14:52
      };
    };
  };

  # rofi (Alt+d), in Rose Pine Dawn: the official port, with the terminal's
  # font instead of the port's (which isn't installed).
  programs.rofi = {
    enable = true;
    theme = {
      "@import" = "${inputs.rose-pine-rofi}/rose-pine-dawn.rasi";
      "*".font = font;
    };
  };
}
