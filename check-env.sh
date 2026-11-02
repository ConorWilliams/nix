#!/usr/bin/env bash
# Checks how this machine's shells and desktop get their environment, after
# a switch (or a login): each way in should end up with Home Manager's
# variables, PATH without repeats, ~/.local/bin (and on the desks kitty's
# folder) ahead of Nix's, and Nix's data folders ahead of Ubuntu's. Run it
# by hand; it changes nothing.
#
#   ./check-env.sh          simulated logins and shells
#   ./check-env.sh --live   also the running desktop (only meaningful after
#                           logging in again: Home Manager's variables load
#                           once per login, so a switch reaches new logins)
set -uo pipefail

base=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin
fish=$HOME/.nix-profile/bin/fish
login='. /etc/profile; . ~/.profile'
failed=0

# kitty's folder comes second where there is one (the desks).
first=
[[ -d $HOME/.local/kitty.app/bin ]] && first=$HOME/.local/kitty.app/bin:

# nixFirst <XDG_DATA_DIRS>: Nix's data folders come before Ubuntu's (or it's
# unset). Trailing slashes (/usr/share/) don't count.
nixFirst() {
  local dirs
  dirs=:$(sed 's|/*:|:|g; s|/*$||' <<<"$1"):
  [[ $dirs == :: ]] && return 0
  # (what follows Nix's entry, from its closing colon, has Ubuntu's)
  [[ $dirs == *":$HOME/.nix-profile/share:"* && ${dirs#*":$HOME/.nix-profile/share"} == *":/usr/share:"* ]]
}

fail() {
  failed=1
  echo "FAIL  $1"
  shift
  printf '        %s\n' "$@"
}

# report <name>: checks an environment (`env -0` output) on stdin.
report() {
  local name=$1 envs path data d
  envs=$(tr '\0' '\n')
  path=$(grep '^PATH=' <<<"$envs" | cut -d= -f2-)
  data=$(grep '^XDG_DATA_DIRS=' <<<"$envs" | cut -d= -f2-)
  local problems=()
  d=$(tr : '\n' <<<"$path" | sort | uniq -d | tr '\n' ' ')
  [[ -n $d ]] && problems+=("PATH repeats: $d")
  [[ $path == "$HOME/.local/bin:$first"* ]] || problems+=("PATH starts: ${path:0:100}")
  [[ :$path: == *":$HOME/.nix-profile/bin:"* ]] || problems+=("no ~/.nix-profile/bin on PATH")
  if ! nixFirst "$data"; then
    problems+=("XDG_DATA_DIRS: Nix's after Ubuntu's: ${data:0:100}")
  fi
  grep -q '^NH_FLAKE=.' <<<"$envs" || problems+=("NH_FLAKE missing")
  grep -q '^EDITOR=nvim$' <<<"$envs" || problems+=("EDITOR is '$(grep '^EDITOR=' <<<"$envs")'")
  if ((${#problems[@]})); then fail "$name" "${problems[@]}"; else echo "ok    $name"; fi
}

echo "Simulated:"
env -i HOME="$HOME" PATH=$base sh -c "$login; env -0" | report "login (tty, ssh, desktop)"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c 'env -0'" | report "fish"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c '$fish -c \"$fish -c \\\"env -0\\\"\"'" |
  report "fish in fish in fish"
env -i HOME="$HOME" PATH=$base sh -c "$login; $fish -c 'bash -c \"bash -ic \\\"env -0\\\"\"'" 2>/dev/null |
  report "bash in bash in fish"
# (sshd runs `bash -c cmd`, which reads .bashrc as SSH_CLIENT is set)
env -i HOME="$HOME" PATH=$base SSH_CLIENT="10.0.0.1 1 22" bash -c 'env -0' | report "ssh host cmd"

if [[ ${1-} == --live ]]; then
  echo "Running (the newest of each):"
  for name in i3 dunst kitty zellij; do
    pid=$(pgrep -n -u "$USER" -x "$name") && report "$name ($pid)" <"/proc/$pid/environ"
  done
  # The next desktop login starts from the systemd user manager's
  # environment: "already loaded" marks there would make it skip Home
  # Manager's or Nix's setup, and a GNOME login's leftovers confuse
  # services under i3.
  leftovers=$(systemctl --user show-environment | cut -d= -f1 |
    grep -xE '__HM_SESS_VARS_SOURCED|__ETC_PROFILE_NIX_SOURCED|SESSION_MANAGER|GNOME_DESKTOP_SESSION_ID' |
    tr '\n' ' ')
  desktop=$(systemctl --user show-environment | grep '^XDG_CURRENT_DESKTOP=')
  # (what services it starts, dunst and the portals, find apps and icons in)
  data=$(systemctl --user show-environment | grep '^XDG_DATA_DIRS=' | cut -d= -f2-)
  if [[ -n $leftovers || $desktop != XDG_CURRENT_DESKTOP=i3 ]] || ! nixFirst "$data"; then
    fail "systemd user manager" "leftovers: ${leftovers:-none}" "$desktop" "XDG_DATA_DIRS=${data:0:100}"
  else
    echo "ok    systemd user manager"
  fi
  closing=$(loginctl list-sessions --no-legend | awk -v u="$USER" '$3 == u { print $1 }' |
    while read -r s; do [[ $(loginctl show-session "$s" -p State --value) == closing ]] && echo "$s"; done)
  [[ -z $closing ]] || fail "logins that never finished: $(echo "$closing" | tr '\n' ' ')" \
    "(loginctl session-status <id> shows what holds them)"
fi

exit $failed
