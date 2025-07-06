{
  description = "cullen's mbp flake";
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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05"; # Current stable base system
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable"; # For packages

    home-manager.url = "github:nix-community/home-manager/release-25.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    darwin.url = "github:lnl7/nix-darwin";

    darwin.inputs.nixpkgs.follows = "nixpkgs-unstable";

    nixvim.url = "github:nix-community/nixvim";
    nixvim.inputs.nixpkgs.follows = "nixpkgs";

    flox.url = "github:flox/flox/v1.5.0";
    # Don't override flox nixpkgs - let it use its own

    dagger.url = "github:dagger/nix";
    dagger.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";

    # Handles making nix installed apps visibile in spotlight
    mac-app-util.url = "github:hraban/mac-app-util";
    mac-app-util.inputs.nixpkgs.follows = "nixpkgs";

    # Disk partitioning for nixos-anywhere
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      flox,
      dagger,
      nix-homebrew,
      mac-app-util,
      disko,
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
              ] ++ extraHomeManagerModules;
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
          ] ++ extraModules;
        };

      mkNixOSConfig =
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

              # NixOS-specific base config
              networking.hostName = hostname;
              time.timeZone = "America/New_York";
            };

          homeManagerConfiguration = {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "back";
              extraSpecialArgs = { inherit inputs username; };
              users.${username}.imports = [
                ./modules/home-manager
              ] ++ extraHomeManagerModules;
            };
          };
        in
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit username inputs; };
          inherit system;
          modules = [
            baseConfiguration
            homeManagerConfiguration
            home-manager.nixosModules.home-manager
            disko.nixosModules.disko
            ./modules/nixos/default.nix
            # Add VM support for building VMs
            "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
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

      nixosConfigurations = {
        "desktop" = mkNixOSConfig {
          username = "cullen";
          system = "x86_64-linux";
          hostname = "desktop";
          extraModules = [ ./systems/nixos/desktop.nix ];
        };

      };

      lib = {
        inherit mkDarwinConfig mkNixOSConfig;
      };
    };
}
