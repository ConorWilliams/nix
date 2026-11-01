# Review — 2026-11-01

Compiled from six read-only reviews: four Opus agents (**N** Nix/Home Manager,
**V** Neovim, **S** shell/git/terminal/bootstrap, **X** cross-cutting) and two
Sonnet agents reading the Rosé Pine ports' READMEs (**R**). Duplicates are
merged; tags show who raised each item. Items marked ✔ I re-checked myself.
Tick what you want done and I'll work through it.

## Needs your decision first

- [ ] **zellij Ctrl-h/j/k/l (home/zellij.nix)** — S read zellij 0.45.1's
  source: only the *first* top-level `keybinds` block is read, and ours is
  the second (✔ the generated config has two). If so, Ctrl-hjkl from a
  *shell* pane never moves panes; nvim → zellij still works (smart-splits
  calls `zellij action` itself), which may be what you tested. Test: in a
  shell pane, press Ctrl-l towards a neighbour. Fix: move the four binds into
  the preset file's `shared_among "normal" "locked"` block. (S)
- [ ] **bash → fish hand-off (home/shell.nix:21-25)** — N: interactive bash
  started by `nix-shell`/`nix develop` execs into fish and loses the dev
  environment; S disagrees for those (they replace their own process) but
  confirmed `bash -ic 'cmd'` loses the command (breaks e.g. VS Code remote
  env probes). Agreed fix: also skip when `$BASH_EXECUTION_STRING` (and
  `$IN_NIX_SHELL`) is set; exec `fish --login` for login shells. (N, S, X)
- [ ] **`hms`/`dms` without the path (home/default.nix:71, gui/mac)** — N and
  S suggest `nh home switch` alone, since `NH_FLAKE` is set. We added the path
  deliberately: session variables only reach terminals after a re-login.
  Keep as is unless you'd rather rely on `NH_FLAKE`. (N, S)
- [ ] **atuin threads on work servers (home/shell.nix:120-123)** —
  `capture_tools` syncs Claude/Codex tool input/output (file contents,
  command output from work repos) to api.atuin.sh, end-to-end encrypted, and
  every server holding the key can read it all. Check work policy; options:
  `capture_tools = false`, or threads off in the server layer. (S, X)
- [ ] **Claude permissions on servers (home/claude.nix:33-34)** — auto mode
  applies on shared work servers too; consider stricter settings there. (X)

## Must fix

- [ ] ✔ **bootstrap.sh:27-32** — the "turn on flakes" check runs through the
  `nix()` wrapper, which already passes the flakes flag, so it always reports
  flakes as on and never writes `nix.conf`. On a fresh machine, later
  `nix flake …`/`nix fmt` fail. Fix: check with `command nix config show`;
  and write `extra-experimental-features` (not `experimental-features`,
  which replaces existing ones). (X, S)
- [ ] ✔ **home/nvim/plugin/60_lsp.lua:47-50, 85_start.lua:36-45** — the
  diagnostic signs and dashboard icons are plain spaces (the nerd-font glyphs
  were lost), so errors/warnings show nothing in the gutter. Fix: drop the
  `signs.text` table (built-in E/W/I/H) or write glyphs with
  `vim.fn.nr2char(0x...)`; fix or drop the dashboard `icon`s. (V)
- [ ] **home/nvim/plugin/61_format.lua:39-40** — the global conform
  `formatexpr` breaks `gq` wherever no formatter applies (tested: `gqq` does
  nothing in .txt and .md), so reflowing prose/commit messages is broken.
  Fix: delete the line. (V)
- [ ] ✔ **home/nvim/plugin/70_markdown.lua:27-28** — only `checkbox` is
  disabled; list dashes still render as `●`. The `bullet = { enabled = false }`
  line isn't in the file or history (likely lost in a history rewrite). Fix:
  add it back. (V)
- [ ] **home/git.nix:39,70** — `colorMoved = "default"` is zebra mode:
  adjacent moved blocks alternate to bold blue / bold yellow, which
  `map-styles` doesn't map, so they show as raw coloured text. Fix: add
  `bold blue => syntax #efe0ff, bold yellow => syntax #dff0ff`, or use
  `colorMoved = "blocks"`. (N, S)

## Should fix

### Neovim

- [ ] **plugin/60_lsp.lua:20-37** — LSP keymaps attach for copilot, which
  attaches to every buffer (incl. help, .txt), so `gd`/`gr` become empty
  pickers there. Fix: skip `client.name == 'copilot'` in the LspAttach
  callback (or check `supports_method`). (V)
