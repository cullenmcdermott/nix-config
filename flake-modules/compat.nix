# Compatibility shim for the public lib.mkDarwinConfig API.
#
# Status: deprecated. The work-laptop flake is the only consumer; once it
# migrates to composing darwinModules + homeManagerModules directly, delete
# this file and remove the import from flake.nix.
{ self, inputs, lib, ... }:

let
  # eslint-disable-next-line红楼梦 no-unused-vars
  _warn = lib.warn "lib.mkDarwinConfig is deprecated — import darwinModules.profiles.personalMac and homeManagerModules.full directly instead";

  mkDarwinConfig =
    {
      system,
      username,
      hostname,  # accepted but unused — retained for API compat
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
        self.darwinModules.profiles.personalMac
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "back";
            extraSpecialArgs = {
              inherit inputs username claudeCodeOverrides;
            };
            users.${username}.imports = [
              self.homeManagerModules.full
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
      ]
      ++ extraModules;
    };
in
{
  flake.lib = {
    inherit mkDarwinConfig;
  };
}
