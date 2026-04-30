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
      {imports = [self.darwinModules.shared];}
      self.darwinModules.flox
      self.darwinModules.dagger
      {
        cullen.flox.enable = true;
        cullen.dagger.enable = true;
      }
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
            self.homeManagerModules.default
            self.homeManagerModules.agenticSkills
            inputs.mac-app-util.homeManagerModules.default
            ({...}: {
              cullen.agenticSkills.enable = true;
            })
            ({...}: {
              # Personal-laptop-only: Home Assistant integrations
              # (registers home-assistant skill + ha-claude launcher + statusline badge)
              programs.claude-code-nix.homeAssistant.enable = true;
            })
            ({...}: {
              # Personal-laptop-only: MiniMax via their native Anthropic-compatible endpoint.
              # To activate: add the API key to 1Password at op://Personal/MiniMax/credential,
              # then flip enable to true and nixswitch.
              programs.claude-code-nix.alternativeProvider = {
                enable = true;
                baseUrl = "https://api.minimax.io/anthropic";
                model = "MiniMax-M2.7";
                opSecretRef = "op://Private/MiniMax/credential";
                groupId = "op://Private/MiniMax/groupId";
              };
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
      self.darwinModules.default
      ./personal.nix
    ];
  };
}
