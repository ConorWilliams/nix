# nix

My terminal environment, managed with Nix + Home Manager.

## Quick start

1. Install upstream `nix`: <https://nixos.org/download/>. On the Mac,
   nix-darwin manages Nix and its daemon after the first switch.

2. Run the (idempotent) bootstrap script:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ConorWilliams/nix/main/bootstrap.sh | bash
   ```

3. Open a new terminal!

## Layout

```sh
├── flake.nix                # users, hosts -> layer
├── bootstrap.sh
├── home
│   ├── default.nix          # server layer: every machine; all CLI tools
│   ├── shell.nix            #   fish (bash/zsh hand over to it), prompt, history
│   ├── git.nix              #   git, delta, lazygit, git clone-wt
│   ├── zellij.nix, zellij/  #   zellij and its keys
│   ├── neovim.nix, nvim/    #   nvim: packages from Nix, config in Lua
│   ├── claude.nix, claude/  #   Claude Code and its status line
│   └── gui
│       ├── default.nix      # GUI layer: desks on any OS
│       ├── keys.nix         #   window manager keys, shared by i3 and AeroSpace
│       ├── icons.nix        #   the bars' icons, shared by i3status and SketchyBar
│       ├── ubuntu
│       │   ├── default.nix  # Ubuntu layer
│       │   ├── hubble.nix
│       │   └── luna.nix
│       └── mac
│           ├── default.nix  # Mac layer
│           ├── bar.nix      #   SketchyBar, at the bottom like i3's
│           └── polaris.nix
└── darwin                   # the Macs' system settings (nix-darwin)
    ├── default.nix          # every Mac: Nix, Homebrew, kitty, preferences
    └── polaris.nix          # this Mac: its account, name, keyboard and apps
```

Each layer imports the one above it, so a machine only names its last layer.

On Ubuntu, GUI apps that need the graphics drivers (browsers, Slack...) stay
with apt/snap, as Nix-built ones can't use Ubuntu's drivers; kitty comes from
its own installer, and i3, rofi and dunst from Nix. On the Mac, GUI apps
(kitty included) are Homebrew casks in `darwin/`; the first nix-darwin
switch may ask for `/etc/zshrc` and `/etc/bashrc` to be renamed to
`*.before-nix-darwin`.

### macOS

The configuration names this account and host explicitly:
`main@polaris` for Home Manager, and `polaris` for nix-darwin
(`darwin/polaris.nix`). nix-darwin keeps the Mac's name set to it, but the first time
(or after renaming it) set it yourself, since the bootstrap, `dms`
and `hms` find their config by the current name:

```sh
sudo scutil --set ComputerName polaris
sudo scutil --set LocalHostName polaris
sudo scutil --set HostName polaris
```

Then, from a fresh terminal in an existing checkout, run:

```sh
./bootstrap.sh
```

The script builds Home Manager before system activation, then builds/applies
nix-darwin using sudo and applies Home Manager. Conflicting dotfiles
are backed up with unique `before-home-manager-*` suffixes. Use `/bin/zsh` as the
account's login shell; Home Manager hands interactive sessions over to Fish.

GUI apps are declared in `darwin/default.nix` (every Mac's) and
`darwin/polaris.nix` (this one's). System switches uninstall undeclared
Homebrew packages while preserving app data. Homebrew updates and upgrades are
explicit; Photoshop and Bridge are managed through Creative Cloud. AeroSpace
comes from Nix, set up in `home/gui/mac/default.nix` (Home Manager starts it
at login and reloads it on `hms`), its keys from `home/gui/keys.nix`, shared
with i3 (Cmd as the leader where i3 uses Alt). After an AeroSpace update,
macOS may ask again to allow it under Privacy & Security, Accessibility.

## Day to day

```sh
hms                                        # apply home changes
dms                                        # on Mac: system settings, then home
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump only claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too
```

nvim's plugins come from nixpkgs (two from flake inputs), so
`nix flake update` updates them too. Copilot needs `:LspCopilotSignIn` once
per machine.
In zellij, Ctrl+arrows move between panes and nvim splits; the first press
asks to allow the navigator plugin (answer `y`).

For worktrees, `git clone-wt <url>` clones a repo as `<name>/.bare` plus a
`<name>/<default branch>` checkout. lazygit (Worktrees tab: `2`, then `]`)
then creates new ones as `<name>/<branch>`, and nvim follows when lazygit
switches to one. Start lazygit inside a checkout, not in `<name>/` itself.

## SSH

### Straight into zellij

With SSH:

```sh
zzh host         # new zellij session
zzh host main    # join "main" on host, creating it if needed
```

Or with mosh:

```sh
zosh host main
```

Full commands:

```sh
ssh -t host zellij attach -c main
```

```sh
mosh host -- zellij attach -c main
```

### Credentials

git authenticates to GitHub through gh, over HTTPS: no SSH keys on GitHub's
side and nothing forwarded to servers. Desks log gh in with the browser;
each server gets its own [fine-grained token][pat], limited to the repos it
needs, with Contents read/write and an expiry. The bootstrap script asks
for it; to renew one, run:

```sh
gh auth login --with-token
```

[pat]: https://github.com/settings/personal-access-tokens
