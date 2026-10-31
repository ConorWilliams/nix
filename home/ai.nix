# AI coding CLIs. Logins stay per machine, outside Nix.
{ pkgs, inputs, ... }:

let
  # numtide/llm-agents.nix: updated daily, so claude is at most ~a day old.
  # Its package already disables claude's own auto-updater.
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    llm.claude-code # update with `nix flake update llm-agents`
    pkgs.codex # from nixpkgs: a few days behind, but prebuilt (no compiling)
  ];
}
