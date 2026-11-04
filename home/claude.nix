# Claude Code, its settings and status line.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # numtide/llm-agents.nix: updated daily
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Status line script.
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
  programs.claude-code = {
    enable = true;
    package = llm.claude-code;

    # Merge the settings below into ~/.claude/settings.json on each switch.
    mutableSettings = true;
    settings = {
      statusLine = {
        type = "command";
        command = lib.getExe statusline;
      };
      # Claude's own light palette; relies on COLORTERM=truecolor (default.nix)
      theme = "light";
      tui = "fullscreen";
      autoCompactEnabled = true;
      idleCompaction = false;
      permissions.defaultMode = "auto";
      skipAutoPermissionPrompt = true; # no one-time auto-mode notice per machine
    };
  };
}
