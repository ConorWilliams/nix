{ pkgs, zellij }:

# Installed on every host: run locally or with `ssh -t host anon-zellij`.
# The client owns the original anon-* name: exiting or detaching kills that
# session; renaming it lets it survive. This is disposable, unlike plain Zellij.
pkgs.writeShellApplication {
  name = "anon-zellij";
  runtimeInputs = [
    zellij
    pkgs.rust-petname
  ];
  text = /* bash */ ''
    # Ignore inherited session identity (e.g. a new Kitty launched from a pane).
    # This permits nesting; it does not escape the outer terminal multiplexer.
    unset ZELLIJ ZELLIJ_SESSION_NAME ZELLIJ_PANE_ID
    existing=$(zellij list-sessions -sn 2>/dev/null || true)
    while :; do
      session="anon-$(petname --words 2)"
      # Compare whole names so we never intentionally attach to an existing one.
      [[ $'\n'"$existing"$'\n' != *$'\n'"$session"$'\n'* ]] && break
    done
    cleanup() {
      # Always target the original name: a renamed session is intentionally kept.
      zellij kill-session "$session" >/dev/null 2>&1 || true
    }
    # Best-effort cleanup on terminal/SSH closure too; SIGKILL cannot run traps.
    trap cleanup EXIT
    trap 'exit' HUP INT TERM
    zellij --session "$session" "$@"
  '';
}
