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

```sh
zzh brahe         # new zellij session on brahe, over ssh
zzh brahe main    # join "main" on brahe, creating it if needed
zosh brahe main   # the same over mosh
```

Full commands:

```sh
ssh -t brahe zellij attach -c main
```

```sh
mosh brahe -- zellij attach -c main
```

### Credentials

Servers hold no keys of their own. Desks run an SSH agent that loads your
key the first time ssh uses it, and `home/ssh.nix` forwards that agent to
every dotless host, so git on a server signs with your desk's key
(`ssh-add -l` on the server lists it). Only over ssh, and only while you're
connected; anyone with root on the server can use it in that time.

A zellij session keeps the agent of the connection that first started it,
so after you disconnect and reattach, git inside it can't reach your agent
(new panes included). Use a shell outside zellij for that, or start a new
session.
