#!/usr/bin/env bash
# Set up (or update) this machine from github.com/ConorWilliams/nix:
#
#   curl -fsSL https://raw.githubusercontent.com/ConorWilliams/nix/main/bootstrap.sh | bash
#
# What it does:
#   1. Checks Nix (warns if old) and turns on flakes for this user if off.
#   2. Clones ~/nix over HTTPS, or pulls it if it's already there.
#   3. Picks the config: <user>@<hostname> if flake.nix lists this machine,
#      else plain <user> (the server layer).
#   4. Ubuntu desks: offers `apt install i3` (sudo) and kitty's installer.
#   5. Switches Home Manager (-b backup moves files in the way to *.backup).
#   6. Offers the gh and atuin logins, then moves the repo's remote to SSH
#      once a GitHub key works.
#
# Safe to re-run: it pulls, switches, and skips whatever is already done.
# Needs Nix already installed (it never installs or upgrades it), and asks
# before anything that uses sudo.
set -euo pipefail

repo=https://github.com/ConorWilliams/nix.git
dir=$HOME/nix
nix_min=2.31 # nh warns below this

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
# Answers come from the terminal: under `curl | bash`, stdin is this script.
ask() {
  local answer
  read -rp "$1 [y/N] " answer </dev/tty || return 1
  [[ $answer == [yY]* ]]
}

# Everything runs inside main, called on the last line: under `curl | bash`
# that makes bash read the whole script before running any of it, so a
# command reading stdin can't swallow the rest.
main() {
  say "Nix"
  if ! type -P nix >/dev/null; then
    echo "Nix isn't installed. Install it (multi-user), open a new shell, re-run:"
    echo "  sh <(curl -L https://nixos.org/nix/install) --daemon"
    exit 1
  fi
  version=$(command nix --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
  echo "Nix $version"
  if [[ $(printf '%s\n' "$nix_min" "$version" | sort -V | head -1) != "$nix_min" ]]; then
    echo "Older than $nix_min (nh will warn). To upgrade: sudo -i nix upgrade-nix"
  fi
  # The official installer leaves flakes off; turn them on for this user.
  nix() { command nix --extra-experimental-features 'nix-command flakes' "$@"; }
  if ! nix config show experimental-features | grep -qw flakes; then
    mkdir -p ~/.config/nix
    echo 'experimental-features = nix-command flakes' >>~/.config/nix/nix.conf
    echo "Turned on flakes in ~/.config/nix/nix.conf"
  fi

  # git from Nix if the system has none
  git() { if type -P git >/dev/null; then command git "$@"; else nix run nixpkgs#git -- "$@"; fi; }

  say "Repo: $dir"
  if [[ -d $dir/.git ]]; then
    git -C "$dir" pull --ff-only
  else
    git clone "$repo" "$dir" # HTTPS: public, so no login needed yet
  fi

  # Which config: <user>@<hostname> if the flake lists this machine, else
  # plain <user> (the server layer).
  user=$(id -un)
  host=$(hostname -s)
  config=$(nix eval --raw "$dir#homeConfigurations" --apply "c:
    if c ? \"$user@$host\" then \"$user@$host\" else if c ? \"$user\" then \"$user\" else \"\"")
  if [[ -z $config ]]; then
    echo "No config for user '$user' (the users are listed in flake.nix)."
    exit 1
  fi
  desk=false
  [[ $config == *@* ]] && desk=true

  # Ubuntu desks: the few things that can't come from Nix (see README).
  if $desk && [[ $(uname -s) == Linux ]]; then
    say "Ubuntu desk extras"
    if dpkg -s i3 >/dev/null 2>&1; then
      echo "i3 installed"
    elif ask "Install i3 with apt (the i3 login session and i3lock; uses sudo)?"; then
      sudo apt-get install -y i3
    fi
    if [[ -x ~/.local/kitty.app/bin/kitty ]]; then
      echo "kitty installed"
    elif ask "Install kitty with its own installer (into ~/.local/kitty.app)?"; then
      curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    fi
  fi

  say "Home Manager: $config"
  # -b backup renames files in the way (e.g. the starter .bashrc) to *.backup
  nix run --inputs-from "$dir" home-manager -- switch -b backup --flake "$dir#$config"
  export PATH=$HOME/.nix-profile/bin:$PATH # the tools it just installed

  say "Logins"
  if gh auth status >/dev/null 2>&1; then
    echo "gh logged in"
  elif ask "Log in to GitHub (gh)?"; then
    echo "No browser here? Open https://github.com/login/device anywhere and enter the code."
    if $desk; then
      gh auth login --web --git-protocol ssh </dev/tty # also creates and uploads an SSH key
    else
      gh auth login --web --skip-ssh-key </dev/tty # git uses your forwarded agent
    fi
  fi
  # Push over SSH once a key works (a desk's own, or a server's forwarded agent)
  github=$(ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 || true)
  if [[ $(git -C "$dir" remote get-url origin) == https://* && $github == *"successfully authenticated"* ]]; then
    git -C "$dir" remote set-url origin git@github.com:ConorWilliams/nix.git
    echo "Repo remote switched to SSH"
  fi

  if atuin status 2>/dev/null | grep -q '^Username:'; then
    echo "atuin logged in"
  elif ask "Log in to atuin (shell history sync; have the key from your password manager)?"; then
    atuin login </dev/tty
    atuin daemon restart # it started with a temporary key before the login
    atuin sync
  fi

  say "Done"
  echo "Open a new terminal (or log in again) to start fish with everything."
  echo "Other logins (Claude, codex, Copilot): see the README."
  if $desk && [[ $(uname -s) == Linux ]]; then
    echo "First time on this desk: log out and pick the \"i3\" session."
  fi
}

main "$@"
