{ pkgs, zellij }:

# Naming only: the background plugin owns cleanup when the last client leaves.
pkgs.writeShellApplication {
  name = "anon-zellij";
  runtimeInputs = [
    zellij
    pkgs.rust-petname
  ];
  text = /* bash */ ''
    unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID
    exec zellij --session "anon-$(petname --words 2)" "$@"
  '';
}
