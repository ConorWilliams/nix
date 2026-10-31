# Shells: bash is the login shell, interactive sessions switch to fish.
# Aliases (home.shellAliases) and tool integrations apply to both.
{ ... }:

{
  programs.bash = {
    enable = true;
    # Runs only in interactive bash (Home Manager puts it after its
    # "not interactive? stop here" check), so `ssh host cmd`, scp and mosh
    # stay plain bash. Skipped when bash was started from fish, so typing
    # `bash` inside fish still gives you bash.
    initExtra = ''
      if [[ $(ps -o comm= -p $PPID) != *fish* ]]; then
        exec fish
      fi
    '';
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting # no startup banner
    '';
    # Calculator via fish's built-in math: `c 2^10/3`.
    # Quote anything with * or (): `c '(80-100)/80*100'`.
    functions.c = "math $argv";
  };

  # Prompt, identical in bash and fish on every machine:
  #   nix on  main [!] ❯           (local)
  #   conix@kepler nix on  main ❯  (over SSH)
  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      # Only these modules, in this order, to keep the prompt short.
      format = "$username$hostname$directory$git_branch$git_status$python$cmd_duration$status$character";
      # user@host only over SSH (starship's default rule for both).
      username.format = "[$user]($style)@";
      hostname.format = "[$hostname]($style) ";
      directory.truncation_length = 3; # at most 3 path segments
      python.format = "[($virtualenv )]($style)"; # active venv name only
      # Show the exit code when a command fails, as a red [127].
      status = {
        disabled = false;
        format = "[\\[$status\\]]($style) ";
      };
    };
  };
}
