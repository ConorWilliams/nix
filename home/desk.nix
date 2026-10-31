# Extras for machines you sit at, on any OS (hubble, laptop, Mac).
# Never imported on servers. OS-specific bits go in desk-linux.nix / desk-mac.nix.
{ ... }:

{
  home.shellAliases = {
    icat = "kitten icat"; # show an image in kitty
  };
}
