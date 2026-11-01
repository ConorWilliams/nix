# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# AeroSpace goes here later (Home Manager's programs.aerospace).
# Mac GUI apps (Chrome, Slack...) are Homebrew casks in darwin/mac.nix.
{ config, ... }:

{
  imports = [ ../. ]; # the GUI layer

  # The Mac's system settings (darwin/mac.nix): the counterpart of `hms`.
  # nh picks darwinConfigurations.<hostname> and asks for sudo itself.
  home.shellAliases.dms = "nh darwin switch ${config.home.homeDirectory}/nix";
}
