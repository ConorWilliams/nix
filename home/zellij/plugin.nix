{ pkgs }:

# A Zellij plugin crate (Cargo.toml + Cargo.lock) built for WASI.
src:
let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
  manifest = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
in
wasm.rustPlatform.buildRustPackage {
  pname = manifest.package.name;
  version = manifest.package.version;
  inherit src;
  cargoLock.lockFile = src + "/Cargo.lock";
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugin; behavior is checked in a real Zellij session.
}
