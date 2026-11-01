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

      # Machines with a config of their own, by hostname, pointing at their
      # layer in home/ (each layer file imports the one above it):
      #   server -> gui -> ubuntu -> hubble, luna
      #                 -> mac
      hosts = {
        hubble = {
          system = "x86_64-linux";
          module = ./home/gui/ubuntu/hubble.nix;
        };
        luna = {
          system = "x86_64-linux";
          module = ./home/gui/ubuntu/luna.nix;
        };
        # TODO: rename to the Mac's real hostname once it's set up.
        mac = {
          system = "aarch64-darwin";
          module = ./home/gui/mac;
        };
      };

      # Every other machine (the work servers) gets the base layer, with no
      # need to list them: the config is named after the user alone, which
      # nh and home-manager fall back to when <user>@<hostname> isn't found.
      server = {
        system = "x86_64-linux";
        module = ./home;
      };

      # Build one Home Manager config for a user on a machine.
      mkHome =
        user: machine:
        let
          pkgs = import nixpkgs {
            inherit (machine) system;
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
          modules = [
            machine.module
            {
              home.username = user;
              home.homeDirectory = "${homeRoot}/${user}";
            }
          ];
        };
    in
    {
      # Your home directory, on every machine: "<user>@<hostname>" for the
      # hosts above, plain "<user>" for everything else (the servers). `hms`
      # (nh) picks the right one by itself; with home-manager directly:
      #   home-manager switch --flake ~/nix#conix@luna   (a desk)
      #   home-manager switch --flake ~/nix#conix        (a server)
      homeConfigurations = builtins.listToAttrs (
        nixpkgs.lib.concatMap (
          user:
          [
            {
              name = user;
              value = mkHome user server;
            }
          ]
          ++ nixpkgs.lib.mapAttrsToList (host: machine: {
            name = "${user}@${host}";
            value = mkHome user machine;
          }) hosts
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
