# Extras for machines you sit at, on any OS (hubble, luna, mac).
# Never imported on servers. OS-specific bits go in desk-linux.nix / desk-mac.nix.
{ pkgs, ... }:

{
  home.packages = [
    # OpenAI's coding CLI, from nixpkgs: a few days behind, but prebuilt.
    # Desk only: it pulls in ~1 GiB (GStreamer, for voice features).
    pkgs.codex
  ];
}
