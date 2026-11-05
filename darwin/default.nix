# The Macs' system settings (nix-darwin)
{ config, ... }:

# TODO: the division between default.nix and polaris.nix is a
# little arbitrary because at the moment I only have one Mac.

{
  # Each Mac's name for all three of macOS's names, so it stays put: macOS
  # renames a Mac on a network name clash.
  networking = {
    localHostName = config.networking.hostName;
    computerName = config.networking.hostName;
  };

  # Upstream Nix; nix-darwin manages its daemon and settings.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GUI apps via Homebrew casks
  homebrew = {
    enable = true;
    casks = [ "kitty" ];
    onActivation.cleanup = "uninstall";
  };

  # Weekly clean-up of old versions and unused files, as root.
  programs.nh = {
    enable = true;
    clean = {
      enable = true;
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # sudo asks for a fingerprint (Touch ID).
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true; # inside zellij too.
  };

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

    CustomUserPreferences.NSGlobalDomain = {
      AppleLanguages = [ "en-GB" ];
      AppleLocale = "en_GB";
    };
  };
}
