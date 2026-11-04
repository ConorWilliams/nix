#!/usr/bin/env bash

set -euo pipefail

repo=https://github.com/ConorWilliams/nix.git
dir=$HOME/nix

# Pretty output
say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Answers come from the terminal: under `curl | bash`, stdin is this script.
ask() {
  local answer
  read -rp "$1 [y/N] " answer </dev/tty || return 1
  [[ $answer == [yY]* ]]
}

# Home Manager's -b backs up regular files, but rejects foreign symlinks.
# Move only links that collide with files in the built generation. Never follow
# the links into an existing dotfile checkout or move links owned by HM.
backup_home_symlinks() {
  local generation=$1 suffix=$2 store_dir=$3 home_dir=$4
  local source relative target link parent backup
  while IFS= read -r -d '' source; do
    relative=${source#"$generation/home-files/"}
    target=$home_dir/$relative
    [[ -L $target ]] || continue
    link=$(readlink "$target")
    [[ $link == "$store_dir/"*-home-manager-files/* ]] && continue

    # Moving a link through a symlinked parent could change the old checkout.
    parent=${target%/*}
    while [[ $parent != "$home_dir" ]]; do
      if [[ -L $parent ]]; then
        echo "Cannot back up $target through symlinked parent $parent."
        return 1
      fi
      parent=${parent%/*}
    done
    backup=$target.$suffix
    if [[ -e $backup || -L $backup ]]; then
      echo "Backup already exists: $backup"
      return 1
    fi
    echo "Backing up symlink: $target -> $backup"
    mv -- "$target" "$backup"
  done < <(find -H "$generation/home-files" -type l -print0)
}

main() {
  say "Nix"
  if ! type -P nix >/dev/null; then
    echo "Nix isn't installed. Install it, open a new shell, re-run"
    exit 1
  fi
  echo "Nix $(command nix --version | grep -oE '[0-9]+\.[0-9]+' | head -1)"

  # The official installer leaves flakes off; turn them on for this user
  # (asking the real nix: the wrapper below always passes the flag).
  if ! command nix config show experimental-features 2>/dev/null | grep -qw flakes; then
    mkdir -p ~/.config/nix
    echo 'extra-experimental-features = nix-command flakes' >>~/.config/nix/nix.conf
    echo "Turned on flakes in ~/.config/nix/nix.conf"
  fi
  # ...and for this run, whatever nix.conf says.
  nix() { command nix --extra-experimental-features 'nix-command flakes' "$@"; }

  # git from Nix if the system has none
  git() { if type -P git >/dev/null; then command git "$@"; else nix run nixpkgs#git -- "$@"; fi; }

  say "Repo: $dir"
  if [[ -d $dir/.git ]]; then
    # A local setup branch may have no upstream. Apply that checkout rather
    # than pulling main into it or changing branches behind the user's back.
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

  # Catch user-environment build failures before changing system settings.
  say "Build Home Manager: $config"
  home_generation=$(nix build --no-link --print-out-paths "$dir#homeConfigurations.\"$config\".activationPackage")

  # Ubuntu desks: the few things that can't come from Nix.
  if $desk && [[ $(uname -s) == Linux ]]; then
    say "Ubuntu desk extras"
    # Only what Nix can't provide: the login screen's "i3" session entry
    # (i3-wm) and a locker that can use Ubuntu's PAM (i3lock). i3 itself
    # and everything else come from Nix.
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

  # The Mac: Homebrew (nix-darwin installs apps such as kitty with it, but
  # doesn't install Homebrew itself), then the system settings.
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
      sudo "$(type -P nix)" --extra-experimental-features 'nix-command flakes' \
        run --inputs-from "$dir" nix-darwin#darwin-rebuild -- switch --flake "$dir#$host"
    elif [[ ! -e /run/current-system ]]; then
      echo "The first Mac setup needs nix-darwin before Home Manager; stopping."
      exit 1
    fi
  fi

  say "Home Manager: $config"
  # Preserve existing files/symlinks without following them into their targets. A
  # unique suffix also avoids clobbering backups from a previous attempt.
  backup_suffix="before-home-manager-$(date +%Y%m%d-%H%M%S)-$$"
  store_dir=$(nix eval --raw --expr builtins.storeDir)
  backup_home_symlinks "$home_generation" "$backup_suffix" "$store_dir" "$HOME"
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
    echo "First time on this desk: log out and pick the \"i3\" session."
  fi
}

main "$@"
