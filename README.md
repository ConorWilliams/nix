# nix

My terminal environment, managed with Nix + Home Manager.

## Quick start

1. Install upstream `nix`: <https://nixos.org/download/>.

2. Run the (idempotent) bootstrap script:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ConorWilliams/nix/main/bootstrap.sh | bash
   ```

3. Open a new terminal!

## Layout

```fish
├── flake.nix                # users, hosts -> layer
├── bootstrap.sh
├── home
│   ├── default.nix          # cli: every machine
│   └── gui
│       ├── default.nix      # GUI layer: desks on any OS
│       ├── ubuntu
│       │   ├── default.nix  # Ubuntu layer
│       │   └── <host>.nix
│       └── mac
│           ├── default.nix  # Mac layer
│           └── <host>.nix
└── darwin
    ├── default.nix          # Macs' system settings
    └── <host>.nix
```

Each layer imports the one above it, so a machine only names its last layer.

On Ubuntu, GUI apps that need the graphics drivers stay with apt/snap, as
Nix-built ones can't use Ubuntu's drivers; kitty comes from its own installer.
On the Mac, GUI apps are Homebrew casks in `darwin/`.

## Day to day

```sh
hms                                        # apply home changes
dms                                        # on Mac: system settings, then home
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump only claude
nix fmt                                    # format
nix flake check --all-systems --no-build   # check every config
```

## Credentials

`git` authenticates to GitHub through `gh`, over HTTPS Desks log `gh` in with
the browser; each server gets its own [fine-grained token][pat], limited to
the repos it needs, to renew one, run:

```sh
gh auth login --with-token
```

[pat]: https://github.com/settings/personal-access-tokens
