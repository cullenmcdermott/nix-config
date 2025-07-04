{
  description = "cullen's mbp flake";
  nixConfig = {
    extra-trusted-substituters = [ "https://cache.flox.dev" ];
    extra-trusted-public-keys = [ "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs=" ];
  };
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";

    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.3.17";

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Handles making nix installed apps visibile in spotlight
    mac-app-util.url = "github:hraban/mac-app-util";
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
      ...
    }:
    let
      supportedSystems = [
        "x86_64-darwin"
        "aarch64-darwin"
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
              environment.systemPackages = [
                inputs.flox.packages.${pkgs.system}.default
                dagger.packages.${pkgs.system}.dagger
              ];

              nix.settings = {
                experimental-features = "nix-command flakes";
                trusted-substituters = [
                  "https://cache.flox.dev"
                ];
                trusted-public-keys = [
                  "cullen:gtI9d0t7nPTU36OnGU6YpEP5wEndvbmna9+7jpCgWPg= "
                  "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
                ];
              };
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
              ] ++ extraHomeManagerModules;
            };
          };
        in
        darwin.lib.darwinSystem {
          specialArgs = {
            inherit username;
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
          ] ++ extraModules;
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
        inherit mkDarwinConfig;
      };
    };
}
