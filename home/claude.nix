{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [
      pkgs.jq
      config.programs.git.package # the git configured in git.nix
      pkgs.hostname
    ];
    text = builtins.readFile ./claude/statusline.sh;
  };
in
{
  # In Zellij, a new Claude conversation gets its id on its command line,
  # where Zellij saves it, so a resurrected pane resumes that one (the
  # discovery hook in zellij.nix).
  programs.fish.functions.claude = {
    wraps = "claude";
    body = /* fish */ ''
      # Not for what already picks a conversation, print mode, or a
      # subcommand (as `claude --help` lists them).
      set -l subcommands agents attach auth auto-mode doctor gateway import install logs \
        mcp plugin plugins purge respawn rm setup-token stop kill ultrareview update upgrade
      if set -q ZELLIJ
          and not contains -- "$argv[1]" $subcommands
          and not string match -qr -- '^(-r|--resume|-c|--continue|--session-id|--fork-session|-p|--print)(=.*)?$' $argv
        command claude --session-id (${lib.getExe' pkgs.util-linux "uuidgen"}) $argv
      else
        command claude $argv
      end
    '';
  };

  programs.claude-code = {
    enable = true;
    package = llm.claude-code;

    # Merge the settings below on each switch.
    mutableSettings = true;

    settings = {
      statusLine = {
        type = "command";
        command = lib.getExe statusline;
      };
      # Claude's own light palette; relies on COLORTERM=truecolor (default.nix)
      theme = "light";
      editorMode = "vim";
      tui = "fullscreen";
      autoCompactEnabled = true;
      idleCompaction = false;
      permissions.defaultMode = "auto";
      skipAutoPermissionPrompt = true; # no one-time auto-mode notice per machine
    };
  };
}
