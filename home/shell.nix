# Shells: bash is the login shell, interactive sessions switch to fish.
# Aliases (home.shellAliases) and tool integrations apply to both.
{ inputs, ... }:

let
  # Rose Pine Dawn palette from the official starship port.
  rosePine =
    (builtins.fromTOML (builtins.readFile "${inputs.rose-pine-starship}/rose-pine-dawn.toml"))
    .palettes.rose-pine-dawn;
in

{
  programs.bash = {
    enable = true;
    # Runs in every bash, before the "not interactive? stop here" check.
    # `ssh host <command>` (and mosh, which starts mosh-server that way)
    # gets a non-interactive bash, and Ubuntu's /etc/bash.bashrc only loads
    # Nix for interactive ones; load it here so the host's own Nix tools
    # (mosh-server, zellij...) are found. nix-daemon.sh guards against
    # being loaded twice.
    bashrcExtra = ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
    '';
    # Runs only in interactive bash (Home Manager puts it after its
    # "not interactive? stop here" check), so `ssh host cmd`, scp and mosh
    # stay plain bash. Skipped when bash was started from fish, so typing
    # `bash` inside fish still gives bash.
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
      fish_config theme choose "Rosé Pine Dawn" # syntax colours (theme file below)
    '';
    # Calculator via fish's built-in math: `c 2^10/3`.
    # Quote anything with * or (): `c '(80-100)/80*100'`.
    functions.c = "math $argv";

    # zellij on another machine: `zzh brahe` starts a new session there,
    # `zzh brahe main` joins "main" (creating it if needed). `zosh` is the
    # same over mosh (no scrollback or images, but survives sleep).
    functions.zzh = {
      description = "zellij on a host over ssh: new session, or join/create one";
      wraps = "ssh"; # complete hostnames like ssh
      body = ''
        if set -q argv[2]
          ssh -t $argv[1] zellij attach -c $argv[2]
        else
          ssh -t $argv[1] zellij
        end
      '';
    };
    functions.zosh = {
      description = "zellij on a host over mosh: new session, or join/create one";
      wraps = "mosh"; # (mosh is the alias that adds --ssh=ssh)
      body = ''
        if set -q argv[2]
          mosh $argv[1] -- zellij attach -c $argv[2]
        else
          mosh $argv[1] -- zellij
        end
      '';
    };
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
      # Full colour: the modules' standard colour names (red, green...) are
      # redefined as Rose Pine Dawn's, mapped as in kitty's Rose Pine theme.
      palette = "rose-pine-dawn";
      palettes.rose-pine-dawn = rosePine // {
        red = rosePine.love;
        green = rosePine.pine;
        yellow = rosePine.gold;
        blue = rosePine.foam;
        purple = rosePine.iris;
        cyan = rosePine.rose;
      };
    };
  };

  # Shell history in a local SQLite database. Ctrl-R opens a full-screen
  # search over all history from every machine; Up searches this machine's
  # history only (press Ctrl-R inside either to change the filter).
  # Synced every 5 minutes to Atuin's hosted server (api.atuin.sh), end-to-end
  # encrypted. Login is per machine and never in Nix: `atuin login`.
  programs.atuin = {
    enable = true;
    # Don't bind `?` to Atuin AI (a hosted AI that would see shell context).
    flags = [ "--disable-ai" ];
    settings = {
      auto_sync = true;
      sync_frequency = "5m";
      update_check = false; # Nix handles updates
      filter_mode = "global";
      filter_mode_shell_up_key_binding = "host";
      workspaces = false; # don't narrow to the current git repo
      inline_height = 0; # full screen
      # Enter runs the picked command straight away; Tab puts it in the
      # prompt to edit first.
      enter_accept = true;
      theme.name = "rose-pine-dawn"; # from themes below

      # Background daemon, started by the shell when needed (no service).
      # Threads needs it; it also syncs every 5 minutes on its own.
      daemon = {
        enabled = true;
        autostart = true;
      };

      # Threads: capture Claude Code (and Codex) sessions from their
      # transcript files, synced like history. `atuin threads` to search,
      # `atuin resume` to continue one, on any machine.
      threads = {
        capture = true;
        capture_tools = true; # include tool input/output and edit diffs
      };
    };
  };

  # `z foo` jumps to the most-used directory matching foo; `zi` picks with fzf.
  programs.zoxide.enable = true;

  # Rose Pine Dawn for fish's syntax colours and atuin's search UI: the
  # official ports' theme files, selected above.
  xdg.configFile."fish/themes/Rosé Pine Dawn.theme".source =
    "${inputs.rose-pine-fish}/themes/Rosé Pine Dawn.theme";
  # (the contents: a path string would be written out as text)
  programs.atuin.themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-atuin}/dist/rose-pine-dawn.toml";
}
