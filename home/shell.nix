# Shells: the system's login shell stays as it is and hands interactive
# sessions over to fish
{
  config,
  lib,
  pkgs,
  inputs,
  dawn,
  ...
}:

let
  # The hand-off, not when the parent is already fish (so typing `bash` inside
  # fish gives bash), not for `-ic 'cmd'` (tools probing the environment), not
  # in nix-shell / nix develop.
  toFish =
    { commandVar, isLogin }:
    /* bash */ ''
      if [[ $(ps -o comm= -p $PPID) != *fish* && -z ''${${commandVar}:-} && -z ''${IN_NIX_SHELL:-} ]]; then
        ${isLogin} && exec ${lib.getExe config.programs.fish.package} --login
        exec ${lib.getExe config.programs.fish.package}
      fi
    '';

in

{
  programs.bash = {
    enable = true;
    # Runs in every bash, before the "not interactive? stop here" check.
    bashrcExtra = /* bash */ ''
      if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
        . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh # multi-user Nix
      elif [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh" # single-user Nix (no sudo)
      fi
      # Home Manager's variables, for commands over ssh (`ssh host cmd`,
      # zzh's zellij), which only get this far. (The file loads once per
      # session: elsewhere it's already loaded, and this does nothing.)
      . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
    '';
    # Runs only in interactive bash; first (Home Manager loads completion
    # at order 100 and fzf at 200), as fish sets those up for itself.
    initExtra = lib.mkOrder 50 (toFish {
      commandVar = "BASH_EXECUTION_STRING";
      isLogin = "shopt -q login_shell";
    });
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
    interactiveShellInit = lib.mkMerge [
      (/* fish */ ''
        set -g fish_greeting # no startup banner
        fish_config theme choose "Rosé Pine Dawn" # syntax colours (theme file below)
        # Vim keys: starts in insert mode, Esc for normal mode. The cursor
        # shape shows the mode, as in nvim (starship's ❯ turns to ❮ too).
        set -g fish_key_bindings fish_vi_key_bindings
        set -g fish_cursor_default block
        set -g fish_cursor_insert line
        set -g fish_cursor_replace_one underscore
        set -g fish_cursor_visual block
      '')
      (lib.mkAfter /* fish */ ''
        bind -M insert space __space
        bind -M default space __space
      '')
    ];

    # Only Fish knows whether the command line is empty. Everything after
    # this hand-off is handled by Zellij's native modes. This targets the
    # shell's own session; Alt-g also works while a remote program owns input.
    functions.__space = /* fish */ ''
      if set -q ZELLIJ; and not commandline --paging-mode; and begin; test "$fish_bind_mode" = default; or test -z "$(commandline)"; end
        ${lib.getExe config.programs.zellij.package} action switch-mode normal
      else if test "$fish_bind_mode" = default
        commandline -f forward-char
      else
        commandline --insert ' '
        commandline -f expand-abbr
        if test "$(commandline)" = "g "
          commandline ""
          __zoxide_zi
        end
      end
      commandline -f repaint
    '';

    # c: fend, a calculator
    functions.c = {
      description = "Calculator (fend): a REPL, or evaluate the arguments";
      wraps = "fend";
      body = "fend $argv";
    };

    # starship's shrunk prompt after a command runs
    functions.starship_transient_prompt_func = "starship module character $argv";

    # sudo searches its own PATH (secure_path), without ~/.nix-profile/bin,
    # so `sudo dust` isn't found: give it the program's full path from this
    # shell's PATH.
    functions.sudo = {
      description = "sudo, finding programs on this shell's PATH (Nix's too)";
      wraps = "sudo";
      body = /* fish */ ''
        # (an option such as -u is no program, so it fails `command -s` too)
        if set -q argv[1]; and set -l exe (command -s -- $argv[1])
          command sudo $exe $argv[2..]
        else
          command sudo $argv
        end
      '';
    };

    functions.zzh = {
      description = "Zellij over SSH: new session, or join/create a named one";
      wraps = "ssh";
      body = /* fish */ ''
        if test (count $argv) -lt 1; or test (count $argv) -gt 2; or test -z "$argv[1]"; or string match -q -- '-*' $argv[1]
          echo 'Usage: zzh host [session]' >&2
          return 2
        end
        set -l remote zellij
        if set -q argv[2]
          if test -z "$argv[2]"; or string match -qr '[/\r\n]' -- $argv[2]
            echo 'zzh: session names must be nonempty and cannot contain / or line breaks' >&2
            return 2
          end
          # SSH joins its command arguments into shell text: quote for the remote shell.
          set -l session (string replace --all "'" "'\\'''" -- $argv[2])
          set remote "zellij attach -c -- '$session'"
        end
        ssh -t -- $argv[1] $remote
      '';
    };
    functions.zosh = {
      wraps = "mosh";
      body = "mosh $argv -- zellij";
    };
  };

  # Prompt for all shells
  programs.starship = {
    enable = true;
    enableTransience = true;
    settings = {
      add_newline = false;
      # Only these modules, in this order, to keep the prompt short.
      format = "$hostname$directory$git_branch$python$cmd_duration$status$character";
      hostname.format = "[$hostname]($style) ";
      git_branch.format = "\\[[$branch(:$remote_branch)]($style)\\] "; # [branch], no "on"
      cmd_duration.format = "[$duration]($style) "; # 4s, not "took 4s"
      python.format = "[($virtualenv )]($style)"; # active venv name only
      # Show the exit code when a command fails, as a red [127].
      status = {
        disabled = false;
        format = "[\\[$status\\]]($style) ";
      };
      palette = "rose-pine-dawn";
      palettes.rose-pine-dawn = {
        red = dawn.love;
        green = dawn.pine;
        yellow = dawn.gold;
        blue = dawn.foam;
        purple = dawn.iris;
        cyan = dawn.rose;
      };
    };
  };

  # direnv: entering a folder with an .envrc loads its environment
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
      filter_mode_shell_up_key_binding = "global";
      inline_height = 0; # full screen
      # Enter runs the picked command straight away; Tab puts it in the
      # prompt to edit first.
      enter_accept = true;
      theme.name = "rose-pine-dawn"; # (themes, below)

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
    # Rose Pine Dawn for the search UI: the official port's theme file.
    themes.rose-pine-dawn = builtins.readFile "${inputs.rose-pine-atuin}/dist/rose-pine-dawn.toml";
  };

  # `z foo` jumps to the most-used directory matching foo; `zi` picks with fzf.
  programs.zoxide.enable = true;
  # Fuzzy `zi` (zoxide's own fzf options include --exact).
  home.sessionVariables._ZO_FZF_OPTS = "${config.home.sessionVariables.FZF_DEFAULT_OPTS} --height=45% --layout=reverse --tiebreak=index";

  # Rose Pine Dawn for fish's syntax colours: the official port's theme
  # file, selected above.
  xdg.configFile."fish/themes/Rosé Pine Dawn.theme".source =
    "${inputs.rose-pine-fish}/themes/Rosé Pine Dawn.theme";
}
