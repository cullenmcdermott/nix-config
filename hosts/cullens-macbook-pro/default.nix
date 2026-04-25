{ self, inputs, ... }:
let
  username = "cullen";
in
{
  flake.darwinConfigurations."cullens-MacBook-Pro" = inputs.darwin.lib.darwinSystem {
    specialArgs = {
      inherit username inputs;
    };
    modules = [
      {
        nixpkgs.hostPlatform = "aarch64-darwin";
        nixpkgs.config.allowUnfree = true;
      }
      { imports = [ self.darwinModules.shared ]; }
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "back";
          extraSpecialArgs = {
            inherit inputs username;
            claudeCodeOverrides = { };
          };
          users.${username}.imports = [
            self.homeManagerModules.default
            inputs.mac-app-util.homeManagerModules.default
          ];
        };
      }
      inputs.home-manager.darwinModules.home-manager
      inputs.nix-homebrew.darwinModules.nix-homebrew
      inputs.mac-app-util.darwinModules.default
      {
        nix-homebrew = {
          enable = true;
          enableRosetta = true;
          user = username;
          mutableTaps = true;
        };
      }
      self.darwinModules.default
      ./personal.nix
    ];
  };
}
