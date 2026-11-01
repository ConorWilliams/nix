# nix

My terminal environment, managed with Nix + Home Manager.

## Quick start

1. Install `nix`: <https://nixos.org/download/>

2. Run the (idempotent) bootstrap script:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/ConorWilliams/nix/main/bootstrap.sh | bash
   ```

3. Open a new terminal, then do the [logins](#logins) it doesn't.

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

GUI apps on Ubuntu stay with apt/snap, nix-built GUI apps can't use Ubuntu's
graphics drivers. On the Mac, GUI apps are Homebrew casks in `darwin/mac.nix`.

## Day to day

```sh
hms                                        # apply home changes
dms                                        # on Mac: system settings, then home
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too
```

## SSH
