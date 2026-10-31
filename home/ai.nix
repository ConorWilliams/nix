# AI coding CLIs, from numtide/llm-agents.nix (see flake.nix).
# Their packages already disable the CLIs' own auto-updaters; update with
# `nix flake update llm-agents`. Logins stay per machine, outside Nix.
{ pkgs, inputs, ... }:

let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  home.packages = [
    llm.claude-code
    llm.codex
  ];
}
