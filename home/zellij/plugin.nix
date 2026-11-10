{
  lib,
  pkgs,
  zellij,
}:

# The Zellij plugins (this folder's Cargo workspace) built for WASI:
# bin/<crate>.wasm for each.
let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
  locked = (fromTOML (builtins.readFile ./Cargo.lock)).package;
  tile = (lib.findFirst (p: p.name == "zellij-tile") null locked).version;
in
# The plugin API changes between Zellij versions: a mismatch would build,
# then fail in a running session.
assert lib.assertMsg (tile == zellij.version) ''
  The Zellij plugins use zellij-tile ${tile}, but Zellij is ${zellij.version}:
  bump zellij-tile in home/zellij/Cargo.toml and update its Cargo.lock.
'';
wasm.rustPlatform.buildRustPackage {
  pname = "zellij-plugins";
  version = (fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugins; behavior is checked in a real Zellij session.
}
