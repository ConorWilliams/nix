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

  p = import ./rose-pine-dawn.nix;
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
      theme = "custom:rose-pine-dawn"; # the theme file below
      tui = "fullscreen";
      autoCompactEnabled = true;
      idleCompaction = false; # don't compact sessions I've stepped away from
      permissions.defaultMode = "auto";
      skipAutoPermissionPrompt = true; # no one-time auto-mode notice per machine
    };
  };

  # Claude theme in kitty's Rosé Pine Dawn colours. Tokens not set here fall
  # back to Claude's "light" theme. Token list:
  # https://code.claude.com/docs/en/terminal-config#create-a-custom-theme
  home.file.".claude/themes/rose-pine-dawn.json".text = builtins.toJSON {
    name = "Rosé Pine Dawn";
    base = "light";
    overrides = {
      # Text and accents
      claude = p.rose;
      claudeShimmer = "#ebbcba"; # lighter rose, for the spinner animation
      text = p.text;
      inverseText = p.base;
      inactive = p.muted;
      subtle = p.highlightHigh;
      suggestion = p.iris;
      permission = p.pine;
      remember = p.iris;
      # Status
      success = p.pine;
      error = p.love;
      warning = p.gold;
      merged = p.iris;
      # Input box and modes
      promptBorder = p.highlightHigh;
      planMode = p.foam;
      autoAccept = p.iris;
      bashBorder = p.rose;
      # Diffs: foam/love blended into the base colour (20%; 30% for the
      # changed words; 12% when dimmed)
      diffAdded = "#d9e1dd";
      diffRemoved = "#ecd7d6";
      diffAddedWord = "#c9d7d6";
      diffRemovedWord = "#e5c8ca";
      diffAddedDimmed = "#e6e8e4";
      diffRemovedDimmed = "#f2e3df";
      # Backgrounds
      userMessageBackground = p.overlay;
      userMessageBackgroundHover = p.highlightMed;
      bashMessageBackgroundColor = p.overlay;
      memoryBackgroundColor = p.overlay;
      selectionBg = p.highlightMed;
      composerSidebarBackground = p.surface;
      # Usage meter
      rate_limit_fill = p.pine;
      rate_limit_empty = p.highlightMed;
    };
  };

  home.packages = [
    pkgs.codex # from nixpkgs: a few days behind, but prebuilt (no compiling)
  ];
}
