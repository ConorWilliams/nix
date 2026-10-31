# The Mac: nix-darwin system settings, with Home Manager running inside.
# Stub: evaluates, but nothing Mac-specific is configured yet.
{ ... }:

let
  user = "conor"; # TODO: confirm the Mac's username
in
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user settings (Homebrew, macOS defaults) apply to.
  system.primaryUser = user;
  users.users.${user}.home = "/Users/${user}";

  # The Determinate installer manages Nix itself, so nix-darwin shouldn't.
  nix.enable = false;

  # ── Home Manager: the same modules as a Linux desk, minus i3 ──────
  home-manager.useGlobalPkgs = true;   # reuse this config's nixpkgs
  home-manager.useUserPackages = true; # install into the user's profile
  home-manager.users.${user}.imports = [
    ../home/common.nix
    ../home/desk.nix
  ];

  # ── Later (after a few weeks on Linux) ────────────────────────────
  # services.aerospace = { enable = true; settings = { ... }; };
  # homebrew = {
  #   enable = true;
  #   onActivation.cleanup = "none"; # never uninstall existing apps
  #   casks = [ "google-chrome" ];
  # };
  # system.defaults = { ... };
}
