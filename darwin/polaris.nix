# polaris: this Mac's own system settings, on top of every Mac's (./.).
{ ... }:

{
  imports = [ ./. ];

  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user system settings (Homebrew, macOS defaults)
  # apply to.
  system.primaryUser = "main";
  users.users.main.home = "/Users/main";

  # Its name, kept: macOS renames a Mac on a network name clash (adding -2),
  # and the flake finds its configs by this name. (Set it by hand the first
  # time: README.)
  networking = {
    hostName = "polaris";
    localHostName = "polaris";
    computerName = "polaris";
  };

  # Its apps (Homebrew casks), added to every Mac's (./default.nix).
  homebrew.casks = [
    "adobe-creative-cloud"
    "google-chrome"
    "mullvad-vpn"
    "thunderbird"
    "tor-browser"
    "transmission"
    "vlc"
    "whatsapp"
  ];
}
