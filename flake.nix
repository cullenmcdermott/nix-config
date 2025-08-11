{
  description = "cullen's multi-platform nix configuration";
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-substituters = [
      "https://cache.nixos.org"
      "https://cache.flox.dev"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    extra-platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    extra-system-features = [
      "big-parallel"
      "kvm"
    ];
  };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:nix-darwin/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox";
    # Don't override flox nixpkgs - let it use its own

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Handles making nix installed apps visibile in spotlight
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";

    # uv2nix for Python package management
    uv2nix.url = "github:pyproject-nix/uv2nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";

    # MCP Servers
    mcp-nixos.url = "github:utensils/mcp-nixos";
    mcp-nixos.inputs.nixpkgs.follows = "nixpkgs";
    
    # Non-flake MCP server sources
    kagimcp.url = "github:kagisearch/kagimcp";
    kagimcp.flake = false;
    
    context7-mcp.url = "github:upstash/context7-mcp";
    context7-mcp.flake = false;
    
    serena-mcp.url = "github:oraios/serena";
    serena-mcp.flake = false;

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
      uv2nix,
      mcp-nixos,
      kagimcp,
      context7-mcp,
      serena-mcp,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      mkDarwinConfig =
        {
          system,
          username,
          hostname,
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
                inherit inputs username;
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
          inherit system;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          modules = [
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
          extraModules ? [ ],
          extraPackages ? [ ],
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = {
            inherit inputs username flakeRef;
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
