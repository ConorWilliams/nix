# Claude Code, its settings and status line. Logins stay per machine.
# (codex is a plain package in default.nix.)
{ pkgs, inputs, ... }:

let
  # numtide/llm-agents.nix: updated daily, so claude is at most ~a day old.
  # Its package already disables claude's own auto-updater.
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};

  # Status line script, with its own pinned jq and git.
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [
      jq
      git
      hostname
    ];
    text = builtins.readFile ./claude/statusline.sh;
  };
in
{
  programs.claude-code = {
    enable = true;
    package = llm.claude-code; # update with `nix flake update llm-agents`

    # Merge the settings below into ~/.claude/settings.json on each switch.
    # Changes made inside Claude (/config, /model...) work until the next
    # switch; keys not declared here (model, effort, autoMode...) stay local.
    mutableSettings = true;
    settings = {
      statusLine = {
        type = "command";
        command = "${statusline}/bin/claude-statusline";
      };
      # Claude's own light palette; relies on COLORTERM=truecolor (default.nix)
      # to look right over SSH/zellij.
      theme = "light";
      tui = "fullscreen";
      autoCompactEnabled = true;
      idleCompaction = false; # don't compact sessions I've stepped away from
      permissions.defaultMode = "auto";
      skipAutoPermissionPrompt = true; # no one-time auto-mode notice per machine
    };
  };
}
