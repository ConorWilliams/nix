#!/usr/bin/env bash
# Checks how this machine's shells and desktop get their environment, after
# a switch (or a login): each way in should end up with Home Manager's
# variables, PATH-like lists without repeats, and ~/.local/bin and kitty's
# folder ahead of the rest. Run it by hand; it changes nothing.
#
#   ./check-env.sh          simulated logins and shells
#   ./check-env.sh --live   also the running desktop's processes
set -uo pipefail

base=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
fish=$HOME/.nix-profile/bin/fish
login='. /etc/profile; . ~/.profile'
failed=0

# report <name>: checks an environment (`env -0` output) on stdin.
report() {
  local name=$1 envs p v d
  envs=$(tr '\0' '\n')
  local problems=()
  for v in PATH XDG_DATA_DIRS XCURSOR_PATH TERMINFO_DIRS; do
    d=$(grep "^$v=" <<<"$envs" | cut -d= -f2- | tr : '\n' | sort | uniq -d | tr '\n' ' ')
    [[ -n $d ]] && problems+=("$v repeats: $d")
  done
  grep -q '^NH_FLAKE=.' <<<"$envs" || problems+=("NH_FLAKE missing")
  grep -q '^EDITOR=nvim$' <<<"$envs" || problems+=("EDITOR is '$(grep '^EDITOR=' <<<"$envs")'")
  p=$(grep '^PATH=' <<<"$envs" | cut -d= -f2-)
  [[ $p == "$HOME/.local/bin:"* ]] || problems+=("PATH starts: ${p:0:100}")
  for v in SESSION_MANAGER GNOME_DESKTOP_SESSION_ID; do
    grep -q "^$v=" <<<"$envs" && problems+=("$v set (a GNOME session's leftover)")
  done
  if ((${#problems[@]})); then
    failed=1
    echo "FAIL  $name"
    printf '        %s\n' "${problems[@]}"
  else
    echo "ok    $name"
  fi
}

# What a login can inherit from a systemd user manager that a GNOME login
# filled, or from an older generation: the "loaded" mark and old values.
stale=(__HM_SESS_VARS_SOURCED=1 EDITOR=vim FZF_DEFAULT_OPTS=--color=16)
stalePath=$HOME/.local/kitty.app/bin:$HOME/.nix-profile/bin:$HOME/.local/kitty.app/bin:$base:/snap/bin

echo "Simulated:"
env -i HOME="$HOME" PATH=$base sh -c "$login; env -0" | report "login (tty, ssh, desktop)"
env -i HOME="$HOME" PATH=$base "${stale[@]}" sh -c "$login; env -0" | report "login, inheriting stale values"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c 'env -0'" | report "fish"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c '$fish -c \"$fish -c \\\"env -0\\\"\"'" |
  report "fish in fish in fish"
env -i HOME="$HOME" PATH="$stalePath" "${stale[@]}" "$fish" -c 'env -0' |
  report "fish, inheriting stale values"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c 'bash -c \"bash -ic \\\"env -0\\\"\"'" 2>/dev/null |
  report "bash in bash in fish"
# (sshd runs `bash -c cmd`, which reads .bashrc as SSH_CLIENT is set)
env -i HOME="$HOME" PATH=$base SSH_CLIENT="10.0.0.1 1 22" bash -c 'env -0' | report "ssh host cmd"

if [[ ${1-} == --live ]]; then
  echo "Running (the newest of each; anything started before the last switch"
  echo "or login can be stale):"
  for name in i3 dunst kitty zellij; do
    pid=$(pgrep -n -u "$USER" -x "$name") && report "$name ($pid)" <"/proc/$pid/environ"
  done
  systemctl --user show-environment | tr '\n' '\0' | report "systemd user manager"
  closing=$(loginctl list-sessions --no-legend | awk -v u="$USER" '$3 == u { print $1 }' |
    while read -r s; do [[ $(loginctl show-session "$s" -p State --value) == closing ]] && echo "$s"; done)
  if [[ -n $closing ]]; then
    failed=1
    echo "FAIL  logins that never finished: $(echo "$closing" | tr '\n' ' ')(loginctl session-status <id>)"
  fi
fi

exit $failed
