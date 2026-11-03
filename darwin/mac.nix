# The Mac's system settings. The home directory is NOT managed here;
# that's homeConfigurations."main@Conors-MacBook-Pro-2".
{ ... }:

{
  imports = [ ./preferences.nix ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user system settings (Homebrew, macOS defaults)
  # apply to.
  system.primaryUser = "main";
  users.users.main.home = "/Users/main";

  # This Mac uses upstream Nix; nix-darwin manages its daemon and settings.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # GUI apps via Homebrew casks (bootstrap.sh installs Homebrew itself).
  homebrew = {
    enable = true;
    taps = [ "nikitabobko/tap" ];
    casks = [
      "adobe-creative-cloud"
      {
        name = "nikitabobko/tap/aerospace";
        trusted = true;
      }
      "google-chrome"
      "kitty"
      "mullvad-vpn"
      "thunderbird"
      "tor-browser"
      "transmission"
      "vlc"
      "whatsapp"
    ];
    # Removing a declaration uninstalls the package, preserving its app data.
    onActivation.cleanup = "uninstall";
  };
}
