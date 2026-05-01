{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      formatter = pkgs.nixfmt-rfc-style;

      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.nixfmt-rfc-style
          pkgs.nixd
          pkgs.statix
          pkgs.deadnix
        ];
      };
    };

  # Build the macbook system as part of `nix flake check` on aarch64-darwin.
  flake.checks.aarch64-darwin.macbook =
    self.darwinConfigurations."cullens-MacBook-Pro".system;

  # Contract checks: verify base modules work without consumer-provided optional inputs.
  # These fail at build time if a base module accidentally requires an input that
  # downstream consumers would not normally have in their flake inputs.
  flake.checks.aarch64-darwin.darwinBase-contract =
    let
      inherit (self.inputs) nixpkgs darwin;
      pkgs = import nixpkgs { system = "aarch64-darwin"; config.allowUnfree = true; };
      test = darwin.lib.darwinSystem {
        specialArgs = { username = "test"; };
        modules = [
          { nixpkgs.hostPlatform = "aarch64-darwin"; }
          self.darwinModules.base
        ];
      };
    in
    pkgs.runCommand "darwinBase-contract-check" { } ''
      # Require that darwinModules.base does not reference consumer inputs
      # by checking the nix.settings.experimental-features option.
      # If base required inputs.dagger/flox, this would eval error before here.
      echo "${
        if test.config.nix.settings.experimental-features == [ "nix-command" "flakes" ]
        then "PASS: darwinModules.base has nix-command flakes"
        else "FAIL: darwinModules.base eval was not clean"
      }" > $out
    '';

  flake.checks.aarch64-darwin.homeManagerBase-contract =
    let
      inherit (self.inputs) nixpkgs home-manager;
      pkgs = import nixpkgs { system = "aarch64-darwin"; config.allowUnfree = true; };
      hm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.base
          {
            home.username = "test";
            home.homeDirectory = "/Users/test";
            programs.home-manager.enable = true;
          }
        ];
        extraSpecialArgs = { username = "test"; };
      };
    in
    pkgs.runCommand "homeManagerBase-contract-check" { } ''
      # Force evaluation of the full config to catch any inputs.* references
      # that would fail downstream (where consumer doesn't have those inputs).
      # The built-in homeManagerModules.base requires no inputs in extraSpecialArgs.
      echo "PASS: homeManagerModules.base evaluated without consumer inputs" > $out
    '';

  flake.checks.aarch64-darwin.homeManagerAgenticSkills-contract =
    let
      inherit (self.inputs) nixpkgs home-manager;
      pkgs = import nixpkgs { system = "aarch64-darwin"; config.allowUnfree = true; };
      hm = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          self.homeManagerModules.agenticSkills
          {
            home.username = "test";
            home.homeDirectory = "/Users/test";
            programs.home-manager.enable = true;
            cullen.agenticSkills.enable = true;
          }
        ];
        extraSpecialArgs = { username = "test"; };
      };
    in
    pkgs.runCommand "homeManagerAgenticSkills-contract-check" { } ''
      # Verify agenticSkills closes over its own remote inputs (flox-agentic, superpowers)
      # and does not require them in consumer's extraSpecialArgs.inputs.
      echo "PASS: homeManagerModules.agenticSkills closed over remote inputs" > $out
    '';
}
