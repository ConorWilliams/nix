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
dms                                        # on Mac: system settings, home, then brew upgrade
```

Updating things (nh bumps the pinned inputs, builds, and lists each package
whose version changed; `hms` then applies it):

```sh
bump-preview [INPUT]                       # what a bump would change, unbuilt
nh home build -u                           # bump all pinned inputs
nh home build -U llm-agents                # bump only claude
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

## Zellij

A new terminal is a plain shell; Zellij starts when asked for:

```sh
zellij attach -c NAME                      # join or create a session
zzh HOST [NAME]                            # the same on another host
restart-zellij                             # save and end every session
```

Zellij starts locked, so keys go to the program in the pane. `Alt g` leads
into its modes (a menu shows the keys), and these work from anywhere:

| Keys           | Does                                  |
| -------------- | ------------------------------------- |
| `Alt f`        | find a session's tab (any words)      |
| `Alt h`/`l`    | previous / next tab                   |
| `Ctrl` arrows  | move between panes and Neovim splits  |

They shadow fish's `Alt h`, `Alt l` and `Alt f`, and `Ctrl Right` (in fish,
`Alt Right` still accepts a word of a suggestion).

Ended sessions can be brought back (`s n`, or `zellij attach NAME`), each pane
in its folder; Neovim, Claude and Codex wait for Enter, then resume. A switch
that changes plugin aliases or Zellij's options only reaches sessions started
after it: run `restart-zellij` (outside Zellij) to bring them all up to date.

## Credentials

`git` authenticates to GitHub through `gh`, over HTTPS. Desks log `gh` in with
the browser; each server gets its own [fine-grained token][pat], limited to
the repos it needs. To renew one, run:

```sh
gh auth login --with-token
```

[pat]: https://github.com/settings/personal-access-tokens
