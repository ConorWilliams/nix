{ pkgs }:

# The Zellij plugins (this folder's Cargo workspace) built for WASI:
# bin/<crate>.wasm for each.
let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
in
wasm.rustPlatform.buildRustPackage {
  pname = "zellij-plugins";
  version = (fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.version;
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugins; behavior is checked in a real Zellij session.
}
