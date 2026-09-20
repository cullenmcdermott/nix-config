{
  self,
  inputs,
  ...
}:
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
        users.users.${username}.home = "/Users/${username}";
        # nix-darwin's manual builder still passes `--toc-depth`, which
        # nixpkgs-unstable's nixos-render-docs removed (use --sidebar-depth).
        # Skip building the HTML manual until nix-darwin catches up. Also drop
        # the uninstaller, whose own inner darwin-system rebuilds the same
        # broken manual regardless of this setting.
        documentation.enable = false;
        system.tools.darwin-uninstaller.enable = false;
      }
      self.darwinModules.profiles.personalMac
      self.darwinModules.flox
      self.darwinModules.dagger
      self.darwinModules.linuxBuilder
      {
        cullen.flox.enable = true;
        cullen.dagger.enable = true;
        cullen.linuxBuilder.enable = true;
        cullen.linuxBuilder.tuned = true;
      }
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
            self.homeManagerModules.full
            self.homeManagerModules.agenticSkills
            self.homeManagerModules.omp
            self.homeManagerModules.sandbox
            inputs.mac-app-util.homeManagerModules.default
            (_: {
              cullen.agenticSkills.enable = true;
              cullen.omp.enable = true;
              programs.zwift-media.enable = true;
              programs.sandbox.enable = true;
            })
            (_: {
              # Personal-laptop-only: Home Assistant integrations
              # (registers home-assistant skill + ha-claude launcher + statusline badge)
              programs.claude-code-nix.homeAssistant.enable = true;
              programs.claude-code-nix.homeAssistant.repoPath = "/Users/${username}/git/claude-homeassistant";
              # Onshape FeatureScript MCP (Onshape Labs). Remote HTTP server;
              # needs an Onshape account subscribed to the app store listing,
              # then `/mcp` in Claude Code to do the OAuth login.
              programs.claude-code-nix.mcpServers.featurescript = {
                type = "http";
                url = "https://fs-mcp.labs.onshape.app/mcp";
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
    ];
  };
}
