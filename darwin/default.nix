# The Macs' system settings (nix-darwin), for every Mac; each one's own are
# in darwin/<hostname>.nix, which imports this. The home directory is NOT
# managed here: that's homeConfigurations."<user>@<hostname>", as on every
# machine.
{ config, ... }:

{
  # Each Mac's name (networking.hostName, from flake.nix) for all three of
  # macOS's names, so it stays put: macOS renames a Mac on a network name
  # clash (adding -2), and the flake finds its configs by this name.
  networking = {
    localHostName = config.networking.hostName;
    computerName = config.networking.hostName;
  };

  # Upstream Nix; nix-darwin manages its daemon and settings.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GUI apps via Homebrew casks (bootstrap.sh installs Homebrew itself):
  # here the ones every Mac's setup relies on, each Mac's own in its file.
  homebrew = {
    enable = true;
    casks = [ "kitty" ]; # the terminal; Home Manager writes its config (gui layer)
    # Removing a declaration uninstalls the package, preserving its app data.
    onActivation.cleanup = "uninstall";
  };

  # sudo asks for a fingerprint (Touch ID), the password still the fallback;
  # inside zellij too (reattach).
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
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

    # Language and region (no dedicated nix-darwin options for these).
    CustomUserPreferences.NSGlobalDomain = {
      AppleLanguages = [ "en-GB" ];
      AppleLocale = "en_GB";
    };
  };
}
