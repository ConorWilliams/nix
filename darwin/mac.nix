# The Mac's system settings. The home directory is NOT managed here;
# that's homeConfigurations."<user>@mac", the same as every other machine.
{ ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # nix-darwin's equivalent of home.stateVersion. Set once, never bump.
  system.stateVersion = 6;

  # The user that per-user system settings (Homebrew, macOS defaults)
  # apply to.
  system.primaryUser = "conix"; # TODO: the Mac's account name, once known

  # Nix is installed with Determinate's installer, which manages it, so
  # nix-darwin shouldn't.
  nix.enable = false;

  # GUI apps via Homebrew casks (bootstrap.sh installs Homebrew itself).
  homebrew = {
    enable = true;
    onActivation.cleanup = "none"; # never uninstall apps added by hand
    casks = [
      "kitty" # the terminal; Home Manager writes its config (gui layer)
    ];
  };
  # system.defaults = { ... };  (macOS settings, later)
}
