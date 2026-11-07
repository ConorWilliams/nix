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
```

## Zellij

A session contains tabs, and each tab contains terminal panes. The keys borrow
Neovim's mnemonics: `b` for tabs (buffers), `w` for panes (windows), `q` for sessions.

At an empty Fish prompt, press Space, wait for the bar to leave LOCKED mode,
then use the keys below. Alt+G enters the same native modes directly and works
while a program is running. Space in commands and Neovim keeps its usual behavior.

| Keys after leader     | Action                                                            |
| --------------------- | ----------------------------------------------------------------- |
| `b n`                 | Create a tab and enter native naming mode; Enter accepts          |
| `b r`                 | Rename this tab; Esc restores the previous name                   |
| `,` or `b f`          | Fuzzy-find tabs, panes, or sessions in the native manager         |
| `b b`                 | Last tab                                                          |
| `b h` / `b l`         | Previous / next tab; `b 1` … `b 9` jumps by position              |
| `b d`                 | Close this tab and its programs                                   |
| `q n`, then Ctrl+W    | Open the native new-session form; name it and follow its prompts  |
| `q r`, then Ctrl+R    | Rename the current session in the native manager                  |
| `q s`                 | Find and switch sessions                                          |
| `q d`                 | Detach from the current session                                   |
| `q q`                 | Quit the session, stopping its programs, whether named or unnamed |
| `-` / `\|`            | Split below / right                                               |
| `w w` / `w m` / `w f` | Last pane / maximize pane / floating panes                        |
| `w d`                 | Close this pane and its program                                   |
| `r`, then arrows      | Resize; Esc finishes                                              |
| `s`, then `j` / `k`   | Scroll; Ctrl+D / Ctrl+U scroll half a page; Esc finishes          |
| `s e`                 | Open scrollback in Neovim                                         |

Ctrl+arrows retain the existing Neovim/Zellij navigation. A small standalone Rust
plugin shows every binding for the current mode in a popup: press the leader to
see its commands, then `b`, `w`, or `q` to see that group's commands. Aliases with
the same action share a row, including the numbered tab keys. The popup closes
when you return to typing or enter a naming prompt. It does not take keyboard
focus or execute actions; Zellij handles every key.

The stock compact bar is unchanged. Our plugin reads the live keymap from
Zellij's released plugin API, with no second menu configuration or Zellij source
patch. Its Rust source and locked dependencies live in `home/zellij/key-hints/`.
On first launch, Zellij opens a selectable permission popup: press `y` to let it
read application state and show/hide its own pane. Permission acceptance does not
require clicking the status bar.

The session manager uses its built-in multi-screen view so fuzzy search includes
tabs and panes: type a name, select with arrows, Enter accepts, Esc closes it.
Names are optional; no shell code validates them.

The Space hand-off uses Zellij's CLI, so allow the mode change before typing the
next key. Use Alt+G for fast sequences. On macOS, Kitty and shells share a short
`ZELLIJ_SOCKET_DIR` so named sockets fit the platform's path limit. Older sessions
in another socket directory remain accessible from their existing windows.

Apply with `hms`, then open a fresh terminal. Start with one session per project,
tabs for tasks, and panes for programs you want visible together. Project layouts
can come later, once that workflow feels useful.

## Credentials

`git` authenticates to GitHub through `gh`, over HTTPS desks log `gh` in with
the browser; each server gets its own [fine-grained token][pat], limited to
the repos it needs, to renew one, run:

```sh
gh auth login --with-token
```

[pat]: https://github.com/settings/personal-access-tokens
