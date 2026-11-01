# Shells: the system's login shell (bash on Linux, zsh on macOS) stays as
# it is and hands interactive sessions over to fish, the same way on every
# machine (terminals, ssh, zellij panes).
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # The hand-off, for bash and zsh alike. Not when the parent is already
  # fish (so typing `bash` inside fish gives bash), not for `-ic 'cmd'`
  # (tools probing the environment), not in nix-shell / nix develop (they
  # need their own shell for the dev environment).
  toFish =
    { commandVar, isLogin }:
    ''
      if [[ $(ps -o comm= -p $PPID) != *fish* && -z ''${${commandVar}:-} && -z ''${IN_NIX_SHELL:-} ]]; then
        ${isLogin} && exec ${config.programs.fish.package}/bin/fish --login
        exec ${config.programs.fish.package}/bin/fish
      fi
    '';

  # Rose Pine Dawn palette from the official starship port.
  rosePine =
    (fromTOML (builtins.readFile "${inputs.rose-pine-starship}/rose-pine-dawn.toml"))
    .palettes.rose-pine-dawn;
in

{
  programs.bash = {
    enable = true;
    # Runs in every bash, before the "not interactive? stop here" check.
    bashrcExtra = ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh # multi-user Nix
      elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh" # single-user Nix (no sudo)
      fi
    '';
    # Runs only in interactive bash
    initExtra = toFish {
      commandVar = "BASH_EXECUTION_STRING";
      isLogin = "shopt -q login_shell";
    };
  };

  # macOS's login shell is zsh: the same hand-off from there.
  programs.zsh = {
    enable = pkgs.stdenv.hostPlatform.isDarwin;
    # (first thing in .zshrc, before zsh sets up completion it won't use)
    initContent = lib.mkBefore (toFish {
      commandVar = "ZSH_EXECUTION_STRING";
      isLogin = "[[ -o login ]]";
    });
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting # no startup banner
      fish_config theme choose "Rosé Pine Dawn" # syntax colours (theme file below)
      # Vim keys: starts in insert mode, Esc for normal mode. The cursor
      # shape shows the mode, as in nvim (starship's ❯ turns to ❮ too).
      set -g fish_key_bindings fish_vi_key_bindings
      set -g fish_cursor_default block
      set -g fish_cursor_insert line
      set -g fish_cursor_replace_one underscore
      set -g fish_cursor_visual block
    '';

    # Calculator shortcut
    functions.c = "math $argv";

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

  # Prompt, identical in bash and fish on every machine
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

  # direnv: entering a folder with an .envrc loads its environment (`use
  # flake` for a project's dev shell, cached by nix-direnv), and leaving
  # unloads it, all in the same fish. `direnv allow` once per project.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global.hide_env_diff = true; # no list of every variable changed
  };

  programs.atuin = {
    enable = true;
    # Don't bind `?` to Atuin AI.
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
      # transcript files, synced like history.
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
  programs.atuin.themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-atuin}/dist/rose-pine-dawn.toml";
}
