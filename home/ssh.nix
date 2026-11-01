# SSH client. Nothing is forwarded to servers: git there authenticates
# through gh's own token (programs.gh in default.nix), so SSH keys never
# leave the desk.
{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # Home Manager's old implicit defaults
  };
}