- [ ] **plugin/80_ai.lua** — copilot is sent every opened file: `.env`,
  secrets, `~/.ssh`. Fix: a `root_dir` that skips such paths and help buffers.
  Also its `executable()` guard always passes (installed on every host incl.
  servers) — see "copilot to the GUI layer" below. (V, X)
- [ ] **plugin/40_treesitter.lua:14-15** — `vim.wo.foldmethod =` also sets the
  window's global value, so the next file in that window inherits treesitter
  folds; and it targets the current window, not `ev.buf`'s. Fix:
  `vim.wo[0][0].foldmethod` / `foldexpr`. (V)
- [ ] **plugin/20_keymaps.lua:67-69** — `vim.diagnostic.jump{ float = true }`
  is deprecated in 0.12 (shows in `:checkhealth vim.deprecated`). Fix: use
  `vim.diagnostic.config{ jump = { on_jump = … open_float … } }` and drop
  `float`. (V)
- [ ] **plugin/30_ui.lua:14-15** — with `cmdheight=0`, ui2 never shows
  "recording @q". Fix: add `reg_recording()` to the statusline + redraw on
  `RecordingEnter/Leave`. (V)
- [ ] **plugin/15_autocmds.lua:24** — `man` and `checkhealth` already map `q`
  (better: man also closes its loclist, checkhealth handles last-window); ours
  overrides them with `close` (E444 as last window). Fix: pattern
  `{ 'help', 'qf', 'gitsigns-blame' }`. (V)
- [ ] **plugin/60_lsp.lua:34** — insert `<C-k>` duplicates blink's super-tab
  `<C-k>` (signature); which wins depends on attach order. Fix: delete. (V)
- [ ] **plugin/10_options.lua:23,27,32** — `scrolloff`, `splitkeep`,
  `smoothscroll` are overridden by go-up at setup; dead lines. Fix: delete
  (30_ui.lua already explains). (V)
- [ ] **home/nvim/plugin/65_completion.lua:6** — blink downloads a native
  `.so` from GitHub on each machine's first start (unpinned by Nix, fails
  without GitHub access). Fix: nixpkgs `vimPlugins.blink-cmp` (same 1.10.2)
  in `programs.neovim.plugins`, drop it from vim.pack. (X)

### Nix / Home Manager

- [ ] **Copilot and codex to the GUI layer (home/neovim.nix:30, default.nix:56)**
  — the server config is 3.8 GiB; copilot-language-server (767 M) and codex
  (610 M) are the biggest pieces, and copilot then warns "not signed in" on
  every server. Also consider `llm.codex` (daily, like claude) instead of
  nixpkgs' codex. (X, V, N)
- [ ] **glibc locales (X)** — 223 M of all locales in every closure; set
  `i18n.glibcLocales` to just en_GB/en_US.
- [ ] **home/default.nix:61-66 fuc override** — not in the binary cache, so
  every machine (servers, Mac) compiles Rust after each nixpkgs bump. Drop the
  progress features or accept the compile. (X, N)
- [ ] **home/default.nix:88-91 programs.ssh** — writes an empty, read-only
  `~/.ssh/config`, blocking hand-written hosts (whose IPs can't live in this
  public repo). Fix: drop it, or `includes = [ "config.local" ]`; optional
  extras: `ServerAliveInterval`, `ControlMaster` for faster repeated ssh.
  (N, S, X)
- [ ] **~/.local/bin not on PATH** — Home Manager replaced Ubuntu's
  `~/.profile`, so `uv tool install` binaries aren't found. Fix:
  `home.sessionPath = [ "$HOME/.local/bin" ];`. (S)
- [ ] **home/gui/ubuntu/default.nix:36,50** — `i3lock -d` (DPMS) was removed
  from i3lock 2.13 and does nothing; Alt+n locks black but suspend locks
  white. Fix: `i3lock -c 000000` in both. (N)
