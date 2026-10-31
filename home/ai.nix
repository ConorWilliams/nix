# AI coding CLIs. Logins stay per machine, outside Nix.
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
    text = builtins.readFile ./scripts/claude-statusline.sh;
  };
in
{
  programs.claude-code = {
    enable = true;
    package = llm.claude-code; # update with `nix flake update llm-agents`
    # Merge only the settings below into ~/.claude/settings.json on each
    # switch; everything Claude writes itself (/model, theme, permissions)
    # is left alone.
    mutableSettings = true;
    settings.statusLine = {
      type = "command";
      command = "${statusline}/bin/claude-statusline";
    };
  };

  home.packages = [
    pkgs.codex # from nixpkgs: a few days behind, but prebuilt (no compiling)
  ];
}
