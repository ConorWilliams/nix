# nix

My terminal environment, managed with Nix + Home Manager.

## Quick start

1. Have Nix (multi-user). If it's missing:
   `sh <(curl -L https://nixos.org/nix/install) --daemon`, then open a new
   shell. Run everything as the user who'll own `~/nix`: Nix refuses a repo
   owned by someone else.
2. Run the bootstrap script. It sets up the machine, or updates it when run
   again; see the comments in [`bootstrap.sh`](bootstrap.sh) for what it does.

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ConorWilliams/nix/main/bootstrap.sh | bash
   ```

3. Open a new terminal, then do the [logins](#logins) it doesn't. On a new
   Ubuntu desk, log out and pick the "i3" session.

The Mac also has system settings, applied separately (not set up yet):

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix#mac  # first time
sudo darwin-rebuild switch --flake ~/nix#mac                                # after that
```

## Layout

```text
flake.nix                users, hosts -> layer, checks, formatter
bootstrap.sh             set up or update a machine
home/default.nix         server layer: every machine; all CLI tools
  git.nix                git, delta, lazygit, lfs
  shell.nix              bash -> fish, starship, atuin, zoxide
  claude.nix             Claude Code: settings, status line (claude/)
  ssh.nix                SSH client: agent forwarding to work hosts
  zellij.nix             zellij: theme, modal keys (zellij/)
  neovim.nix             neovim: tools from Nix, Lua config linked live (nvim/)
  gui/default.nix        GUI layer: desks on any OS: kitty config, font
    ubuntu/default.nix   Ubuntu layer: i3, scrot, xclip, arandr
      hubble.nix         hubble: mouse speed
      luna.nix           luna: font size, touchpad
    mac/default.nix      Mac layer (empty for now)
darwin/mac.nix           Mac system settings (nix-darwin, sudo): not a layer
```

Each layer imports the one above it (server -> gui -> ubuntu -> hubble,
luna; gui -> mac), so a machine only names its last layer. Configs are
`<user>@<hostname>` for the machines listed under `hosts` in `flake.nix`, and
plain `<user>` (the server layer) for every other machine. `hms`,
home-manager and the bootstrap script all try the first, then the second.

Where a change goes:

| To... | Edit |
| --- | --- |
| add a CLI tool, everywhere | `home/default.nix`, or its topic file (`git.nix`...) |
| add something for every desk | `home/gui/default.nix` |
| add something for the Ubuntu desks | `home/gui/ubuntu/default.nix` |
| tweak one machine | its file, e.g. `home/gui/ubuntu/luna.nix` |
| add a machine | a file with `imports = [ ./. ];` in its layer's folder, plus an entry in `hosts` |
| add a user | `users` in `flake.nix` |

GUI apps on Ubuntu stay with apt/snap (google-chrome, thunderbird, code;
slack, obsidian) and kitty with its own installer: Nix-built GUI apps can't
use Ubuntu's graphics drivers. Fixing that (`targets.genericLinux.gpu`) needs
sudo and pinning the exact NVIDIA driver, which isn't an option on
work-managed machines. On the Mac, GUI apps will be Homebrew casks in
`darwin/mac.nix`.

## Day to day

```sh
hms                                        # apply changes: build, show the diff, activate
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too
```

Old generations and unused store paths are cleaned up weekly
(`nh clean user --keep 5 --keep-since 7d`).

## Logins

Per machine, never in Nix. The bootstrap script offers gh and atuin; these
are left. Each works over SSH: it shows a URL or code to open on whatever
machine you're at.

| What | Command | Notes |
| --- | --- | --- |
| Claude | `claude`, then log in | First run asks for a theme: pick Light (the declared one). No browser: press `c` to copy the URL, open it, paste the code back. |
| codex | `codex login --device-auth` | Device code, like gh. |
| Copilot | `:LspCopilotSignIn` in nvim | Copies a device code to the clipboard, for <https://github.com/login/device>. Until then nvim warns "not signed into GitHub". |

Servers hold no SSH key: the agent is forwarded to short hostnames
(`home/ssh.nix`), so git there uses your desk's key. Connect with plain `ssh`
from a machine whose agent has one.

## Gotchas

- **New session variables need a re-login.** Your desktop session loads
  `home.sessionVariables` once at login, and every terminal inherits a flag
  that stops them reloading. New aliases and functions only need a new shell
  (`exec fish`). On servers, session variables only reach login shells.
- **mosh** has no scrollback, so the mouse wheel sends Up (opening atuin).
  Run zellij inside it: `mosh host -- zellij attach -c main`. Over ssh, add
  `-t` (`ssh -t host zellij attach -c main`): without a terminal, zellij
  crashes, and the half-started session has no `TERM`; delete it with
  `zellij delete-session main --force`.
- **atuin:** only ever use the pinned one; a newer atuin (brew's) once built
  a history index the pinned one couldn't open. Keep the `atuin key` in the
  password manager.
- **Servers' weekly cleanup** is a systemd user timer, so it only runs while
  you're logged in (it catches up at the next login) unless
  `loginctl enable-linger` is set.
- **Neovim:** `~/.config/nvim` is a live link to `~/nix/home/nvim` (edits
  apply without a switch; vim.pack writes its lockfile there), so the repo
  must live at `~/nix`.
