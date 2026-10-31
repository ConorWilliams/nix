# nix

My terminal environment, managed with Nix + Home Manager.

## Layout

```
flake.nix            users, roles, mkHome
home/common.nix      every machine (+ git.nix, ai.nix)
home/desk.nix        machines you sit at, any OS
home/desk-linux.nix  Linux desks
home/desk-mac.nix    the Mac
darwin/mac.nix       Mac system settings only
```

Configs are named `<user>@<role>`: users `conor`/`conix`, roles
`desk`/`server`/`mac`.

## Set up a new machine

1. Install Nix (Determinate installer).
2. Clone this repo to `~/nix` and activate:

   ```sh
   nix run home-manager -- switch --flake ~/nix#conix@desk
   ```

The Mac also has system settings, applied separately:

```sh
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix#mac  # first time
sudo darwin-rebuild switch --flake ~/nix#mac                                # after that
```

## Day to day

```sh
home-manager switch --flake .#conix@desk   # apply changes
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude
nix fmt                                    # format all .nix files
nix flake check --all-systems --no-build   # check every config, Mac too (~7s)
```

## Notes for later steps

- **Moving `conor` over:** delete `~/.gitconfig` first. Git reads it after
  Home Manager's `~/.config/git/config`, so it silently wins. Expect the
  first switch to hit existing `.bashrc`/`.profile`/`config.fish`; use
  `home-manager switch -b backup`.
- **Shells:** keep bash as the login shell and start fish from bash for
  interactive sessions, so `ssh host cmd`, scp and mosh stay plain bash.
  Stop running `brew shellenv`, or linuxbrew shadows Nix tools.
- **Linux GUI apps:** consider `targets.genericLinux` (launcher entries,
  terminfo). Its GPU part needs sudo and a driver-version pin on NVIDIA,
  so prefer apt for GL-heavy apps like kitty (`package = null`).
- **Servers:** add `nix.gc` (a systemd user timer, so needs
  `loginctl enable-linger`). `home.sessionVariables` only reach login
  shells.
- **Neovim:** live-editing the config via `mkOutOfStoreSymlink` relies on
  the repo always living at `~/nix`.
