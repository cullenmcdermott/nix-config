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
}
