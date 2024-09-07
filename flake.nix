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
    self,
    nixpkgs,
    home-manager,
    darwin,
    nixvim,
    flox,
    dagger,
    ...
  }: let
    configuration = {pkgs, ...}: {
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

    commonDarwinConfig = system: modules:
      darwin.lib.darwinSystem {
        inherit system;
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        modules =
          modules
          ++ [
            configuration
            home-manager.darwinModules.home-manager
            {
              users.users.cullen.home = "/Users/cullen";
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = {inherit inputs;};
                users.cullen.imports = [./modules/home-manager];
              };
            }
          ];
      };
  in {
    darwinConfigurations.Cullens-MacBook-Pro = commonDarwinConfig "x86_64-darwin" [
      ./modules/darwin
      ./systems/personal
    ];

    darwinConfigurations.cmcdermott-mbp = commonDarwinConfig "aarch64-darwin" [
      ./modules/darwin
      ./systems/work
    ];
  };
}
