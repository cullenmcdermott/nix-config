{
  self,
  inputs,
  ...
}: let
  username = "cullen";
in {
  flake.darwinConfigurations."cullens-MacBook-Pro" = inputs.darwin.lib.darwinSystem {
    specialArgs = {
      inherit username inputs;
    };
    modules = [
      {
        nixpkgs.hostPlatform = "aarch64-darwin";
        nixpkgs.config.allowUnfree = true;
      }
      self.darwinModules.profiles.personalMac
      self.darwinModules.flox
      self.darwinModules.dagger
      {
        cullen.flox.enable = true;
        cullen.dagger.enable = true;
      }
      ./homebrew-personal.nix
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "back";
          extraSpecialArgs = {
            inherit inputs username;
            claudeCodeOverrides = {};
          };
          users.${username}.imports = [
            self.homeManagerModules.full
            self.homeManagerModules.agenticSkills
            self.homeManagerModules.omp
            inputs.mac-app-util.homeManagerModules.default
            ({...}: {
              home.homeDirectory = "/Users/${username}";
              cullen.agenticSkills.enable = true;
              cullen.omp.enable = true;
              programs.zwift-media.enable = true;
            })
            ({...}: {
              # Personal-laptop-only: Home Assistant integrations
              # (registers home-assistant skill + ha-claude launcher + statusline badge)
              programs.claude-code-nix.homeAssistant.enable = true;
            })
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
    ];
  };
}
