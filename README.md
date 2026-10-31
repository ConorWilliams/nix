# nix

My terminal environment, managed with Nix + Home Manager.

## Layout

```
flake.nix            users, roles, mkHome, checks, formatter
home/common.nix      every machine; imports the files below
  git.nix            git, delta, lazygit, lfs
  shell.nix          bash -> fish, starship, atuin, zoxide
  claude.nix         Claude Code: settings, status line (claude/)
  ssh.nix            SSH client: agent forwarding to work hosts
  zellij.nix         zellij: theme, modal keys (zellij/)
  neovim.nix         placeholder until the neovim step
home/desk.nix        machines you sit at, any OS: kitty config, font, codex
home/desk-linux.nix  Linux desks: i3
home/desk-mac.nix    the Mac
home/hubble.nix      hubble-only hardware tweaks
darwin/mac.nix       Mac system settings only
```

Configs are named `<user>@<machine>`: users `conor`/`conix`; machines
`hubble`, `luna` (laptop), `mac`, and `server` (shared by every work server).

## Set up a new machine

1. Install Nix (Determinate installer). For a new user on a machine that
   already has Nix: `sudo useradd -m -s /bin/bash <user>`. If Nix says
   "experimental Nix feature 'flakes' is disabled" (the official nixos.org
   installer leaves them off), turn them on for your user:

   ```sh
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```
2. Log in to GitHub and clone. On a **server**, skip the login: your
   forwarded SSH agent already lets git through (`ssh-add -l` should list a
   key), so just `git clone`. On a **desk**, `gh` isn't installed yet, so
   borrow it:

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
   nix run --inputs-from ~/nix home-manager -- switch -b backup --flake ~/nix#conix@<machine>
   ```

4. Log in again (bash now starts fish), then do the per-machine logins
   below.
5. Desks (hubble, luna) also need things from outside Nix, since Nix-built
   GUI apps can't use Ubuntu's graphics drivers:

   ```sh
   sudo apt install i3   # the login screen's "i3" session, and i3lock
   curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin  # kitty
   ```

   GUI apps stay with apt/snap: google-chrome, thunderbird, code (apt);
   slack, obsidian (snap). Then log out and pick the "i3" session.

The Mac also has system settings, applied separately:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix#mac  # first time
sudo darwin-rebuild switch --flake ~/nix#mac                                # after that
```

## Logging in to things (per machine, never in Nix)

Every login works over SSH: the tool shows a URL or code, you open it in
the browser on whatever machine you're sitting at, and the terminal carries
on by itself (or asks you to paste a code back).

| What | Command | Notes |
| --- | --- | --- |
| git (servers) | nothing | The SSH agent is forwarded to short hostnames (`home/ssh.nix`), so servers use your desk's key and hold none. Connect with plain `ssh` from a machine whose agent has a key. |
| git + gh (desks) | `gh auth login --web --git-protocol ssh` | Creates and uploads this machine's SSH key. |
| gh (servers) | `gh auth login --web --skip-ssh-key` | Token only, for `gh pr`, `gh run` etc.; git itself uses the forwarded agent. |
| atuin | `atuin login`, then `atuin daemon restart`, then `atuin sync` | No `-u`: that's the old password login. Then paste the atuin key (password manager). The restart matters: the daemon started before login with a temporary key and keeps using it until restarted. |
| Claude | `claude`, then log in | First run asks for a theme: pick Light (the declared one). No browser: press `c` to copy the URL, open it, paste the code back. Stored in `~/.claude/.credentials.json`. |
| codex | `codex login --device-auth` | Device code, like gh. |

gh's device page is https://github.com/login/device; "Failed opening a web
browser" just means it's waiting for you to go there.

## Day to day

```sh
home-manager switch --flake .#conix@hubble # apply changes (this machine's name)
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too (~7s)
```

## Notes

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
  the daemon. Keep the `atuin key` in the password manager. Only ever use
  the pinned atuin: brew's newer one once built a threads index the pinned
  one couldn't open.
- **mosh:** has no scrollback, so the mouse wheel sends Up (opening atuin).
  Run zellij inside it: `mosh host -- zellij attach -c main`. Over ssh,
  add `-t` (`ssh -t host zellij attach -c main`): without a terminal,
  zellij crashes, and the half-started session has no `TERM`; delete it
  with `zellij delete-session main --force`.
- **Linux GUI apps:** stay with apt/snap/vendor installers. Making Nix GUI
  apps work needs `targets.genericLinux.gpu`: sudo, plus pinning the exact
  NVIDIA driver version (hubble's display is on the 4090) and re-pinning
  after every driver update. Not an option on work-managed machines.
- **Servers:** add `nix.gc` (a systemd user timer, so needs
  `loginctl enable-linger`). `home.sessionVariables` only reach login
  shells.
- **Neovim:** live-editing the config via `mkOutOfStoreSymlink` relies on
  the repo always living at `~/nix`.
