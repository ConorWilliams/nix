{ pkgs, zellij }:

# An anonymous Zellij session that cleans itself up unless renamed.
pkgs.writeShellApplication {
  name = "anon-zellij";
  runtimeInputs = [
    zellij
    pkgs.rust-petname
  ];
  text = /* bash */ ''
    unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID
    existing=$(zellij list-sessions -sn 2>/dev/null || true)
    while :; do
      session="anon-$(petname --words 2)"
      [[ $'\n'"$existing"$'\n' != *$'\n'"$session"$'\n'* ]] && break
    done
    cleanup() {
      zellij kill-session "$session" >/dev/null 2>&1 || true
    }
    trap cleanup EXIT
    trap 'exit' HUP INT TERM
    zellij --session "$session" "$@"
  '';
}
