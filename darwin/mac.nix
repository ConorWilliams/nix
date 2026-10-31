# The Mac's system settings. Your home directory is NOT managed here;
# that's homeConfigurations."<user>@mac", the same as every other machine.
# Stub: evaluates, but nothing is configured yet.
{ ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user system settings (Homebrew, macOS defaults)
  # apply to.
  system.primaryUser = "conor"; # TODO: confirm the Mac's username

  # The Determinate installer manages Nix itself, so nix-darwin shouldn't.
  nix.enable = false;

  # ── Later (after a few weeks on Linux) ────────────────────────────
  # homebrew = {
  #   enable = true;
  #   onActivation.cleanup = "none"; # never uninstall existing apps
  #   casks = [ "google-chrome" ];
  # };
  # system.defaults = { ... };
}
