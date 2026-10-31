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

    # AI coding CLIs (claude, codex), updated daily by a bot.
    # No `follows` on purpose: this flake is only tested against its own
    # nixpkgs pin, so we keep the combination it ships.
    llm-agents.url = "github:numtide/llm-agents.nix";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      # Every system we build for.
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      users = [
        "conor"
        "conix"
      ];

      # What each kind of machine gets, and what it runs on.
      roles = {
        desk = {
          system = "x86_64-linux";
          modules = [
            ./home/common.nix
            ./home/desk.nix
            ./home/desk-linux.nix
          ];
        };
        server = {
          system = "x86_64-linux";
          modules = [ ./home/common.nix ];
        };
        mac = {
          system = "aarch64-darwin";
          modules = [
            ./home/common.nix
            ./home/desk.nix
            ./home/desk-mac.nix
          ];
        };
      };

      # Build one Home Manager config for a given user and role.
      mkHome =
        user: role:
        let
          pkgs = nixpkgs.legacyPackages.${role.system};
          homeRoot = if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          # Makes `inputs` available to every module, e.g. home/claude.nix.
          extraSpecialArgs = { inherit inputs; };
          modules = role.modules ++ [
            {
              home.username = user;
              home.homeDirectory = "${homeRoot}/${user}";
            }
          ];
        };
    in
    {
      # Your home directory, on every machine. Every user × role, named
      # "<user>@<role>". Activate one with:
      #   home-manager switch --flake .#conix@desk
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.concatMap (
          user:
          nixpkgs.lib.mapAttrsToList (name: role: {
            name = "${user}@${name}";
            value = mkHome user role;
          }) roles
        ) users
      );

      # `nix fmt` formats every .nix file in the repo with nixfmt.
      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # Lets `nix flake check` test every home config (by default it doesn't).
      # Each config is checked under the system it runs on.
      checks = nixpkgs.lib.genAttrs systems (
        system:
        nixpkgs.lib.mapAttrs (_: c: c.activationPackage) (
          nixpkgs.lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system) self.homeConfigurations
        )
      );

      # The Mac's system settings only (Homebrew casks, macOS defaults).
      # Rarely changed. Activate with:
      #   sudo darwin-rebuild switch --flake .#mac
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [ ./darwin/mac.nix ];
      };
    };
}
