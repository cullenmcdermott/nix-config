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

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.11.2";

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
    inputs@{ flake-parts, home-manager, darwin, flox, dagger, nix-homebrew, mac-app-util, flox-agentic, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-darwin" "x86_64-linux" ];

      imports = [
        ./hosts/cullens-macbook-pro
      ];

      flake =
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
              baseConfiguration = { pkgs, ... }: {
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

        in
        {
          darwinModules = {
            default = ./modules/darwin;
            shared = ./modules/common;
          };

          homeManagerModules = {
            default = ./modules/home-manager;
          };

          # darwinConfigurations entry for cullens-MacBook-Pro is now
          # registered by ./hosts/cullens-macbook-pro

          lib = {
            inherit mkDarwinConfig;
          };
        };
    };
}
