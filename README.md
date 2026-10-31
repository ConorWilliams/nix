# nix

My terminal environment, managed with Nix + Home Manager.

## Layout

```
flake.nix            users, roles, mkHome, checks, formatter
home/common.nix      every machine; imports the files below
  git.nix            git, delta, lazygit, lfs
  shell.nix          bash -> fish, starship, atuin, zoxide
  ai.nix             claude (+ settings, status line), codex
  neovim.nix         placeholder until the neovim step
  scripts/           scripts packaged by the modules above
home/desk.nix        machines you sit at, any OS
home/desk-linux.nix  Linux desks
home/desk-mac.nix    the Mac
darwin/mac.nix       Mac system settings only
```

Configs are named `<user>@<role>`: users `conor`/`conix`, roles
`desk`/`server`/`mac`.

## Set up a new machine

1. Install Nix (Determinate installer). For a new user on a machine that
   already has Nix: `sudo useradd -m -s /bin/bash <user>`.
2. Log in to GitHub and clone. `gh` isn't installed yet, so borrow it:

   ```sh
   nix run nixpkgs#gh -- auth login --web --git-protocol ssh
   git clone git@github.com:ConorWilliams/nix.git ~/nix
   ```

   gh has no "no browser" option; over SSH it prints "Failed opening a web
   browser" and keeps waiting. Open https://github.com/login/device on any
   machine and enter the code it showed.

   If the clone says `Permission denied (publickey)`, the key upload didn't
   happen: `nix run nixpkgs#gh -- ssh-key add ~/.ssh/id_ed25519.pub`.
   Clone as the user itself: Nix refuses a repo owned by someone else.
3. Activate (`-b backup` renames the starter `.bashrc`/`.profile`):

   ```sh
   nix run --inputs-from ~/nix home-manager -- switch -b backup --flake ~/nix#conix@desk
   ```

4. Log in again (bash now starts fish), then the per-machine logins. None
   of these are in Nix; each prints a URL to open in any browser:

   ```sh
   atuin login        # no -u (that's password login); then the atuin key
   atuin sync
   claude             # then /login
   codex login
   ```

The Mac also has system settings, applied separately:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix#mac  # first time
sudo darwin-rebuild switch --flake ~/nix#mac                                # after that
```

## Day to day

```sh
home-manager switch --flake .#conix@desk   # apply changes
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too (~7s)
```

## Notes for later steps

- **Moving `conor` over:** delete `~/.gitconfig` first. Git reads it after
  Home Manager's `~/.config/git/config`, so it silently wins. Expect the
  first switch to hit existing `.bashrc`/`.profile`/`config.fish`; use
  `home-manager switch -b backup`.
- **Moving `conor` over (shells):** its login shell is apt's fish; switch
  it to bash (`chsh -s /bin/bash`) so Home Manager's bash starts Nix's fish.
  Stop running `brew shellenv`, or linuxbrew shadows Nix tools.
- **atuin account:** created once (`atuin register`, browser flow), with
  history imported from `conor` (`atuin import fish`, `atuin threads
  import`). Outside a shell set up by atuin, those need
  `export ATUIN_SESSION=$(atuin uuid)` first, and `threads import` needs
  the daemon. Keep the `atuin key` in the password manager.
- **mosh:** has no scrollback, so the mouse wheel sends Up (opening atuin).
  Run zellij inside it: `mosh host -- zellij attach -c main`.
- **Linux GUI apps:** consider `targets.genericLinux` (launcher entries,
  terminfo). Its GPU part needs sudo and a driver-version pin on NVIDIA,
  so prefer apt for GL-heavy apps like kitty (`package = null`).
- **Servers:** add `nix.gc` (a systemd user timer, so needs
  `loginctl enable-linger`). `home.sessionVariables` only reach login
  shells.
- **Neovim:** live-editing the config via `mkOutOfStoreSymlink` relies on
  the repo always living at `~/nix`.
