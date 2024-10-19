{
  description = "cullen's mbp flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox";

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {
    nixpkgs,
    home-manager,
    darwin,
    flox,
    dagger,
    ...
  }: let
    mkDarwinConfig = {
      system,
      username,
      hostname,
      email,
      extraModules ? [],
      extraHomeManagerModules ? [],
    }: let
      baseConfiguration = {pkgs, ...}: {
        environment.systemPackages = [
          inputs.flox.packages.${pkgs.system}.default
          dagger.packages.${pkgs.system}.dagger
        ];

        nix.settings = {
          experimental-features = "nix-command flakes";
          substituters = [
            "https://cache.flox.dev"
          ];
          trusted-public-keys = [
            "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
          ];
        };
      };

      homeManagerConfiguration = {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = {inherit inputs username email;};
          users.${username}.imports =
            [
              ./modules/home-manager
            ]
            ++ extraHomeManagerModules;
        };
      };
    in
      darwin.lib.darwinSystem {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        modules =
          [
            baseConfiguration
            homeManagerConfiguration
            home-manager.darwinModules.home-manager
            ./modules/darwin
          ]
          ++ extraModules;
      };
  in {
    darwinConfigurations = {
      "Cullens-MacBook-Pro" = mkDarwinConfig {
        system = "x86_64-darwin";
        username = "cullen";
        hostname = "Cullens-MacBook-Pro";
        email = "cullen@example.com";
        extraModules = [./systems/personal];
      };
    };
  };
}
