# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# AeroSpace goes here later (Home Manager's programs.aerospace).
# Mac GUI apps (Chrome, Slack...) are Homebrew casks in darwin/mac.nix.
{ pkgs, ... }:

{
  imports = [ ../. ]; # the GUI layer

  # macOS logs into zsh, which nothing here manages (on Linux, bash hands
  # over to fish), so kitty starts fish itself, as a login shell.
  programs.kitty.settings.shell = "${pkgs.fish}/bin/fish --login";

  # Everything on the Mac: system settings (darwin/mac.nix), then home.
  # `hms` stays home only, like everywhere else. nh picks
  # darwinConfigurations.<hostname> and asks for sudo itself; the flake
  # comes from NH_FLAKE.
  home.shellAliases.dms = "nh darwin switch && nh home switch";
}
