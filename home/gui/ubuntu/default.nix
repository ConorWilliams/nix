{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  mod = "Mod1"; # Alt.
  lock = "i3lock -c 000000"; # black screen
  font = "${config.programs.kitty.font.name} 14"; # rofi and notifications

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
  imports = [ ../. ]; # the GUI layer

  # Non-NixOS Linux: lets the desktop find apps and icons installed by Nix,
  # and programs find Ubuntu's terminfo too.
  targets.genericLinux.enable = true;
  # ...but not its GPU drivers for Nix programs (GUI apps stay with apt;
  # README), which would also print a setup notice on every switch.
  targets.genericLinux.gpu.enable = false;

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

  # kitty comes from its own installer.
  home.sessionPath = [ "$HOME/.local/kitty.app/bin" ];

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
      terminal = "kitty";
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
      ];
    };
    # Rose Pine Dawn window borders and titles: the official port (i3
    # config lines; later lines win over Home Manager's default colours).
    extraConfig = builtins.readFile "${inputs.rose-pine-i3}/themes/rose-pine-dawn.theme";
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
