{
  description = "cullen's multi-platform nix configuration";
  nixConfig = {
    extra-substituters = [
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.11.1";

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    mac-app-util.url = "github:hraban/mac-app-util";

    flox-agentic.url = "github:flox/flox-agentic";
    flox-agentic.flake = false;

    superpowers.url = "github:obra/superpowers/v5.0.7";
    superpowers.flake = false;
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      darwin,
      flox,
      dagger,
      nix-homebrew,
      mac-app-util,
      flox-agentic,
      ...
    }:
    let
      mkDarwinConfig =
        {
          system,
          username,
          hostname,
          claudeCodeOverrides ? { },
          extraModules ? [ ],
          extraHomeManagerModules ? [ ],
        }:
        let
          baseConfiguration =
            { pkgs, ... }:
            {
              imports = [ ./modules/common ];

            };

          homeManagerConfiguration = {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "back";
              extraSpecialArgs = {
                inherit inputs username claudeCodeOverrides;
              };
              users.${username}.imports = [
                ./modules/home-manager
                mac-app-util.homeManagerModules.default
              ]
              ++ extraHomeManagerModules;
            };
          };
        in
        darwin.lib.darwinSystem {
          specialArgs = {
            inherit username inputs;
          };
          modules = [
            {
              nixpkgs.hostPlatform = system;
              nixpkgs.config.allowUnfree = true;
            }
            baseConfiguration
            homeManagerConfiguration
            home-manager.darwinModules.home-manager
            nix-homebrew.darwinModules.nix-homebrew
            mac-app-util.darwinModules.default
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = username;
                mutableTaps = true;
              };
            }
            ./modules/darwin
          ]
          ++ extraModules;
        };

      mkDistroboxEnvConfig =
        {
          system,
          username,
          homeDirectory,
          flakeRef,
          claudeCodeOverrides ? { },
          extraModules ? [ ],
          extraPackages ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit
              inputs
              username
              flakeRef
              claudeCodeOverrides
              ;
          };
          modules = [
            ./modules/home-manager
            ./modules/home-manager/distrobox.nix
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              home.packages = extraPackages;
            }
          ]
          ++ extraModules;
        };

    in
    {
      darwinConfigurations = {
        "cullens-MacBook-Pro" = mkDarwinConfig {
          username = "cullen";
          system = "aarch64-darwin";
          hostname = "cullens-MacBook-Pro";
          extraModules = [ ./systems/personal/default.nix ];
        };

        # Example: Work laptop with Claude Code overrides
        # "work-macbook" = mkDarwinConfig {
        #   username = "cullen";
        #   system = "aarch64-darwin";
        #   hostname = "work-macbook";
        #   extraHomeManagerModules = [ ./systems/work/claude-code.nix ];
        # };
      };

      lib = {
        inherit mkDarwinConfig mkDistroboxEnvConfig;
      };

      homeConfigurations = {
        "cullen@distrobox" = mkDistroboxEnvConfig {
          system = "x86_64-linux";
          username = "cullen";
          homeDirectory = "/home/cullen";
          flakeRef = "github:cullenmcdermott/nix-config";
        };
      };

    };
}
