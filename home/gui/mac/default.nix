# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# AeroSpace goes here later (Home Manager's programs.aerospace).
# Mac GUI apps (Chrome, Slack...) are Homebrew casks in darwin/mac.nix.
{ ... }:

{
  imports = [ ../. ]; # the GUI layer

  # Everything on the Mac: system settings (darwin/mac.nix), then home.
  # `hms` stays home only, like everywhere else. nh picks
  # darwinConfigurations.<hostname> and asks for sudo itself; the flake
  # comes from NH_FLAKE.
  home.shellAliases.dms = "nh darwin switch && nh home switch";
}
