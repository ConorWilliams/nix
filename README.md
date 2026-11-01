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
for it; to renew one, run `gh auth login --with-token` and paste the new
token. Since nothing is forwarded, git and gh keep working in zellij after
you disconnect, under mosh too.

A fine-grained token covers one owner (MyrtleSoftware or ConorWilliams),
and pushing `.github/workflows/` needs its Workflows permission.

[pat]: https://github.com/settings/personal-access-tokens
