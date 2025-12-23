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

    flox.url = "github:flox/flox/v1.7.8";

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Workaround for GitLab Common Lisp 404 error (mac-app-util issue #39)
    # Pin to specific commit that fixes iterate download URL
    cl-nix-lite.url = "github:r4v3n6101/cl-nix-lite/6deefd29913ad23b73db8f1ade0a397e1518619f";

    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";
    mac-app-util.inputs.cl-nix-lite.follows = "cl-nix-lite";

    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";

    uv2nix.url = "github:pyproject-nix/uv2nix";
    uv2nix.inputs.pyproject-nix.follows = "pyproject-nix";
    uv2nix.inputs.nixpkgs.follows = "nixpkgs";

    pyproject-build-systems.url = "github:pyproject-nix/build-system-pkgs";
    pyproject-build-systems.inputs.pyproject-nix.follows = "pyproject-nix";
    pyproject-build-systems.inputs.uv2nix.follows = "uv2nix";
    pyproject-build-systems.inputs.nixpkgs.follows = "nixpkgs";

    # Pinned to f35c002 (2025-11-24) due to TypeScript build errors in newer commits
    # TODO: Try updating once upstream fixes path alias resolution (@http, @commands, etc.)
    context7-mcp.url = "github:upstash/context7-mcp/f35c002beeada90ed6fdddf19c0345f9f41cccdb";
    context7-mcp.flake = false;

    serena-mcp.url = "github:oraios/serena";
    serena-mcp.flake = false;

    flox-agentic.url = "github:flox/flox-agentic";
    flox-agentic.flake = false;

    agent-os.url = "github:buildermethods/agent-os/8b12ec5b3d002988da7171b89b9f60e5dbd88abc";
    agent-os.flake = false;
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
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      context7-mcp,
      serena-mcp,
      flox-agentic,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-linux"
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

      # MCP packages built from embedded sources
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        import ./lib/mcp-packages.nix {
          inherit
            inputs
            pkgs
            pyproject-nix
            uv2nix
            pyproject-build-systems
            ;
        }
      );
    };
}