- [ ] ✔ **home/neovim.nix:83** — comment lost its first line ("Live symlink
  into the repo (not a store copy): edits apply without a switch, and
  vim.pack can"). (V, N)
- [ ] **home/zellij.nix comments** — "in every mode" (binds are normal+locked
  only); "see the comment at the top of the file" (it's in the .kdl); and "a
  plugins block replaces zellij's defaults" is wrong for 0.45.1 (it merges) —
  so keep only the `compact-bar` entry and drop the other ~12 lines. (N, S)
- [ ] **flake.nix checks** — add
  `checks.aarch64-darwin.darwin-mac = self.darwinConfigurations.mac.system;`
  so `nix flake check` covers nix-darwin (README says "Mac too"). (X, N)

### Bootstrap / servers

- [ ] **bootstrap.sh:39,105** — `git pull --ff-only` (diverged local repo)
  and a failed `gh auth login` (bad token) abort the whole run under `set -e`,
  skipping Home Manager / atuin. Make both non-fatal with a message. (S)
- [ ] **Server rollout: existing dotfiles** — `-b backup` moves a server's
  `.bashrc` (CUDA/conda/module setup), `.profile`, `.ssh/config` aside for
  read-only links. Fix: source `~/.bashrc.local` if present (bashrcExtra),
  `programs.ssh.includes = [ "config.local" ]`, and print what was moved. (X)
- [ ] **home/shell.nix:15-19** — `bashrcExtra` only handles multi-user Nix;
  add the single-user `~/.nix-profile/etc/profile.d/nix.sh` branch for
  servers without sudo. (S)
- [ ] **CI** — no `.github/`: nothing stops a broken eval or a secret reaching
  `main`, which `curl | bash` installs. Add an Action: `nix flake check
  --all-systems --no-build`, darwin eval, `shellcheck bootstrap.sh`,
  gitleaks. (X)
- [ ] **README** — "GUI apps on Ubuntu stay with apt/snap" is out of date
  (kitty: own installer; i3/rofi/dunst: Nix); add the nvim maintenance bits
  (`:lua vim.pack.update()`, commit the lockfile, update only on desks,
  `:LspCopilotSignIn`). (S, X)

### Mac (before first setup)

- [ ] **Login shell is zsh** — nothing here loads on macOS (the fish hand-off
  lives in `.bashrc`; HM doesn't manage zsh; /bin/bash 3.2 also dislikes HM's
  `shopt globstar`). Fix: kitty `shell = fish --login` in the Mac layer, or
  nix-darwin `programs.fish.enable` + user shell. (X, N, S)
- [ ] **Names** — `primaryUser = "conor"` vs `users = [ "conix" ]`, plus both
  `mac` hostname TODOs; bootstrap/dms/nh key on them. Settle together. (X, S)
- [ ] **bootstrap.sh:47-53** — the plain-`<user>` fallback is x86_64-linux;
  on a Mac without its hostname entry it fails confusingly. Fall back only on
  `Linux x86_64`, else say "add this host to flake.nix". (X)
- [ ] **eza theme path** — on macOS eza reads `~/Library/Application
  Support/eza`; set `EZA_CONFIG_DIR = "${config.xdg.configHome}/eza"`. (X, R)
- [ ] **kitty install / Homebrew** — nothing installs kitty or Homebrew on
  the Mac; and README (nixos.org installer) vs `nix.enable = false`
  (Determinate) disagree. nix-darwin may also want `/etc/zshrc`,
  `/etc/bashrc` renamed on first switch. (X)

## Rosé Pine ports (README audit)

- [ ] **yazi (home/default.nix:139-142)** — only the port's *icon* colours
  are loaded; the real theme is the flavor `flavors/rose-pine-dawn.yazi`
  (UI colours + code-preview tmTheme). Fix: `programs.yazi.flavors.rose-pine-dawn
  = "${inputs.rose-pine-yazi}/flavors/rose-pine-dawn.yazi"` and
  `theme.flavor = { light = …; dark = …; }` (both, since detection fails over
  mosh/zellij), keeping the icon file. (R, S)
- [ ] **eza vs vivid** — `LS_COLORS` (vivid) takes precedence over eza's
  `theme.yml` (eza README), so dirs/executables use vivid's Dawn colours, not
  the eza port's. Accept (both Dawn) or run eza with `LS_COLORS` unset in the
  aliases. (R)
- [ ] **nvim rose-pine (plugin/30_ui.lua:7-8)** — call
  `require('rose-pine').setup({ variant = 'dawn' })` before `colorscheme`, so
  Dawn doesn't depend on background detection (fails over mosh/zellij). (R)
- [ ] **kitty** — kitty-themes' Dawn matches the official port except
  `active_border_color #286983` / `inactive_border_color #dfdad9` (kitty's
  own splits). Add the two settings if you use kitty splits. (R)
- [ ] **fzf** — parsing the port's `export FZF_DEFAULT_OPTS="…"` is correct
  but would silently yield nothing if upstream reformats; add an `assert`. (R)
- [ ] **i3 and rofi** — official ports exist (`rose-pine/i3`,
  `rose-pine/rofi`); both are stock today. dunst has no port (hand-colour if
  wanted). For `programs.rofi.theme` pass a path value, not a string. (R, N, S)
- [ ] **lazygit** — wiring matches the README's preset method; its delta
  snippet is just for their screenshots (`mellow-barbet` feature + rose-pine
  syntax theme) — skip, it conflicts with stock delta. Optional:
  `--syntax-theme=rose-pine-dawn` in the diffRenderer for code colours. (R)

## Consider

- [ ] **init.lua** — `vim.loader.enable()` (startup ~48 → ~39 ms). (V)
- [ ] **plugin/65_completion.lua:16,20** — `auto_brackets` and
  `sources.default` repeat blink's defaults; delete. (V)
- [ ] **plugin/80_ai.lua:29-33** — Right-arrow fallback as an `expr` map
  (`return '<Right>'`), as the docs show; drops `nvim_feedkeys`. (V)
- [ ] **plugin/85_start.lua:43** — the "s" item checks only the branch
  session; `load()` also falls back to the folder session. Check both. (V)
- [ ] **after/lsp/lua_ls.lua** — `diagnostics.globals = { 'Snacks' }` to stop
  undefined-global warnings in this config. (V)
- [ ] **plugin/70_markdown.lua:57** — Esc at the title prompt still creates an
  untitled note; return early on an empty title. (V)
- [ ] **plugin/20_keymaps.lua:23** — smart-splits' `warn_if_unusable = false`
  replaces the `$ZELLIJ` check. (V)
- [ ] **snacks `bigfile = {}`** — turns off treesitter/LSP/render-markdown for
  multi-MB files. Note: explorer "delete to trash" is permanent where no
  trash tool exists (servers). (V)
- [ ] **programs.eza** — HM module (`icons`, `git`) could replace the package
  and the three aliases (keep `theme.yml` as a file). (N)
- [ ] **programs.htop** — writes no config, so it's just a package; move to
  `home.packages` or give it settings. (N)
- [ ] **atuin** — `auto_sync`, `sync_frequency`, `capture_tools` repeat the
  defaults; drop them. (S)
- [ ] **kitty terminfo** — also link it to `~/.terminfo` so `sudo <tui>` and
  processes without session vars find it. (S)
- [ ] **direnv + nix-your-shell** — `programs.direnv` (with nix-direnv) and
  `programs.nix-your-shell` keep project dev shells in fish. (S, N)
- [ ] **git** — `rebase.autoStash = true` (pull on a dirty tree);
  `rerere.enabled = true`. (S)
- [ ] **zellij Alt binds** — on desks i3 takes Alt+arrows/f/h/n/o/p/minus, so
  those preset binds never fire there; could drop them. (S)
- [ ] **targets.genericLinux.enable** on Ubuntu desks (XDG_DATA_DIRS for
  rofi drun, distro terminfo). (X)
- [ ] **Supply chain** — 2FA + branch protection on GitHub; a "clone, read,
  run" alternative to `curl | bash` for servers; pin kitty's installer
  version. (X)
- [ ] **nh clean on shared servers** — runs a store-wide GC (others' unrooted
  paths too); fine, worth knowing. (X)
- [ ] **.gitattributes** — mark `home/nvim/nvim-pack-lock.json` as
  `linguist-generated`. (X)

## Checked and fine (highlights)

Git history and files hold no secrets, IPs or internal URLs (only your two
emails; colleague names only in the approved spell file). All flake inputs
locked; treesitter from Nix; flake check passes for every system with zero
HM warnings; darwin evaluates and all packages exist on aarch64-darwin.
bootstrap is shellcheck/shfmt clean and safe under `curl | bash`.
`sideloadInitLua`, providers, `historyWidget = ""`, lazygit `diffRenderers`
and its darwin path, zellij theme `readFile`, gh credential helper,
`bashrcExtra` before the interactive check, fish theme method, vivid theme,
atuin/zellij/bat/fish/starship port wiring, ui2 options, venv `cmd`, marksman
`root_dir` — all verified correct.

_One incident: S briefly stopped your real atuin daemon while testing and
restarted it straight away (healthy; no history affected)._
