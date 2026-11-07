{ pkgs, zellijVersion }:

let
  wasm = pkgs.pkgsCross.wasm32-wasip1;
  manifest = builtins.fromTOML (builtins.readFile ./key-hints/Cargo.toml);
  tileVersion = pkgs.lib.removePrefix "=" manifest.dependencies.zellij-tile;
in
assert pkgs.lib.assertMsg (zellijVersion == tileVersion) ''
  Zellij ${zellijVersion} does not match zellij-tile ${tileVersion}.
  Update home/zellij/key-hints/Cargo.toml and Cargo.lock to match the Zellij package.
'';
wasm.rustPlatform.buildRustPackage {
  pname = "zellij-key-hints";
  version = manifest.package.version;
  src = ./key-hints;
  cargoLock.lockFile = ./key-hints/Cargo.lock;
  nativeBuildInputs = [ wasm.lld ];
  env.RUSTFLAGS = "-C linker=wasm-ld";
  doCheck = false; # WASI plugin; behavior is checked in a real Zellij session.
}
