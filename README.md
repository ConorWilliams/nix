# nix

My terminal environment, managed with Nix + Home Manager.

## Quick start

1. Install `nix`: <https://nixos.org/download/> on Linux; on the Mac,
   [Determinate's installer](https://determinate.systems/nix-installer/).

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
│   └── gui
│       ├── default.nix      # GUI layer: desks on any OS
│       ├── ubuntu
│       │   ├── default.nix  # Ubuntu layer
│       │   ├── hubble.nix
│       │   └── luna.nix
│       └── mac
│           └── default.nix  # Mac layer
└── darwin
    └── mac.nix              # Mac system settings: not a layer
```

Each layer imports the one above it, so a machine only names its last layer.

On Ubuntu, GUI apps that need the graphics drivers (browsers, Slack...) stay
with apt/snap, as Nix-built ones can't use Ubuntu's drivers; kitty comes from
its own installer, and i3, rofi and dunst from Nix. On the Mac, GUI apps
(kitty included) are Homebrew casks in `darwin/mac.nix`; the first nix-darwin
switch may ask for `/etc/zshrc` and `/etc/bashrc` to be renamed to
`*.before-nix-darwin`.

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
