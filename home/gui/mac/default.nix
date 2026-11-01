# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# AeroSpace goes here later (Home Manager's programs.aerospace).
# Mac GUI apps (Chrome, Slack...) are Homebrew casks in darwin/mac.nix.
{ ... }:

{
  imports = [ ../. ]; # the GUI layer
}
