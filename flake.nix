{
  description = "Conor's environment";

  inputs = {

    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # For a daily Claude
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # A pre built, weekly index of what every nixpkgs package contains, for
    # comma and "command not found": no indexing on each machine.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Official Rose Pine ports.
    rose-pine-palette = {
      url = "github:rose-pine/rose-pine-palette";
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

    # nvim plugins nixpkgs doesn't package.
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
      inherit (nixpkgs) lib;

      # Every system to build for.
      systems = lib.unique (lib.catAttrs "system" (builtins.attrValues hosts ++ [ server ]));

      # The default for hosts without an explicit users list (servers).
      users = [ "conix" ];

      # Machines with a config of their own, by hostname
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
          users = [ "main" ];
        };
      };

      # Any other machine (servers) gets the base layer.
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
            config.allowUnfreePredicate = pkg: lib.getName pkg == "copilot-language-server";
          };
          homeRoot = if pkgs.stdenv.hostPlatform.isDarwin then "/Users" else "/home";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          # Makes `inputs` available to every module.
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
      # `nix run github:ConorWilliams/nix` bootstraps a machine.
      packages = lib.genAttrs systems (system: {
        default = nixpkgs.legacyPackages.${system}.writeShellScriptBin "bootstrap" (
          builtins.readFile ./bootstrap.sh
        );
      });

      # "<user>" for servers, "<user>@<host>" for each host's users.
      homeConfigurations =
        lib.genAttrs users (user: mkHome user server)
        // lib.concatMapAttrs (
          host: machine:
          lib.genAttrs' (machine.users or users) (
            user: lib.nameValuePair "${user}@${host}" (mkHome user machine)
          )
        ) hosts;

      # The repo's dev shell (.envrc): the Zellij plugins' host toolchain
      devShells = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              cargo
              clippy
              rustc
              rustfmt
              pkg-config
              openssl
              curl
            ];
          };
        }
      );

      # Formatting this repo
      formatter = lib.genAttrs systems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.nixfmt-tree.override {
          settings.formatter = {
            shfmt = {
              command = "shfmt";
              options = [
                "--write"
                "--indent=2"
              ];
              includes = [ "*.sh" ];
            };
            stylua = {
              command = "stylua";
              options = [ "--config-path=home/nvim/.stylua.toml" ];
              includes = [ "*.lua" ];
            };
            rustfmt = {
              command = "rustfmt";
              options = [ "--edition=2024" ];
              includes = [ "*.rs" ];
            };
            rumdl = {
              command = "rumdl";
              options = [ "fmt" ];
              includes = [ "*.md" ];
            };
          };
          runtimeInputs = with pkgs; [
            shfmt
            stylua
            rustfmt
            rumdl
          ];
        }
      );

      # Lets `nix flake check` test every config
      checks = lib.genAttrs systems (
        system:
        let
          onSystem = lib.filterAttrs (_: c: c.pkgs.stdenv.hostPlatform.system == system);
        in
        lib.mapAttrs (_: c: c.activationPackage) (onSystem self.homeConfigurations)
        // lib.mapAttrs' (host: c: lib.nameValuePair "darwin-${host}" c.system) (
          onSystem self.darwinConfigurations
        )
      );

      # The Macs' system settings (nix-darwin): darwin/<hostname>.nix for
      # each Mac in hosts, with its platform, name and account from there.
      darwinConfigurations = lib.mapAttrs (
        host: machine:
        nix-darwin.lib.darwinSystem {
          modules = [
            ./darwin/${host}.nix
            {
              nixpkgs.hostPlatform = machine.system;
              networking.hostName = host;
              system.primaryUser = builtins.head (machine.users or users);
            }
          ];
        }
      ) (lib.filterAttrs (_: m: lib.hasSuffix "-darwin" m.system) hosts);
    };
}
