{ pkgs }:

let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
  manifest = builtins.fromTOML (builtins.readFile ./key-hints/Cargo.toml);
in
wasm.rustPlatform.buildRustPackage {
  pname = "zellij-key-hints";
  version = manifest.package.version;
  src = ./key-hints;
  cargoLock.lockFile = ./key-hints/Cargo.lock;
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugin; behavior is checked in a real Zellij session.
}
