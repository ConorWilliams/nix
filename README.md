# nix

My environment, managed with Nix + Home Manager.

## Quick start

1. Install upstream `nix`: <https://nixos.org/download/>.

2. Run the (idempotent) bootstrap script:

   ```sh
   nix run github:ConorWilliams/nix
   ```

   On a fresh Nix install, you may need to enable flakes/commands:

   ```sh
   nix --extra-experimental-features 'nix-command flakes' run github:ConorWilliams/nix
   ```

3. Open a new terminal!

## Layout

```fish
├── flake.nix                # Users, hosts -> layer
├── home
│   ├── default.nix          # CLI: every machine
│   ├── <config>.nix         #   specialized configs
│   ├── <config>/            #   auxiliary files
│   └── gui
│       ├── default.nix      # GUI: any OS
│       ├── <config>.nix
│       ├── ubuntu
│       │   ├── default.nix  # Ubuntu
│       │   └── <host>.nix
│       └── mac
│           ├── default.nix  # Mac
│           └── <host>.nix
└── darwin
    ├── default.nix          # Macs' system settings
    └── <host>.nix
```

Each layer imports the one above it, so a host/machine only names its last layer.

## GUI applications

On Ubuntu, GUI apps that need the graphics drivers stay with apt/snap, as
Nix-built ones can't use Ubuntu's drivers; kitty comes from its own installer.
On the Mac, GUI apps are Homebrew casks in `darwin/`.

## Day to day

Activating configurations:

```sh
hms                                        # apply home changes
dms                                        # on Mac: system settings, then home
```

Updating things:

```sh
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump only claude
```

Manual garbage collection (runs on a schedule automatically):

```sh
nh clean all --keep 5 --keep-since 7d --ask
```

Dev work:

```sh
nix fmt                                    # format
nix flake check --all-systems --no-build   # check every config
.github/check.sh [check|lint|rust|nvim]    # everything CI checks
```

## Credentials

`git` authenticates to GitHub through `gh`, over HTTPS. Desks log `gh` in with
the browser; each server gets its own [fine-grained token][pat], limited to
the repos it needs. To renew one, run:

```sh
gh auth login --with-token
```

[pat]: https://github.com/settings/personal-access-tokens
