{
  description = "Conor's terminal environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Use our nixpkgs rather than home-manager's own copy,
      # so there is exactly one package set.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      # Same as above.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, ... }:
    let
      users = [ "conor" "conix" ];

      roles = {
        desk   = [ ./home/common.nix ./home/desk.nix ./home/i3.nix ];
        server = [ ./home/common.nix ];
      };

      # Linux only; the Mac's system is set in darwin/mac.nix.
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Build one Home Manager config for a given user and role.
      mkHome = user: modules: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = modules ++ [{
          home.username = user;
          home.homeDirectory = "/home/${user}";
        }];
      };
    in
    {
      # Linux: every user × role combination, named "<user>@<role>"
      # Activate one with:
      #   home-manager switch --flake .#conix@desk
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.concatMap (user:
          nixpkgs.lib.mapAttrsToList (role: modules: {
            name = "${user}@${role}";
            value = mkHome user modules;
          }) roles
        ) users
      );

      # macOS: system settings + the same home modules, in one config.
      # Activate with:
      #   darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [
          home-manager.darwinModules.home-manager
          ./darwin/mac.nix
        ];
      };
    };
}
