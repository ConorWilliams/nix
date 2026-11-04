# Mac layer: the macOS counterpart of ubuntu/, on top of the GUI layer.
# Mac GUI apps are Homebrew casks in darwin/mac.nix.
{ lib, pkgs, ... }:

{
  imports = [ ../. ]; # the GUI layer

  # AeroSpace manages its own start-at-login behavior.
  # Home Manager's AeroSpace module expects a Nix-built app for its launch agent;
  # this app is installed by Homebrew, so manage only its configuration here.
  home.file.".aerospace.toml".source = ./aerospace.toml;

  # These two 18.24.4 integration tests mistake unreadable interpreter
  # processes for a live Pi session under macOS build-user isolation. Keep the
  # rest of the package's tests, and stop skipping them on the next version.
  programs.atuin.package = pkgs.atuin.overrideAttrs (old: {
    checkFlags =
      (old.checkFlags or [ ])
      ++ lib.optionals (old.version == "18.24.4") [
        "--skip=a_diverged_copy_resumes_only_as_chosen::agent_4_Agent__Pi"
        "--skip=a_session_gone_on_with_elsewhere_catches_up_where_it_came_from::agent_3_Agent__Pi"
      ];
  });

  # Homebrew's command-line helpers (the casks'), after Nix's tools on PATH
  # so a Homebrew formula never shadows them. (In fish, which every shell
  # here hands over to; home.sessionPath would put them first.)
  programs.fish.shellInit = "fish_add_path --append --path /opt/homebrew/bin /opt/homebrew/sbin";

  # Everything on the Mac: system settings (darwin/mac.nix), then home.
  # `hms` stays home only, like everywhere else. nh picks
  # darwinConfigurations.<hostname> and asks for sudo itself; the flake
  # comes from NH_FLAKE.
  home.shellAliases.dms = "nh darwin switch && nh home switch";
}
