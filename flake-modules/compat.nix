# Compatibility shim for the public lib.mkDarwinConfig API.
#
# Status: deprecated. The work-laptop flake is the only consumer; once it
# migrates to composing darwinModules + homeManagerModules directly, delete
# this file and remove the import from flake.nix.
{ self, inputs, ... }:
{
  flake.lib.mkDarwinConfig =
    {
      system,
      username,
      hostname,
      claudeCodeOverrides ? { },
      extraModules ? [ ],
      extraHomeManagerModules ? [ ],
    }:
    inputs.darwin.lib.darwinSystem {
      specialArgs = {
        inherit username inputs;
      };
      modules = [
        {
          nixpkgs.hostPlatform = system;
          nixpkgs.config.allowUnfree = true;
        }
        { imports = [ self.darwinModules.shared ]; }
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "back";
            extraSpecialArgs = {
              inherit inputs username claudeCodeOverrides;
            };
            users.${username}.imports = [
              self.homeManagerModules.default
              inputs.mac-app-util.homeManagerModules.default
            ]
            ++ extraHomeManagerModules;
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
      ]
      ++ extraModules;
    };
}
