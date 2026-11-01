{
  description = "Conor's terminal environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      # Use this flake's nixpkgs rather than home-manager's own copy,
      # so there is exactly one package set.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      # Same as above.
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code, updated daily by a bot (home/claude.nix). No `follows` on
    # purpose: that flake is only tested against its own nixpkgs pin, so it
    # keeps the combination it ships with.
    llm-agents.url = "github:numtide/llm-agents.nix";

    # Official Rose Pine ports.
    rose-pine-tm-theme = {
      url = "github:rose-pine/tm-theme";
      flake = false;
    };
    rose-pine-fzf = {
      url = "github:rose-pine/fzf";
      flake = false;
    };
    rose-pine-zellij = {
      url = "github:rose-pine/zellij";
      flake = false;
    };
    rose-pine-lazygit = {
      url = "github:rose-pine/lazygit";
      flake = false;
    };
    rose-pine-eza = {
      url = "github:rose-pine/eza";
      flake = false;
    };
    rose-pine-starship = {
      url = "github:rose-pine/starship";
      flake = false;
    };
    rose-pine-fish = {
      url = "github:rose-pine/fish";
      flake = false;
    };
    rose-pine-yazi = {
      url = "github:rose-pine/yazi";
      flake = false;
    };
    rose-pine-atuin = {
      url = "github:rose-pine/atuin";
      flake = false;
    };
    rose-pine-i3 = {
      url = "github:rose-pine/i3";
      flake = false;
    };
    rose-pine-rofi = {
      url = "github:rose-pine/rofi";
      flake = false;
    };

    # zellij plugin behind Ctrl-h/j/k/l moving between nvim splits and
    # zellij panes (home/zellij.nix). A release file, pinned here.
    vim-zellij-navigator = {
      url = "file+https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm";
      flake = false;
    };
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
      # Every system to build for
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # Users that get configs (every config is generated for each of them).
      users = [ "conix" ];

      # Machines with a config of their own, by hostname, pointing at their
      # layer in home/:
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
        # TODO: rename to the Mac's real hostname once it's set up
        mac = {
          system = "aarch64-darwin";
          module = ./home/gui/mac;
        };
      };

      # Every other machine (remote servers) gets the base layer
      server = {
        system = "x86_64-linux";
        module = ./home;
      };

      # Build one Home Manager config for a user on a machine
      mkHome =
        user: machine:
        let
          pkgs = import nixpkgs {
            inherit (machine) system;
            # Unfree packages to accept.
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

      # `nix fmt`
      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # Lets `nix flake check` test every home config.
      checks =
        nixpkgs.lib.recursiveUpdate
          (nixpkgs.lib.genAttrs systems (
            system:
            nixpkgs.lib.mapAttrs (_: c: c.activationPackage) (
              nixpkgs.lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system) self.homeConfigurations
            )
          ))
          {
            # ...and the Mac's system settings (nix-darwin).
            aarch64-darwin.darwin-mac = self.darwinConfigurations.mac.system;
          };

      # The Mac's system settings only.
      # TODO: rename to the Mac's real hostname once it's set up.
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        modules = [ ./darwin/mac.nix ];
      };
    };
}
