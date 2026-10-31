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
2. Trust the Numtide binary cache, so codex is downloaded rather than
   compiled (~20 min). Once per machine, needs sudo:

   ```sh
   printf '%s\n' \
     'extra-substituters = https://cache.numtide.com' \
     'extra-trusted-public-keys = niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=' \
     | sudo tee -a /etc/nix/nix.conf
   sudo systemctl restart nix-daemon
   ```

3. Clone this repo and activate:

   ```sh
   nix run home-manager -- switch --flake .#conix@desk
   ```

## Day to day

```sh
home-manager switch --flake .#conix@desk   # apply changes
nix flake update                           # bump all pinned inputs
nix flake update llm-agents                # bump just claude/codex
nix fmt                                    # format all .nix files
```
