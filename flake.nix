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

    # Claude Code, updated daily by a bot (home/claude.nix).
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

      # What each machine gets, and what it runs on. Every work server shares
      # one role. A machine-only tweak goes in a small home/<name>.nix added
      # to its list.
      roles = {
        hubble = {
          system = "x86_64-linux";
          modules = [
            ./home/common.nix
            ./home/desk.nix
            ./home/desk-linux.nix
            ./home/hubble.nix
          ];
        };
        luna = {
          system = "x86_64-linux";
          modules = [
            ./home/common.nix
            ./home/desk.nix
            ./home/desk-linux.nix
            ./home/luna.nix
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
        user: name: role:
        let
          pkgs = import nixpkgs {
            inherit (role) system;
            # Unfree packages we accept, by name (everything else stays refused).
            config.allowUnfreePredicate =
              pkg: builtins.elem (nixpkgs.lib.getName pkg) [ "copilot-language-server" ];
          };
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
              # Switch to this config. nh would guess <user>@<hostname>,
              # which is wrong on servers (role "server") and the Mac.
              home.shellAliases.hms = "nh home switch -c ${user}@${name}";
            }
          ];
        };
    in
    {
      # Your home directory, on every machine. Every user × role, named
      # "<user>@<role>". Activate one with:
      #   home-manager switch --flake .#conix@hubble
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.concatMap (
          user:
          nixpkgs.lib.mapAttrsToList (name: role: {
            name = "${user}@${name}";
            value = mkHome user name role;
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
