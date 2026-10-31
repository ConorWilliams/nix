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
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      users = [ "conor" "conix" ];

      roles = {
        desk   = [ ./home/common.nix ./home/desk.nix ];
        server = [ ./home/common.nix ];
      };

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
      # Every user × role combination, named "<user>@<role>":
      #   conor@desk, conor@server, conix@desk, conix@server
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
    };
}
