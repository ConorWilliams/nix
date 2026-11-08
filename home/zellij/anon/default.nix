{ pkgs }:

let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
  manifest = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
wasm.rustPlatform.buildRustPackage {
  pname = "zellij-anon";
  version = manifest.package.version;
  src = ./.;
  cargoLock.lockFile = ./Cargo.lock;
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugin; behavior is checked in a real Zellij session.
}
