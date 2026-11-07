#!/usr/bin/env bash

set -euo pipefail

repo=https://github.com/ConorWilliams/nix.git
dir=$HOME/nix

# Pretty output
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Read prompts from the terminal, even when stdin is redirected.
ask() {
  local answer
  read -rp "$1 [y/N] " answer </dev/tty || return 1
  [[ $answer == [yY]* ]]
}

main() {
  say "Nix"
  if ! type -P nix >/dev/null; then
    echo "Nix isn't installed. Install it, open a new shell, re-run"
    exit 1
  fi
  echo "Nix $(command nix --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"

  # Keep flakes enabled after the first run's command-line flags.
  if ! command nix config show experimental-features 2>/dev/null | grep -qw flakes; then
    local nix_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nix"
    mkdir -p "$nix_config_dir"
    printf '\nextra-experimental-features = nix-command flakes\n' >>"$nix_config_dir/nix.conf"
    echo "Turned on flakes in $nix_config_dir/nix.conf"
  fi

  # git from Nix if the system has none
  git() { if type -P git >/dev/null; then command git "$@"; else nix run nixpkgs#git -- "$@"; fi; }

  say "Repo: $dir"
  if [[ -d $dir/.git ]]; then
    if git -C "$dir" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
      git -C "$dir" pull --ff-only || echo "Couldn't fast-forward $dir (local changes or commits?); using it as it is."
    else
      echo "Using the existing checkout (no upstream configured)."
    fi
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
  # The plain-<user> (server) config is Linux x86_64; anything else (the
  # Mac) needs its own entry under hosts in flake.nix.
  if [[ $config == "$user" && $(uname -sm) != "Linux x86_64" ]]; then
    echo "No config for this machine ($host, $(uname -sm)): add it to hosts in flake.nix."
    exit 1
  fi
  desk=false
  [[ $config == *@* ]] && desk=true

  # Catch build failures before changing system settings.
  say "Build Home Manager: $config"
  nix build --no-link "$dir#homeConfigurations.\"$config\".activationPackage"

  # Ubuntu: the few things that can't come from Nix.
  if $desk && [[ $(uname -s) == Linux ]]; then
    say "Ubuntu desk extras"
    if dpkg -s i3-wm i3lock >/dev/null 2>&1; then
      echo "i3-wm and i3lock installed"
    elif ask "Install i3-wm and i3lock with apt (login session entry, screen lock; uses sudo)?"; then
      sudo apt-get install -y --no-install-recommends i3-wm i3lock
    fi
    if [[ -x ~/.local/kitty.app/bin/kitty ]]; then
      echo "kitty installed"
    elif ask "Install kitty with its own installer (into ~/.local/kitty.app)?"; then
      curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    fi
  fi

  # The Mac: Homebrew, then the system settings.
  if [[ $(uname -s) == Darwin ]]; then
    say "Mac system settings"
    if type -P brew >/dev/null || [[ -x /opt/homebrew/bin/brew ]]; then
      echo "Homebrew installed"
    elif ask "Install Homebrew (for the Mac's apps, e.g. kitty; uses sudo)?"; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" </dev/tty
    else
      echo "Homebrew is required for the Mac's declared apps; stopping before activation."
      exit 1
    fi
    if [[ $(nix eval "$dir#darwinConfigurations" --apply "c: c ? \"$host\"") != true ]]; then
      echo "flake.nix has no darwinConfigurations.$host (name it after this Mac); skipping."
    elif ask "Apply the Mac's system settings with nix-darwin (uses sudo)?"; then
      sudo -H "$(type -P nix)" --extra-experimental-features 'nix-command flakes' \
        run --inputs-from "$dir" nix-darwin#darwin-rebuild -- switch --flake "$dir#$host"
    elif [[ ! -e /run/current-system ]]; then
      echo "The first Mac setup needs nix-darwin before Home Manager; stopping."
      exit 1
    fi
  fi

  say "Home Manager: $config"
  # Existing dotfiles in the way are kept, renamed with a suffix unique to
  # this run.
  backup_suffix="before-home-manager-$(date +%Y%m%d-%H%M%S)-$$"
  nix run --inputs-from "$dir" home-manager -- switch \
    -b "$backup_suffix" --flake "$dir#$config"
  export PATH=$HOME/.nix-profile/bin:$PATH # the tools it just installed

  say "Logins"
  # git authenticates to GitHub through gh's token, over HTTPS (programs.gh in home/default.nix).
  if gh auth status >/dev/null 2>&1; then
    echo "gh logged in"
  elif $desk; then
    if ask "Log in to GitHub (gh, in a browser)?"; then
      gh auth login --web --git-protocol https --skip-ssh-key </dev/tty || echo "gh login failed; rerun: gh auth login"
    fi
  elif ask "Log in to GitHub (gh) with a fine-grained token for this server?"; then
    echo "Create one at https://github.com/settings/personal-access-tokens:"
    echo "only the repos needed here, Contents read/write, and an expiry."
    local token
    read -rsp "Paste it (not shown): " token </dev/tty
    echo
    if printf '%s\n' "$token" | gh auth login --with-token; then
      gh auth status | grep -i 'logged in' || true
    else
      echo "gh login failed; rerun: gh auth login --with-token"
    fi
  fi

  if atuin status 2>/dev/null | grep -q '^Username:'; then
    echo "atuin logged in"
  elif ask "Log in to atuin (shell history sync; needs the key from a password manager)?"; then
    atuin login </dev/tty
    atuin daemon restart # it started with a temporary key before the login
    atuin sync
  fi

  say "Done"
  echo "Open a new terminal (or log in again) to start fish with everything."
  if $desk && [[ $(uname -s) == Linux ]]; then
    echo "First time on this machine: log out and pick the \"i3\" session."
  fi
}

main "$@"
