# SSH client. Work servers are reached by short names (kepler, brahe...), so
# "a name with no dot in it" is how this config recognises them, without
# listing hostnames in this public repo.
{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false; # Home Manager's old implicit defaults

    settings = {
      # Work servers: forward the SSH agent, so git on the server uses the
      # key on the machine you came from and servers hold no keys of their
      # own. `!*.*` excludes any name with a dot (github.com, IP addresses).
      "* !*.*".ForwardAgent = true;

      # Load a key into the agent the first time ssh uses it, so there's
      # something to forward without running ssh-add by hand.
      "*".AddKeysToAgent = "yes";
    };
  };
}
