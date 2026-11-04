{
  description = "Conor's terminal environment";

  inputs = {
    # nixpkgs-unstable, not nixos-unstable: no NixOS here, and the nixos-*
    # branches advance without waiting for the Mac's (darwin) builds.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

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

    # A prebuilt, weekly index of what every nixpkgs package contains, for
    # comma and "command not found" (home/default.nix): no indexing on each
    # machine.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Rose Pine ports.
    rose-pine-palette = {
      url = "github:rose-pine/rose-pine-palette"; # the colours, by role
      flake = false;
    };
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
    # (mako's: dunst has only a community port; home/gui/ubuntu/default.nix)
    rose-pine-mako = {
      url = "github:rose-pine/mako";
      flake = false;
    };

    # zellij plugin behind Ctrl+arrows moving between nvim splits and
    # zellij panes (home/zellij.nix). A release file, pinned here.
    vim-zellij-navigator = {
      url = "file+https://github.com/hiasr/vim-zellij-navigator/releases/download/0.3.0/vim-zellij-navigator.wasm";
      flake = false;
    };

    # nvim plugins nixpkgs doesn't package (home/neovim.nix).
    go-up-nvim = {
      url = "github:nullromo/go-up.nvim";
      flake = false;
    };
    smart-splits-zellij = {
      url = "github:smart-splits-nvim/backend-zellij-lua";
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
      # Every system to build for: the machines'.
      systems = nixpkgs.lib.unique (map (m: m.system) (builtins.attrValues hosts ++ [ server ]));

      # Server users, also the default for hosts without an explicit users list.
      users = [ "conix" ];

      # Machines with a config of their own, by hostname, pointing at their
      # layer in home/:
      #   server -> gui -> ubuntu -> hubble, luna
      #                 -> mac -> polaris
      hosts = {
        hubble = {
          system = "x86_64-linux";
          module = ./home/gui/ubuntu/hubble.nix;
        };
        luna = {
          system = "x86_64-linux";
          module = ./home/gui/ubuntu/luna.nix;
        };
        polaris = {
          system = "aarch64-darwin";
          module = ./home/gui/mac/polaris.nix;
          users = [ "main" ]; # its account, not conix
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
      homeConfigurations =
        nixpkgs.lib.genAttrs users (user: mkHome user server)
        // nixpkgs.lib.mergeAttrsList (
          nixpkgs.lib.mapAttrsToList (
            host: machine:
            builtins.listToAttrs (
              map (user: nixpkgs.lib.nameValuePair "${user}@${host}" (mkHome user machine)) (
                machine.users or users
              )
            )
          ) hosts
        );

      # `nix fmt`
      formatter = nixpkgs.lib.genAttrs systems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      # Lets `nix flake check` test every home config, and each Mac's system
      # settings (nix-darwin).
      checks = nixpkgs.lib.genAttrs systems (
        system:
        let
          onSystem = nixpkgs.lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system);
        in
        nixpkgs.lib.mapAttrs (_: c: c.activationPackage) (onSystem self.homeConfigurations)
        // nixpkgs.lib.mapAttrs' (host: c: nixpkgs.lib.nameValuePair "darwin-${host}" c.system) (
          onSystem self.darwinConfigurations
        )
      );

      # The Macs' system settings (nix-darwin): darwin/<hostname>.nix for
      # each Mac in hosts.
      darwinConfigurations = nixpkgs.lib.mapAttrs (
        host: machine:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./darwin/${host}.nix
            { nixpkgs.hostPlatform = machine.system; }
          ];
        }
      ) (nixpkgs.lib.filterAttrs (_: m: nixpkgs.lib.hasSuffix "-darwin" m.system) hosts);
    };
}
