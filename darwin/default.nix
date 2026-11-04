# The Macs' system settings (nix-darwin), for every Mac; each one's own are
# in darwin/<hostname>.nix, which imports this. The home directory is NOT
# managed here: that's homeConfigurations."<user>@<hostname>", as on every
# machine.
{ ... }:

{
  # Upstream Nix; nix-darwin manages its daemon and settings.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GUI apps via Homebrew casks (bootstrap.sh installs Homebrew itself):
  # here the ones every Mac's setup relies on, each Mac's own in its file.
  homebrew = {
    enable = true;
    taps = [ "nikitabobko/tap" ];
    casks = [
      "kitty" # the terminal; Home Manager writes its config (gui layer)
      # the window manager; its config is Home Manager's (gui/mac)
      {
        name = "nikitabobko/tap/aerospace";
        trusted = true;
      }
    ];
    # Removing a declaration uninstalls the package, preserving its app data.
    onActivation.cleanup = "uninstall";
  };

  # Keyboard: Caps Lock is Escape, and keys repeat quickly.
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToEscape = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      "com.apple.trackpad.scaling" = 2.0;
    };

    # An empty Dock that hides itself.
    dock = {
      autohide = true;
      persistent-apps = [ ];
      persistent-others = [ ];
    };

    # nix-darwin writes these to both built-in and Bluetooth trackpad domains.
    trackpad = {
      Clicking = false; # no tap to click
      TrackpadRightClick = true; # two fingers right-click
    };

    # Language and region (no dedicated nix-darwin options for these).
    CustomUserPreferences.NSGlobalDomain = {
      AppleLanguages = [ "en-GB" ];
      AppleLocale = "en_GB";
    };
  };
}
