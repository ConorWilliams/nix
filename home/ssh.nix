# SSH client. Nothing is forwarded to servers: git there authenticates
# through gh's own token (git.nix), so your keys never leave your desk.
{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # Home Manager's old implicit defaults
  };
}
