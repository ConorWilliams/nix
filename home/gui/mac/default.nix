# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# Mac GUI apps are Homebrew casks in darwin/mac.nix.
{ ... }:

{
  imports = [ ../. ]; # the GUI layer

  # AeroSpace manages its own start-at-login behavior.
  # Home Manager's AeroSpace module expects a Nix-built app for its launch agent;
  # this app is installed by Homebrew, so manage only its configuration here.
  home.file.".aerospace.toml".source = ./aerospace.toml;

  # Expose the casks' command-line helpers; Home Manager's Nix profile takes
  # precedence.
  home.sessionPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  # Everything on the Mac: system settings (darwin/mac.nix), then home.
  # `hms` stays home only, like everywhere else. nh picks
  # darwinConfigurations.<hostname> and asks for sudo itself; the flake
  # comes from NH_FLAKE.
  home.shellAliases.dms = "nh darwin switch && nh home switch";
}
