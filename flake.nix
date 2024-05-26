{
  description = "cullen's mbp flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-2311.url = "github:nixos/nixpkgs/nixos-23.11";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ nixpkgs, home-manager, darwin, nixvim, ... }: {
    darwinConfigurations.Cullens-MacBook-Pro = darwin.lib.darwinSystem {
      system = "x86_64-darwin";
      pkgs = import nixpkgs {
        system = "x86_64-darwin";
        config.allowUnfree = true;
      };
      modules = [
        ./modules/darwin
        ./systems/personal

        home-manager.darwinModules.home-manager
        {
          users.users.cullen.home = "/Users/cullen";
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.cullen.imports = [ ./modules/home-manager ];
          };
        }
      ];
    };
    darwinConfigurations.cmcdermott-mbp = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      pkgs = import nixpkgs {
        system = "aarch64-darwin";
        config.allowUnfree = true;
      };
      modules = [
        ./modules/darwin
        ./systems/work

        home-manager.darwinModules.home-manager
        {
          users.users.cullen.home = "/Users/cullen";
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = { inherit inputs; };
            users.cullen.imports = [ ./modules/home-manager ];
          };
        }
      ];
    };
  };
}
