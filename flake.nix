{
  description = "Conor's terminal environment";

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
      inherit (nixpkgs) lib;

      # Every system to build for: the machines'.
      systems = lib.unique (map (m: m.system) (builtins.attrValues hosts ++ [ server ]));

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

      # Every other machine (remote servers) gets the base layer.
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
            config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "copilot-language-server" ];
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
      # "<user>" for servers, "<user>@<host>" for each host's users.
      homeConfigurations =
        lib.genAttrs users (user: mkHome user server)
        // lib.concatMapAttrs (
          host: machine:
          lib.genAttrs' (machine.users or users) (
            user: lib.nameValuePair "${user}@${host}" (mkHome user machine)
          )
        ) hosts;

      # `nix fmt`: the Nix, shell, Lua and Markdown files, with the settings
      # nvim formats them with on save (home/nvim/plugin/61_format.lua); CI
      # checks it. Not code embedded in Nix strings (nothing formats it), or
      # the one-off YAML, TOML and KDL files.
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
                "--indent=2" # (conform passes nvim's shiftwidth)
              ];
              includes = [ "*.sh" ];
            };
            stylua = {
              command = "stylua";
              options = [ "--config-path=home/nvim/.stylua.toml" ];
              includes = [ "*.lua" ];
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
            rumdl
          ];
        }
      );

      # Lets `nix flake check` test every home config, and each Mac's system
      # settings (nix-darwin).
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
              # The account that per-user settings (Homebrew, macOS
              # defaults) apply to.
              system.primaryUser = builtins.head (machine.users or users);
            }
          ];
        }
      ) (lib.filterAttrs (_: m: lib.hasSuffix "-darwin" m.system) hosts);
    };
}
